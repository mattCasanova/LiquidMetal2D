import XCTest
@testable import LiquidMetal2D

/// Two bones: `arm` (rest rotation 0.5, rest position (1, 1)) and `hand` on its tip.
private func makeRig() -> SkeletonDefinition {
    SkeletonDefinition(
        bones: [
            Bone(name: "arm", parent: nil, length: 2,
                 rest: RigidTransform2D(position: Vec2(1, 1), rotation: 0.5)),
            Bone(name: "hand", parent: 0, length: 1,
                 rest: RigidTransform2D(position: Vec2(2, 0), rotation: 0)),
        ],
        attachments: [])
}

/// A clip that turns `arm` from 0 to 1 radian over one second.
private func makeTurnClip(loops: Bool = false, easing: EasingType = .linear) -> AnimationClip {
    AnimationClip(
        name: "turn", duration: 1, loops: loops,
        tracks: [BoneTrack(bone: "arm", rotation: [
            Keyframe(time: 0, value: 0, easing: easing),
            Keyframe(time: 1, value: 1),
        ])])
}

final class AnimationClipTests: XCTestCase {

    private let epsilon: Float = 0.0001
    private let rig = makeRig()

    private func pose(of clip: AnimationClip, at time: Float) throws -> Pose {
        var pose = Pose(restOf: rig)
        try clip.resolved(for: rig).sample(at: time, definition: rig, into: &pose)
        return pose
    }

    private func armRotation(_ clip: AnimationClip, at time: Float) throws -> Float {
        try pose(of: clip, at: time).local[0].rotation
    }

    // MARK: - Sampling

    func testLinearKeysInterpolate() throws {
        XCTAssertEqual(try armRotation(makeTurnClip(), at: 0.5), 0.5, accuracy: epsilon)
        XCTAssertEqual(try armRotation(makeTurnClip(), at: 0.25), 0.25, accuracy: epsilon)
    }

    func testOneShotClampsBeforeStartAndAfterEnd() throws {
        XCTAssertEqual(try armRotation(makeTurnClip(), at: -1), 0, accuracy: epsilon)
        XCTAssertEqual(try armRotation(makeTurnClip(), at: 2), 1, accuracy: epsilon)
    }

    func testLoopingClipWraps() throws {
        let clip = makeTurnClip(loops: true)

        XCTAssertEqual(try armRotation(clip, at: 1.25), try armRotation(clip, at: 0.25), accuracy: epsilon)
        XCTAssertEqual(try armRotation(clip, at: -0.25), try armRotation(clip, at: 0.75), accuracy: epsilon)
    }

    func testEasingShapesTheSegment() throws {
        // easeInQuad at u = 0.5 is 0.25 of the way.
        XCTAssertEqual(try armRotation(makeTurnClip(easing: .easeInQuad), at: 0.5), 0.25, accuracy: epsilon)
    }

    func testEasingOnTheLastKeyIsIgnored() throws {
        // Easing belongs to the segment a key starts; the last key starts none.
        let clip = AnimationClip(
            name: "turn", duration: 1, loops: false,
            tracks: [BoneTrack(bone: "arm", rotation: [
                Keyframe(time: 0, value: 0),
                Keyframe(time: 1, value: 1, easing: .easeInQuad),
            ])])

        XCTAssertEqual(try armRotation(clip, at: 0.5), 0.5, accuracy: epsilon)
    }

    func testSameTimeKeysJump() throws {
        let clip = AnimationClip(
            name: "snap", duration: 1, loops: false,
            tracks: [BoneTrack(bone: "arm", rotation: [
                Keyframe(time: 0, value: 0),
                Keyframe(time: 0.5, value: 0),
                Keyframe(time: 0.5, value: 2),
                Keyframe(time: 1, value: 2),
            ])])

        XCTAssertEqual(try armRotation(clip, at: 0.49), 0, accuracy: epsilon)
        XCTAssertEqual(try armRotation(clip, at: 0.5), 2, accuracy: epsilon)
    }

    func testSingleKeyHoldsItsValue() throws {
        let clip = AnimationClip(
            name: "hold", duration: 1, loops: false,
            tracks: [BoneTrack(bone: "arm", rotation: [Keyframe(time: 0.3, value: 1.2)])])

        XCTAssertEqual(try armRotation(clip, at: 0), 1.2, accuracy: epsilon)
        XCTAssertEqual(try armRotation(clip, at: 0.9), 1.2, accuracy: epsilon)
    }

    // MARK: - Channels

    func testUntrackedBoneStaysAtRestEvenIfThePoseHeldJunk() throws {
        var pose = Pose(restOf: rig)
        pose.local[1] = RigidTransform2D(position: Vec2(99, 99), rotation: 9)

        try makeTurnClip().resolved(for: rig).sample(at: 0.5, definition: rig, into: &pose)

        XCTAssertEqual(pose.local[1], rig.bones[1].rest)
    }

    func testRotationTrackLeavesPositionAtRest() throws {
        let armPosition = try pose(of: makeTurnClip(), at: 0.5).local[0].position

        XCTAssertEqual(armPosition, rig.bones[0].rest.position)
    }

    func testPositionTrackLeavesRotationAtRest() throws {
        let clip = AnimationClip(
            name: "slide", duration: 1, loops: false,
            tracks: [BoneTrack(bone: "arm", position: [
                Keyframe(time: 0, value: Vec2(0, 0)),
                Keyframe(time: 1, value: Vec2(4, -2)),
            ])])
        let arm = try pose(of: clip, at: 0.5).local[0]

        XCTAssertEqual(arm.position.x, 2, accuracy: epsilon)
        XCTAssertEqual(arm.position.y, -1, accuracy: epsilon)
        XCTAssertEqual(arm.rotation, rig.bones[0].rest.rotation, accuracy: epsilon)
    }

    // MARK: - Resolving

    func testUnknownBoneIsRejected() {
        let clip = AnimationClip(
            name: "wag", duration: 1, loops: true,
            tracks: [BoneTrack(bone: "tail", rotation: [Keyframe(time: 0, value: 0)])])

        XCTAssertThrowsError(try clip.resolved(for: rig)) {
            XCTAssertEqual($0 as? SkeletonError, .unknownBone("tail"))
        }
    }

    func testUnsortedKeysAreRejected() {
        let clip = AnimationClip(
            name: "bad", duration: 1, loops: false,
            tracks: [BoneTrack(bone: "hand", rotation: [
                Keyframe(time: 0.8, value: 0),
                Keyframe(time: 0.2, value: 1),
            ])])

        XCTAssertThrowsError(try clip.resolved(for: rig)) {
            XCTAssertEqual($0 as? SkeletonError, .keysNotSorted(bone: "hand"))
        }
    }

    func testZeroDurationIsRejected() {
        let clip = AnimationClip(name: "empty", duration: 0, loops: true, tracks: [])

        XCTAssertThrowsError(try clip.resolved(for: rig)) {
            XCTAssertEqual($0 as? SkeletonError, .invalidDuration(clip: "empty"))
        }
    }

    func testResolvedClipKeepsNameDurationAndLooping() throws {
        let resolved = try makeTurnClip(loops: true).resolved(for: rig)

        XCTAssertEqual(resolved.name, "turn")
        XCTAssertEqual(resolved.duration, 1)
        XCTAssertTrue(resolved.loops)
    }
}
