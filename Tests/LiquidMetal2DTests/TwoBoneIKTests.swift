import XCTest
@testable import LiquidMetal2D

private let degree = GameMath.pi / 180

/// A body bone turned 30° with an arm hanging off it: upper arm 2 long, its
/// joint 1 above the body's origin; forearm 1.5 long at the upper arm's end.
/// Bones: 0 body, 1 upper, 2 lower. No attachments: the tests read bones.
private func makeArmRig(jointAt joint: Vec2 = Vec2(2, 0)) -> SkeletonDefinition {
    SkeletonDefinition(
        bones: [
            Bone(name: "body", parent: nil, length: 1, rest: RigidTransform2D(rotation: 30 * degree)),
            Bone(name: "upper", parent: 0, length: 2, rest: RigidTransform2D(position: Vec2(0, 1))),
            Bone(name: "lower", parent: 1, length: 1.5, rest: RigidTransform2D(position: joint))
        ],
        attachments: [])
}

final class TwoBoneIKTests: XCTestCase {

    private let epsilon: Float = 0.001

    private func assertEqual(_ lhs: Vec2, _ rhs: Vec2, _ message: String = "",
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: epsilon, "x \(message)", file: file, line: line)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: epsilon, "y \(message)", file: file, line: line)
    }

    /// Where the solver's angles put the joint and the tip.
    private func chain(root: Vec2, _ upperLength: Float, _ lowerLength: Float,
                       _ solved: (upper: Float, lowerLocal: Float)) -> (joint: Vec2, tip: Vec2) {
        let joint = root + Vec2(upperLength, 0).rotated(by: solved.upper)
        return (joint, joint + Vec2(lowerLength, 0).rotated(by: solved.upper + solved.lowerLocal))
    }

    // MARK: - Solver

    func testTargetInReachIsHitWithEitherBend() {
        let root = Vec2(1, 2)
        for target in [Vec2(3, 3), Vec2(-1, 0.5), Vec2(1, 4.5), Vec2(2.2, 1.1)] {
            let positive = TwoBoneIK.solve(root: root, upperLength: 2, lowerLength: 1.5,
                                           target: target, bendPositive: true)
            let negative = TwoBoneIK.solve(root: root, upperLength: 2, lowerLength: 1.5,
                                           target: target, bendPositive: false)
            let up = chain(root: root, 2, 1.5, positive)
            let down = chain(root: root, 2, 1.5, negative)

            assertEqual(up.tip, target, "bend positive, target \(target)")
            assertEqual(down.tip, target, "bend negative, target \(target)")
            // The two bends put the joint on opposite sides of the root-to-target line.
            XCTAssertGreaterThan((target - root).cross(up.joint - root), 0, "target \(target)")
            XCTAssertLessThan((target - root).cross(down.joint - root), 0, "target \(target)")
        }
    }

    func testTargetOutOfReachGetsAStraightChainPointingAtIt() {
        let solved = TwoBoneIK.solve(root: Vec2(0, 0), upperLength: 2, lowerLength: 1.5,
                                     target: Vec2(0, 10), bendPositive: true)

        XCTAssertEqual(solved.upper, 90 * degree, accuracy: epsilon)
        XCTAssertEqual(solved.lowerLocal, 0, accuracy: epsilon)
        assertEqual(chain(root: Vec2(0, 0), 2, 1.5, solved).tip, Vec2(0, 3.5))
    }

    func testTargetTooCloseGetsTheNearestReachablePoint() {
        let solved = TwoBoneIK.solve(root: Vec2(0, 0), upperLength: 2, lowerLength: 1.5,
                                     target: Vec2(0.2, 0), bendPositive: true)

        // A chain of 2 and 1.5 can't bring its tip nearer the root than 0.5.
        assertEqual(chain(root: Vec2(0, 0), 2, 1.5, solved).tip, Vec2(0.5, 0))
    }

    func testTargetOnTheRootIsNotNaN() {
        for lengths in [(Float(2), Float(1.5)), (Float(1), Float(1))] {
            let solved = TwoBoneIK.solve(root: Vec2(3, 4), upperLength: lengths.0, lowerLength: lengths.1,
                                         target: Vec2(3, 4), bendPositive: false)

            XCTAssertTrue(solved.upper.isFinite && solved.lowerLocal.isFinite, "lengths \(lengths)")
            let tip = chain(root: Vec2(3, 4), lengths.0, lengths.1, solved).tip
            XCTAssertEqual(simd_length(tip - Vec2(3, 4)), abs(lengths.0 - lengths.1), accuracy: epsilon,
                           "the tip comes as near the root as it can, lengths \(lengths)")
        }
    }

    // MARK: - Constraint

    func testConstraintNeedsAChainedPair() {
        XCTAssertThrowsError(try IKConstraint(upper: 0, lower: 2, in: makeArmRig())) { error in
            XCTAssertEqual(error as? SkeletonError, .ikBonesNotChained(upper: "body", lower: "lower"))
        }
        XCTAssertThrowsError(try IKConstraint(upper: "upper", lower: "hand", in: makeArmRig())) { error in
            XCTAssertEqual(error as? SkeletonError, .unknownBone("hand"))
        }
        XCTAssertNoThrow(try IKConstraint(upper: "upper", lower: "lower", in: makeArmRig()))
    }

    func testConstraintRejectsAZeroLengthSegment() {
        XCTAssertThrowsError(try IKConstraint(upper: 1, lower: 2, in: makeArmRig(jointAt: Vec2(0, 0)))) { error in
            XCTAssertEqual(error as? SkeletonError, .ikBoneHasNoLength("upper"))
        }
    }

    // MARK: - Through the component

    /// A moved, turned, scaled root, flipped and not: the forearm's tip lands on
    /// the world target. The target sits 3 right and 2 up from the shoulder
    /// (the arm reaches 7 at scale 2).
    func testTipReachesAWorldTarget() throws {
        for flip in [false, true] {
            let root = GameObj()
            root.position = Vec2(10, 5)
            root.rotation = 20 * degree
            let skeleton = try SkeletonComponent(parent: root, definition: makeArmRig(), defaultTextureID: 0)
            skeleton.scale = 2
            skeleton.flipX = flip
            skeleton.update(dt: 0)
            let target = skeleton.worldTransform(ofBone: 1).position + Vec2(3, 2)

            skeleton.ikConstraints = [try IKConstraint(upper: "upper", lower: "lower", in: skeleton.definition,
                                                       target: target)]
            skeleton.update(dt: 0)

            let forearm = skeleton.worldTransform(ofBone: 2)
            assertEqual(forearm.apply(to: Vec2(1.5 * skeleton.scale, 0)), target, "flip \(flip)")
        }
    }

    /// The bend direction belongs to the rig: flipping the figure mirrors the
    /// elbow to the other side of the shoulder-to-target line in the world.
    func testFlipMirrorsTheBend() throws {
        for flip in [false, true] {
            let root = GameObj()
            let skeleton = try SkeletonComponent(parent: root, definition: makeArmRig(), defaultTextureID: 0)
            skeleton.flipX = flip
            skeleton.update(dt: 0)
            let shoulder = skeleton.worldTransform(ofBone: 1).position
            let target = shoulder + Vec2(1, 2)

            skeleton.ikConstraints = [try IKConstraint(upper: 1, lower: 2, in: skeleton.definition,
                                                       target: target, bendPositive: true)]
            skeleton.update(dt: 0)

            let elbow = skeleton.worldTransform(ofBone: 2).position
            let side = (target - shoulder).cross(elbow - shoulder)
            if flip {
                XCTAssertLessThan(side, 0, "flipped: the elbow mirrors to the clockwise side")
            } else {
                XCTAssertGreaterThan(side, 0, "unflipped: bend positive is counter-clockwise")
            }
        }
    }

    func testWeightZeroLeavesTheAnimationAlone() throws {
        let root = GameObj()
        let skeleton = try SkeletonComponent(parent: root, definition: makeArmRig(), defaultTextureID: 0)
        skeleton.update(dt: 0)
        let animated = (0..<3).map { skeleton.worldTransform(ofBone: $0) }

        skeleton.ikConstraints = [try IKConstraint(upper: 1, lower: 2, in: skeleton.definition,
                                                   target: Vec2(-3, -3), weight: 0)]
        skeleton.update(dt: 0)

        XCTAssertEqual((0..<3).map { skeleton.worldTransform(ofBone: $0) }, animated)
    }

    func testHalfWeightTurnsTheUpperBoneHalfway() throws {
        let root = GameObj()
        let skeleton = try SkeletonComponent(parent: root, definition: makeArmRig(), defaultTextureID: 0)
        skeleton.update(dt: 0)
        let animated = skeleton.worldTransform(ofBone: 1).rotation
        skeleton.ikConstraints = [try IKConstraint(upper: 1, lower: 2, in: skeleton.definition,
                                                   target: Vec2(-1, 3))]
        skeleton.update(dt: 0)
        let full = skeleton.worldTransform(ofBone: 1).rotation

        skeleton.ikConstraints[0].weight = 0.5
        skeleton.update(dt: 0)

        let half = skeleton.worldTransform(ofBone: 1).rotation
        XCTAssertEqual(half, GameMath.lerpAngle(a: animated, b: full, t: 0.5), accuracy: epsilon)
    }

    func testIKLeavesTheAnimatorsPoseAsTheClipsMadeIt() throws {
        let rig = makeArmRig()
        let root = GameObj()     // the component holds its parent unowned
        let skeleton = try SkeletonComponent(parent: root, definition: rig, defaultTextureID: 0)
        skeleton.ikConstraints = [try IKConstraint(upper: 1, lower: 2, in: rig, target: Vec2(1, 3))]

        skeleton.update(dt: 0.1)

        XCTAssertEqual(skeleton.animator.pose, Pose(restOf: rig))
        withExtendedLifetime(root) {}
    }
}
