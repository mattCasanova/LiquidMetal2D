import XCTest
@testable import LiquidMetal2D

/// Three bones, all at rest rotation 0: `hips` (root), `legs` and `arms` hanging off it.
private func makeRig() -> SkeletonDefinition {
    SkeletonDefinition(
        bones: [
            Bone(name: "hips", parent: nil, length: 1, rest: .identity),
            Bone(name: "legs", parent: 0, length: 1, rest: .identity),
            Bone(name: "arms", parent: 0, length: 1, rest: .identity),
        ],
        attachments: [])
}

private let hips = 0
private let legs = 1
private let arms = 2

final class AnimatorTests: XCTestCase {

    private let epsilon: Float = 0.0001
    private let rig = makeRig()

    /// A clip that holds one bone at a fixed rotation.
    private func hold(_ name: String, bone: String, at value: Float,
                      loops: Bool = true, duration: Float = 1) throws -> ResolvedClip {
        try AnimationClip(
            name: name, duration: duration, loops: loops,
            tracks: [BoneTrack(bone: bone, rotation: [Keyframe(time: 0, value: value)])]
        ).resolved(for: rig)
    }

    /// A one-shot clip that turns `hips` from 0 to 1 radian over one second.
    private func ramp() throws -> ResolvedClip {
        try AnimationClip(
            name: "ramp", duration: 1, loops: false,
            tracks: [BoneTrack(bone: "hips", rotation: [
                Keyframe(time: 0, value: 0),
                Keyframe(time: 1, value: 1),
            ])]
        ).resolved(for: rig)
    }

    private func rotation(_ animator: Animator, _ bone: Int) -> Float {
        animator.pose.local[bone].rotation
    }

    // MARK: - Time

    func testEmptyAnimatorHoldsRest() {
        let animator = Animator(definition: rig)
        animator.update(dt: 0.5)

        XCTAssertEqual(animator.pose, Pose(restOf: rig))
    }

    func testUpdateAdvancesByDtTimesSpeed() throws {
        let animator = Animator(definition: rig)
        animator.play(try ramp())

        animator.update(dt: 0.25)
        XCTAssertEqual(rotation(animator, hips), 0.25, accuracy: epsilon)

        animator.speed = 2
        animator.update(dt: 0.25)
        XCTAssertEqual(rotation(animator, hips), 0.75, accuracy: epsilon)
    }

    func testLoopingClipNeverFinishes() throws {
        let animator = Animator(definition: rig)
        var finishes = 0
        animator.onClipFinished = { _, _ in finishes += 1 }
        animator.play(try hold("idle", bone: "hips", at: 0.3))

        animator.update(dt: 5)

        XCTAssertFalse(animator.isFinished())
        XCTAssertEqual(finishes, 0)
    }

    func testOneShotFinishesOnceAndHoldsItsLastFrame() throws {
        let animator = Animator(definition: rig)
        var events: [String] = []
        animator.onClipFinished = { layer, name in events.append("\(layer):\(name)") }
        animator.play(try ramp())

        animator.update(dt: 0.6)
        animator.update(dt: 0.6)
        animator.update(dt: 1)

        XCTAssertTrue(animator.isFinished())
        XCTAssertEqual(events, ["0:ramp"])
        XCTAssertEqual(rotation(animator, hips), 1, accuracy: epsilon)
    }

    func testPlayingTheSameClipWithoutRestartKeepsItsTime() throws {
        let animator = Animator(definition: rig)
        let clip = try ramp()
        animator.play(clip)
        animator.update(dt: 0.5)

        animator.play(clip, restart: false)
        animator.update(dt: 0)
        XCTAssertEqual(rotation(animator, hips), 0.5, accuracy: epsilon)

        animator.play(clip, restart: true)
        animator.update(dt: 0)
        XCTAssertEqual(rotation(animator, hips), 0, accuracy: epsilon)
    }

    // MARK: - Crossfade

    func testCrossfadeBlendsOverItsDuration() throws {
        let animator = Animator(definition: rig)
        animator.play(try hold("a", bone: "hips", at: 0))
        animator.update(dt: 0.1)

        animator.play(try hold("b", bone: "hips", at: 1), crossfade: 0.2)
        animator.update(dt: 0.1)
        XCTAssertEqual(rotation(animator, hips), 0.5, accuracy: epsilon)

        animator.update(dt: 0.1)
        XCTAssertEqual(rotation(animator, hips), 1, accuracy: epsilon)

        animator.update(dt: 0.5)
        XCTAssertEqual(rotation(animator, hips), 1, accuracy: epsilon)
        XCTAssertEqual(animator.currentClipName(), "b")
    }

    func testFirstPlayWithCrossfadeFadesInFromRest() throws {
        let animator = Animator(definition: rig)
        animator.play(try hold("b", bone: "hips", at: 1), crossfade: 0.2)

        animator.update(dt: 0.1)

        XCTAssertEqual(rotation(animator, hips), 0.5, accuracy: epsilon)
    }

    func testCrossfadeReturnsBonesOnlyTheOldClipKeyed() throws {
        let animator = Animator(definition: rig)
        animator.play(try hold("wave", bone: "arms", at: 2))
        animator.update(dt: 0)

        animator.play(try hold("kick", bone: "legs", at: 1.5), crossfade: 0.2)
        animator.update(dt: 0.1)
        XCTAssertEqual(rotation(animator, arms), 1, accuracy: epsilon)
        XCTAssertEqual(rotation(animator, legs), 0.75, accuracy: epsilon)

        animator.update(dt: 0.1)
        XCTAssertEqual(rotation(animator, arms), 0, accuracy: epsilon)
        XCTAssertEqual(rotation(animator, legs), 1.5, accuracy: epsilon)
    }

    // MARK: - Override layers

    func testOverrideLayerChangesOnlyTheBonesItKeys() throws {
        let animator = Animator(definition: rig)
        animator.play(try hold("run", bone: "legs", at: 1))
        animator.play(try hold("slash", bone: "arms", at: 2), layer: 1)

        animator.update(dt: 0)

        XCTAssertEqual(rotation(animator, hips), 0, accuracy: epsilon)
        XCTAssertEqual(rotation(animator, legs), 1, accuracy: epsilon)
        XCTAssertEqual(rotation(animator, arms), 2, accuracy: epsilon)
    }

    func testOverrideLayerWinsOnASharedBone() throws {
        let animator = Animator(definition: rig)
        animator.play(try hold("swing", bone: "arms", at: 1))
        animator.play(try hold("slash", bone: "arms", at: 3), layer: 1)

        animator.update(dt: 0)

        XCTAssertEqual(rotation(animator, arms), 3, accuracy: epsilon)
    }

    func testOverrideLayerFadesIn() throws {
        let animator = Animator(definition: rig)
        animator.play(try hold("swing", bone: "arms", at: 1))
        animator.play(try hold("slash", bone: "arms", at: 3), layer: 1, crossfade: 0.2)

        animator.update(dt: 0.1)

        XCTAssertEqual(rotation(animator, arms), 2, accuracy: epsilon)
        XCTAssertEqual(animator.weight(layer: 1), 0.5, accuracy: epsilon)
    }

    func testStopFadesTheLayerOutAndEmptiesIt() throws {
        let animator = Animator(definition: rig)
        animator.play(try hold("swing", bone: "arms", at: 1))
        animator.play(try hold("slash", bone: "arms", at: 3), layer: 1)
        animator.update(dt: 0)

        animator.stop(layer: 1, fadeOut: 0.2)
        animator.update(dt: 0.1)
        XCTAssertEqual(rotation(animator, arms), 2, accuracy: epsilon)

        animator.update(dt: 0.1)
        XCTAssertEqual(rotation(animator, arms), 1, accuracy: epsilon)
        XCTAssertNil(animator.currentClipName(layer: 1))
    }

    func testStopWithoutFadeIsImmediate() throws {
        let animator = Animator(definition: rig)
        animator.play(try hold("swing", bone: "arms", at: 1))
        animator.play(try hold("slash", bone: "arms", at: 3), layer: 1)
        animator.update(dt: 0)

        animator.stop(layer: 1)
        animator.update(dt: 0)

        XCTAssertEqual(rotation(animator, arms), 1, accuracy: epsilon)
        XCTAssertNil(animator.currentClipName(layer: 1))
    }

    func testOneShotOverrideFadesOutWhenFinished() throws {
        let animator = Animator(definition: rig)
        var events: [String] = []
        animator.onClipFinished = { layer, name in events.append("\(layer):\(name)") }
        animator.play(try hold("swing", bone: "arms", at: 1))
        animator.play(try hold("slash", bone: "arms", at: 3, loops: false, duration: 0.5),
                      layer: 1, fadeOutWhenFinished: 0.2)

        animator.update(dt: 0.5)
        XCTAssertEqual(rotation(animator, arms), 3, accuracy: epsilon)

        animator.update(dt: 0.1)
        XCTAssertEqual(rotation(animator, arms), 2, accuracy: epsilon)

        animator.update(dt: 0.1)
        XCTAssertEqual(rotation(animator, arms), 1, accuracy: epsilon)
        XCTAssertNil(animator.currentClipName(layer: 1))
        XCTAssertEqual(events, ["1:slash"])
    }

    func testCrossfadeBetweenOverrideClipsHandsBonesBackToTheBase() throws {
        let animator = Animator(definition: rig)
        animator.play(try hold("base", bone: "arms", at: 1))
        animator.play(try hold("wave", bone: "arms", at: 3), layer: 1)
        animator.update(dt: 0)

        animator.play(try hold("kick", bone: "legs", at: 1.5), layer: 1, crossfade: 0.2)
        animator.update(dt: 0.1)
        XCTAssertEqual(rotation(animator, arms), 2, accuracy: epsilon)
        XCTAssertEqual(rotation(animator, legs), 0.75, accuracy: epsilon)

        animator.update(dt: 0.1)

        // "kick" keys only the legs, so the arms go back to what the base layer says.
        XCTAssertEqual(rotation(animator, arms), 1, accuracy: epsilon)
        XCTAssertEqual(rotation(animator, legs), 1.5, accuracy: epsilon)
    }

    func testFullWeightLayersKeepAnglesBeyondPiExactly() throws {
        let animator = Animator(definition: rig)
        animator.play(try hold("spin", bone: "hips", at: 4))
        animator.play(try hold("reach", bone: "arms", at: -5), layer: 1)

        animator.update(dt: 0)

        XCTAssertEqual(rotation(animator, hips), 4, accuracy: epsilon)
        XCTAssertEqual(rotation(animator, arms), -5, accuracy: epsilon)
    }

    // MARK: - Callbacks

    func testFinishedCallbackCanPlayTheNextClipSameFrame() throws {
        let animator = Animator(definition: rig)
        let next = try hold("idle", bone: "hips", at: 5)
        animator.onClipFinished = { [unowned animator] _, _ in animator.play(next) }
        animator.play(try ramp())

        animator.update(dt: 1)

        XCTAssertEqual(animator.currentClipName(), "idle")
        XCTAssertEqual(rotation(animator, hips), 5, accuracy: epsilon)
    }
}
