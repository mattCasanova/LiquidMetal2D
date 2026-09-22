import XCTest
@testable import LiquidMetal2D

private let degree = GameMath.pi / 180

/// Two bones in a line along +x: `upper` (length 2) at the root, `lower` (length 1) on its tip.
private func makeTwoBoneChain(upperRotation: Float = 0, lowerRotation: Float = 0) -> SkeletonDefinition {
    SkeletonDefinition(
        bones: [
            Bone(name: "upper", parent: nil, length: 2, rest: RigidTransform2D(rotation: upperRotation)),
            Bone(name: "lower", parent: 0, length: 1,
                 rest: RigidTransform2D(position: Vec2(2, 0), rotation: lowerRotation)),
        ],
        attachments: [])
}

/// World-space tip of bone `index` after solving `definition` at rest.
private func tip(of index: Int, in definition: SkeletonDefinition, root: RigidTransform2D = .identity) -> Vec2 {
    var world = [RigidTransform2D](repeating: .identity, count: definition.bones.count)
    SkeletonSolver.solveWorld(
        definition: definition, pose: Pose(restOf: definition), root: root, into: &world)
    return world[index].apply(to: Vec2(definition.bones[index].length, 0))
}

final class SkeletonTests: XCTestCase {

    private let epsilon: Float = 0.0001

    private func assertEqual(_ lhs: Vec2, _ rhs: Vec2, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: epsilon, "x", file: file, line: line)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: epsilon, "y", file: file, line: line)
    }

    // MARK: - Vec2.rotated / RigidTransform2D

    func testRotatedQuarterTurn() {
        assertEqual(Vec2(1, 0).rotated(by: 90 * degree), Vec2(0, 1))
    }

    func testIdentityIsNeutralOnBothSides() {
        let transform = RigidTransform2D(position: Vec2(3, -2), rotation: 0.4)
        let identityFirst = RigidTransform2D.identity.composed(with: transform)
        let identitySecond = transform.composed(with: .identity)

        XCTAssertEqual(identityFirst.rotation, transform.rotation, accuracy: epsilon)
        assertEqual(identityFirst.position, transform.position)
        XCTAssertEqual(identitySecond.rotation, transform.rotation, accuracy: epsilon)
        assertEqual(identitySecond.position, transform.position)
    }

    func testComposedRotatesTheChildOffset() {
        let parent = RigidTransform2D(position: Vec2(2, 0), rotation: 90 * degree)
        let child = RigidTransform2D(position: Vec2(1, 0), rotation: 0)
        let result = parent.composed(with: child)

        assertEqual(result.position, Vec2(2, 1))
        XCTAssertEqual(result.rotation, 90 * degree, accuracy: epsilon)
    }

    // MARK: - World solve

    func testStraightChainTipIsSumOfLengths() {
        assertEqual(tip(of: 1, in: makeTwoBoneChain()), Vec2(3, 0))
    }

    func testRotatingTheParentSwingsTheChild() {
        assertEqual(tip(of: 1, in: makeTwoBoneChain(upperRotation: 90 * degree)), Vec2(0, 3))
    }

    func testChildRotationIsRelativeToParent() {
        let chain = makeTwoBoneChain(upperRotation: 90 * degree, lowerRotation: -90 * degree)

        assertEqual(tip(of: 1, in: chain), Vec2(1, 2))
    }

    func testRootTransformMovesAndTurnsTheWholeChain() {
        let root = RigidTransform2D(position: Vec2(10, 5), rotation: 90 * degree)

        assertEqual(tip(of: 0, in: makeTwoBoneChain(), root: root), Vec2(10, 7))
        assertEqual(tip(of: 1, in: makeTwoBoneChain(), root: root), Vec2(10, 8))
    }

    // MARK: - Validation

    func testValidChainPassesValidation() throws {
        try makeTwoBoneChain().validate()
    }

    func testEmptyRigIsRejected() {
        XCTAssertThrowsError(try SkeletonDefinition(bones: [], attachments: []).validate()) {
            XCTAssertEqual($0 as? SkeletonError, .noBones)
        }
    }

    func testChildBeforeParentIsRejected() {
        let rig = SkeletonDefinition(
            bones: [
                Bone(name: "lower", parent: 1, length: 1, rest: .identity),
                Bone(name: "upper", parent: nil, length: 2, rest: .identity),
            ],
            attachments: [])

        XCTAssertThrowsError(try rig.validate()) {
            XCTAssertEqual($0 as? SkeletonError, .parentNotBeforeChild(bone: "lower"))
        }
    }

    func testBoneThatIsItsOwnParentIsRejected() {
        let rig = SkeletonDefinition(
            bones: [Bone(name: "loop", parent: 0, length: 1, rest: .identity)], attachments: [])

        XCTAssertThrowsError(try rig.validate()) {
            XCTAssertEqual($0 as? SkeletonError, .parentNotBeforeChild(bone: "loop"))
        }
    }

    func testDuplicateBoneNameIsRejected() {
        let rig = SkeletonDefinition(
            bones: [
                Bone(name: "arm", parent: nil, length: 1, rest: .identity),
                Bone(name: "arm", parent: 0, length: 1, rest: .identity),
            ],
            attachments: [])

        XCTAssertThrowsError(try rig.validate()) {
            XCTAssertEqual($0 as? SkeletonError, .duplicateBoneName("arm"))
        }
    }

    func testAttachmentOnMissingBoneIsRejected() {
        var rig = makeTwoBoneChain()
        rig.attachments = [Attachment(name: "hat", bone: 99, size: Vec2(1, 1), offset: Vec2())]

        XCTAssertThrowsError(try rig.validate()) {
            XCTAssertEqual($0 as? SkeletonError, .attachmentBoneOutOfRange(attachment: "hat"))
        }
    }

    func testBoneIndexByName() throws {
        let rig = makeTwoBoneChain()

        XCTAssertEqual(try rig.boneIndex(named: "lower"), 1)
        XCTAssertThrowsError(try rig.boneIndex(named: "tail")) {
            XCTAssertEqual($0 as? SkeletonError, .unknownBone("tail"))
        }
    }

    // MARK: - Pose

    func testPoseStartsAtRest() {
        let rig = makeTwoBoneChain(upperRotation: 0.3, lowerRotation: -0.2)

        XCTAssertEqual(Pose(restOf: rig).local, rig.bones.map(\.rest))
    }

    func testResetReturnsToRest() {
        let rig = makeTwoBoneChain(upperRotation: 0.3)
        var pose = Pose(restOf: rig)
        pose.local[0] = RigidTransform2D(position: Vec2(9, 9), rotation: 2)

        pose.reset(to: rig)

        XCTAssertEqual(pose.local, rig.bones.map(\.rest))
    }

    func testBlendHalfwayTakesTheShortWayRound() {
        let rig = makeTwoBoneChain()
        var from = Pose(restOf: rig)
        var to = Pose(restOf: rig)
        from.local[0] = RigidTransform2D(position: Vec2(0, 0), rotation: 170 * degree)
        to.local[0] = RigidTransform2D(position: Vec2(4, 2), rotation: -170 * degree)
        var blended = Pose(restOf: rig)

        blended.setBlend(from: from, to: to, t: 0.5)

        assertEqual(blended.local[0].position, Vec2(2, 1))
        XCTAssertEqual(abs(blended.local[0].rotation), 180 * degree, accuracy: epsilon)
    }

    // MARK: - GameMath.lerpAngle

    func testLerpAngleCrossesPiNotZero() {
        let halfway = GameMath.lerpAngle(a: 170 * degree, b: -170 * degree, t: 0.5)

        XCTAssertEqual(abs(halfway), 180 * degree, accuracy: epsilon)
    }

    func testLerpAngleMatchesLerpForSmallTurns() {
        XCTAssertEqual(GameMath.lerpAngle(a: 0.2, b: 0.8, t: 0.25), 0.35, accuracy: epsilon)
    }

    // MARK: - EasingType

    func testEveryEasingStartsAtZeroAndEndsAtOne() {
        for easing in EasingType.allCases {
            XCTAssertEqual(easing.apply(0), 0, accuracy: 0.001, "\(easing) at 0")
            XCTAssertEqual(easing.apply(1), 1, accuracy: 0.001, "\(easing) at 1")
        }
    }

    func testLinearIsIdentity() {
        XCTAssertEqual(EasingType.linear.apply(0.3), 0.3, accuracy: epsilon)
    }

    func testEasingTypeRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(EasingType.easeInOutSine)

        XCTAssertEqual(String(data: data, encoding: .utf8), "\"easeInOutSine\"")
        XCTAssertEqual(try JSONDecoder().decode(EasingType.self, from: data), .easeInOutSine)
    }
}
