import XCTest
import LiquidMetal2D
@testable import MotionatorKit

final class PoseSamplerTests: XCTestCase {

    func testNearestBoneWithinTolerance() throws {
        let rig = try Fixtures.stickFigure().rig
        let pose = Pose(restOf: rig)
        let world = PoseSampler.worldTransforms(rig: rig, pose: pose)
        let shin = try rig.boneIndex(named: "shinNear")
        let middle = (PoseSampler.joint(of: shin, world: world) + PoseSampler.tip(of: shin, rig: rig, world: world)) / 2

        XCTAssertEqual(PoseSampler.bone(near: middle + Vec2(0.05, 0), rig: rig, world: world, tolerance: 0.2), shin)
        XCTAssertNil(PoseSampler.bone(near: Vec2(100, 100), rig: rig, world: world, tolerance: 0.2))
        let stacked = PoseSampler.bones(near: middle, rig: rig, world: world, tolerance: 0.2)
        XCTAssertEqual(stacked, [shin, try rig.boneIndex(named: "shinFar")], "the far shin lies under the near one")
    }

    func testAChainTipIsAHandOrFootNotTheTorso() throws {
        let rig = try Fixtures.stickFigure().rig
        let pose = Pose(restOf: rig)
        let world = PoseSampler.worldTransforms(rig: rig, pose: pose)
        let shin = try rig.boneIndex(named: "shinNear")
        let foot = PoseSampler.tip(of: shin, rig: rig, world: world)

        let chain = try XCTUnwrap(
            PoseSampler.chainTip(near: foot + Vec2(0.02, 0.02), rig: rig, world: world, tolerance: 0.2))
        XCTAssertEqual(chain, IKChain(upper: try rig.boneIndex(named: "thighNear"), lower: shin))

        let spine = try rig.boneIndex(named: "spine")
        let spineTip = PoseSampler.tip(of: spine, rig: rig, world: world)
        XCTAssertNotEqual(PoseSampler.chainTip(near: spineTip, rig: rig, world: world, tolerance: 0.2)?.lower, spine,
                          "the spine has children")
    }

    func testRotationsReachingPutTheTipOnTheTarget() throws {
        let rig = try Fixtures.stickFigure().rig
        var pose = Pose(restOf: rig)
        let thigh = try rig.boneIndex(named: "thighNear")
        let shin = try rig.boneIndex(named: "shinNear")
        let chain = IKChain(upper: thigh, lower: shin)
        var world = PoseSampler.worldTransforms(rig: rig, pose: pose)
        let hip = PoseSampler.joint(of: thigh, world: world)
        let reach = rig.bones[thigh].length + rig.bones[shin].length
        let target = hip + Vec2(0.5, -0.5) * reach * 0.8

        let solved = PoseSampler.rotationsReaching(target, chain: chain, rig: rig, pose: pose, bendPositive: true)
        pose.local[thigh].rotation = solved.upper
        pose.local[shin].rotation = solved.lower
        world = PoseSampler.worldTransforms(rig: rig, pose: pose)

        let foot = PoseSampler.tip(of: shin, rig: rig, world: world)
        XCTAssertEqual(simd_length(foot - target), 0, accuracy: 1e-3)

        let far = hip + Vec2(0, -3) * reach
        let stretched = PoseSampler.rotationsReaching(far, chain: chain, rig: rig, pose: pose, bendPositive: true)
        pose.local[thigh].rotation = stretched.upper
        pose.local[shin].rotation = stretched.lower
        world = PoseSampler.worldTransforms(rig: rig, pose: pose)
        let stretchedFoot = PoseSampler.tip(of: shin, rig: rig, world: world)
        XCTAssertEqual(simd_length(stretchedFoot - hip), reach, accuracy: 1e-3, "straight, as far as it goes")
        XCTAssertEqual(abs((stretchedFoot - hip).x), 0, accuracy: 1e-3, "on the line to the target")
    }

    func testRotationPointingAimsTheBone() throws {
        let rig = try Fixtures.stickFigure().rig
        var pose = Pose(restOf: rig)
        let arm = try rig.boneIndex(named: "lowerArmNear")
        var world = PoseSampler.worldTransforms(rig: rig, pose: pose)
        let point = PoseSampler.joint(of: arm, world: world) + Vec2(-1, 2)

        pose.local[arm].rotation = PoseSampler.rotationPointing(bone: arm, at: point, rig: rig, world: world)
        world = PoseSampler.worldTransforms(rig: rig, pose: pose)

        let direction = PoseSampler.tip(of: arm, rig: rig, world: world) - PoseSampler.joint(of: arm, world: world)
        let wanted = point - PoseSampler.joint(of: arm, world: world)
        XCTAssertEqual(direction.cross(wanted), 0, accuracy: 1e-4)
        XCTAssertGreaterThan(simd_dot(direction, wanted), 0)
    }
}
