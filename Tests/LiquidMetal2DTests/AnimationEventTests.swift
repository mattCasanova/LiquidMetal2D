import XCTest
@testable import LiquidMetal2D

private func makeRig() -> SkeletonDefinition {
    SkeletonDefinition(
        bones: [
            Bone(name: "hips", parent: nil, length: 1, rest: .identity),
            Bone(name: "arms", parent: 0, length: 1, rest: .identity),
        ],
        attachments: [])
}

final class AnimationEventTests: XCTestCase {

    private let rig = makeRig()

    private func clip(_ name: String, duration: Float = 1, loops: Bool,
                      events: [AnimationEvent]) throws -> ResolvedClip {
        try AnimationClip(
            name: name, duration: duration, loops: loops,
            tracks: [BoneTrack(bone: "hips", rotation: [Keyframe(time: 0, value: 0)])],
            events: events
        ).resolved(for: rig)
    }

    /// An animator that records every notice as "layer:clip:event" or "layer:clip:finished".
    private func makeRecordingAnimator() -> (Animator, () -> [String]) {
        let animator = Animator(definition: rig)
        var log: [String] = []
        animator.onEvent = { layer, clip, name in log.append("\(layer):\(clip):\(name)") }
        animator.onClipFinished = { layer, clip in log.append("\(layer):\(clip):finished") }
        return (animator, { log })
    }

    // MARK: - Resolving

    func testEventsAreSortedOnResolve() throws {
        let resolved = try clip("walk", loops: true, events: [
            AnimationEvent(time: 0.5, name: "stepFar"),
            AnimationEvent(time: 0, name: "stepNear"),
        ])

        XCTAssertEqual(resolved.events.map(\.name), ["stepNear", "stepFar"])
    }

    func testEventOutsideTheClipIsRejected() {
        XCTAssertThrowsError(try clip("walk", loops: true, events: [AnimationEvent(time: 1.5, name: "late")])) {
            XCTAssertEqual($0 as? SkeletonError, .eventOutOfRange(clip: "walk", event: "late"))
        }
    }

    // MARK: - Firing

    func testOneShotEventsFireOnceInOrder() throws {
        let (animator, log) = makeRecordingAnimator()
        animator.play(try clip("jump", loops: false, events: [
            AnimationEvent(time: 0.3, name: "takeoff"),
            AnimationEvent(time: 0.8, name: "land"),
        ]))

        animator.update(dt: 0.2)
        XCTAssertEqual(log(), [])

        animator.update(dt: 0.2)
        XCTAssertEqual(log(), ["0:jump:takeoff"])

        animator.update(dt: 0.5)
        animator.update(dt: 0.5)
        XCTAssertEqual(log(), ["0:jump:takeoff", "0:jump:land", "0:jump:finished"])
    }

    func testEventAtZeroFiresOnTheFirstUpdate() throws {
        let (animator, log) = makeRecordingAnimator()
        animator.play(try clip("walk", loops: true, events: [AnimationEvent(time: 0, name: "step")]))

        animator.update(dt: 0.1)

        XCTAssertEqual(log(), ["0:walk:step"])
    }

    func testZeroStepFiresNothing() throws {
        let (animator, log) = makeRecordingAnimator()
        animator.play(try clip("walk", loops: true, events: [AnimationEvent(time: 0, name: "step")]))

        animator.update(dt: 0)

        XCTAssertEqual(log(), [])
    }

    func testLoopingClipFiresEveryLapEvenInOneBigStep() throws {
        let (animator, log) = makeRecordingAnimator()
        animator.play(try clip("walk", loops: true, events: [
            AnimationEvent(time: 0.25, name: "near"),
            AnimationEvent(time: 0.75, name: "far"),
        ]))

        animator.update(dt: 2.1)

        XCTAssertEqual(log(), ["0:walk:near", "0:walk:far", "0:walk:near", "0:walk:far"])
    }

    func testEventOnTheLapBoundaryFiresOncePerLap() throws {
        let (animator, log) = makeRecordingAnimator()
        animator.play(try clip("walk", loops: true, events: [AnimationEvent(time: 0, name: "step")]))

        for _ in 0..<10 {
            animator.update(dt: 0.25)
        }

        // Laps start at 0, 1 and 2; the step at 2.0 fires on the update covering [2.0, 2.25).
        XCTAssertEqual(log(), ["0:walk:step", "0:walk:step", "0:walk:step"])
    }

    func testOverrideLayerEventsReportTheirLayer() throws {
        let (animator, log) = makeRecordingAnimator()
        animator.play(try clip("slash", duration: 0.4, loops: false,
                               events: [AnimationEvent(time: 0.1, name: "swing")]), layer: 1)

        animator.update(dt: 0.2)

        XCTAssertEqual(log(), ["1:slash:swing"])
    }

    func testClipBeingCrossfadedAwayStaysQuiet() throws {
        let (animator, log) = makeRecordingAnimator()
        animator.play(try clip("walk", loops: true, events: [AnimationEvent(time: 0.5, name: "step")]))
        animator.update(dt: 0.1)

        animator.play(try clip("idle", loops: true, events: []), crossfade: 0.6)
        animator.update(dt: 0.5)

        XCTAssertEqual(log(), [])
    }

    func testRestartReplaysEventsButPlayingOnDoesNot() throws {
        let (animator, log) = makeRecordingAnimator()
        let jump = try clip("jump", loops: false, events: [AnimationEvent(time: 0.1, name: "takeoff")])
        animator.play(jump)
        animator.update(dt: 0.2)

        animator.play(jump, restart: false)
        animator.update(dt: 0.2)
        XCTAssertEqual(log(), ["0:jump:takeoff"])

        animator.play(jump, restart: true)
        animator.update(dt: 0.2)
        XCTAssertEqual(log(), ["0:jump:takeoff", "0:jump:takeoff"])
    }

    func testEventCallbackCanStartAnotherClipTheSameFrame() throws {
        let animator = Animator(definition: rig)
        let idle = try AnimationClip(
            name: "idle", duration: 1, loops: true,
            tracks: [BoneTrack(bone: "arms", rotation: [Keyframe(time: 0, value: 1.2)])]
        ).resolved(for: rig)
        animator.onEvent = { [unowned animator] _, _, name in
            if name == "release" { animator.play(idle) }
        }
        animator.play(try clip("throw", loops: false, events: [AnimationEvent(time: 0.1, name: "release")]))

        animator.update(dt: 0.2)

        XCTAssertEqual(animator.currentClipName(), "idle")
        XCTAssertEqual(animator.pose.local[1].rotation, 1.2, accuracy: 0.0001)
    }
}
