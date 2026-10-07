import XCTest
import LiquidMetal2D
@testable import MotionatorKit

final class ClipEditorTests: XCTestCase {

    private func track(_ clip: AnimationClip, _ bone: String) -> BoneTrack? { clip.tracks.first { $0.bone == bone } }

    func testSettingAKeyInsertsInOrderAndReplacesAtTheSameTime() throws {
        let walk = try Fixtures.walk()
        let before = try XCTUnwrap(track(walk, "thighNear")).rotation.map(\.time)
        XCTAssertEqual(before, [0, 0.5, 1])

        var clip = ClipEditor.settingKey(walk, bone: "thighNear", time: 0.25, value: .rotation(-1.5))
        var keys = try XCTUnwrap(track(clip, "thighNear")).rotation
        XCTAssertEqual(keys.map(\.time), [0, 0.25, 0.5, 1])
        XCTAssertEqual(keys[1].value, -1.5)
        XCTAssertEqual(keys[1].easing, .easeInOutSine, "inherits the key before it")

        clip = ClipEditor.settingKey(
            clip, bone: "thighNear", time: 0.25 + 5e-5, value: .rotation(-1.6), easing: .linear)
        keys = try XCTUnwrap(track(clip, "thighNear")).rotation
        XCTAssertEqual(keys.count, 4, "the same time replaces")
        XCTAssertEqual(keys[1].value, -1.6)
        XCTAssertEqual(keys[1].easing, .linear)
        XCTAssertEqual(track(clip, "thighFar"), track(walk, "thighFar"), "other tracks untouched")
    }

    func testAKeyOnANewBoneMakesATrack() throws {
        let walk = try Fixtures.walk()
        XCTAssertNil(track(walk, "sword"))
        let clip = ClipEditor.settingKey(walk, bone: "sword", time: 0.5, value: .position(Vec2(1, 2)))
        let sword = try XCTUnwrap(track(clip, "sword"))
        XCTAssertEqual(sword.position.map(\.value), [Vec2(1, 2)])
        XCTAssertEqual(sword.position[0].easing, .linear, "no key before it: linear")
        XCTAssertTrue(sword.rotation.isEmpty)
    }

    func testRemovingAKeyDropsOnlyItAndAnEmptyTrackGoes() throws {
        let walk = try Fixtures.walk()
        var clip = ClipEditor.removingKey(walk, bone: "thighNear", channel: .rotation, time: 0.5)
        XCTAssertEqual(try XCTUnwrap(track(clip, "thighNear")).rotation.map(\.time), [0, 1])

        for time in [Float(0), 1] {
            clip = ClipEditor.removingKey(clip, bone: "thighNear", channel: .rotation, time: time)
        }
        XCTAssertNil(track(clip, "thighNear"))
        XCTAssertEqual(clip.tracks.count, walk.tracks.count - 1)
    }

    func testMovingKeysShiftsAndClamps() throws {
        let walk = try Fixtures.walk()
        let keys: Set<KeyRef> = [
            KeyRef(bone: "thighNear", channel: .rotation, time: 0.5),
            KeyRef(bone: "thighNear", channel: .rotation, time: 1),
        ]
        let clip = ClipEditor.movingKeys(walk, keys, by: 0.2)
        let times = try XCTUnwrap(track(clip, "thighNear")).rotation.map(\.time)
        XCTAssertEqual(times, [0, 0.7, 1], "0.5 → 0.7; 1 clamps to the end")
        XCTAssertEqual(try XCTUnwrap(track(clip, "thighNear")).rotation[1].value, -2.0943952, accuracy: 1e-6)
    }

    func testAMovedKeyReplacesTheOneItLandsOn() throws {
        let walk = try Fixtures.walk()
        let clip = ClipEditor.movingKeys(walk, [KeyRef(bone: "thighNear", channel: .rotation, time: 0)], by: 0.5)
        let keys = try XCTUnwrap(track(clip, "thighNear")).rotation
        XCTAssertEqual(keys.map(\.time), [0.5, 1])
        XCTAssertEqual(keys[0].value, -1.0471976, accuracy: 1e-6, "the moved key's value")
    }

    func testPoseMatchesTheEnginesSampling() throws {
        let character = try Fixtures.stickFigure()
        let walk = try Fixtures.walk()
        let resolved = try walk.resolved(for: character.rig)
        for time in [Float(0), 0.25, 0.5] {
            var expected = Pose(restOf: character.rig)
            resolved.sample(at: time, definition: character.rig, into: &expected)
            XCTAssertEqual(try ClipEditor.pose(of: walk, rig: character.rig, at: time), expected, "at \(time)")
        }
    }

    func testPastingAPoseKeysOnlyWhatMoved() throws {
        let rig = Fixtures.twoBones()
        var pose = Pose(restOf: rig)
        pose.local[1].rotation = 1.2
        let empty = AnimationClip(name: "pose", duration: 1, loops: false, tracks: [])

        let clip = ClipEditor.pastingPose(pose, into: empty, rig: rig, at: 0.5)

        XCTAssertEqual(clip.tracks.count, 1)
        XCTAssertEqual(clip.tracks[0].bone, "lower")
        XCTAssertEqual(clip.tracks[0].rotation.map(\.value), [1.2])
        XCTAssertTrue(clip.tracks[0].position.isEmpty, "the position stayed at rest")
    }

    func testSettingDurationScalesOrDrops() throws {
        let walk = try Fixtures.walk()
        let scaled = ClipEditor.settingDuration(walk, to: 2, scalingKeys: true)
        XCTAssertEqual(try XCTUnwrap(track(scaled, "thighNear")).rotation.map(\.time), [0, 1, 2])
        XCTAssertEqual(scaled.events.map(\.time), [0, 1])

        let cut = ClipEditor.settingDuration(walk, to: 0.6, scalingKeys: false)
        XCTAssertEqual(try XCTUnwrap(track(cut, "thighNear")).rotation.map(\.time), [0, 0.5])
        XCTAssertEqual(cut.events.map(\.time), [0, 0.5])
        XCTAssertEqual(cut.duration, 0.6)
    }

    func testEventsStayInTimeOrder() throws {
        let walk = try Fixtures.walk()
        var clip = ClipEditor.addingEvent(walk, named: "swing", at: 0.25)
        XCTAssertEqual(clip.events.map(\.name), ["step", "swing", "step"])
        clip = ClipEditor.movingEvent(clip, at: 1, to: 0.9)
        XCTAssertEqual(clip.events.map(\.name), ["step", "step", "swing"])
        clip = ClipEditor.renamingEvent(clip, at: 2, to: "slash")
        XCTAssertEqual(clip.events[2].name, "slash")
        clip = ClipEditor.removingEvent(clip, at: 0)
        XCTAssertEqual(clip.events.map(\.name), ["step", "slash"])
    }

    func testKeyTimesAndNeighbours() throws {
        let walk = try Fixtures.walk()
        XCTAssertEqual(ClipEditor.keyTimes(in: walk), [0, 0.25, 0.5, 0.75, 1])
        XCTAssertEqual(ClipEditor.keyTime(in: walk, before: 0.5), 0.25)
        XCTAssertEqual(ClipEditor.keyTime(in: walk, after: 0.5), 0.75)
        XCTAssertNil(ClipEditor.keyTime(in: walk, before: 0))
        XCTAssertNil(ClipEditor.keyTime(in: walk, after: 1))
    }

    func testSnappingToAFrameGrid() {
        XCTAssertEqual(ClipEditor.snapped(0.1234, fps: 24), 3 / 24, accuracy: 1e-6)
        XCTAssertEqual(ClipEditor.snapped(0.1234, fps: nil), 0.1234)
        XCTAssertEqual(ClipEditor.snapped(0.4999, fps: 30), 0.5, accuracy: 1e-6)
    }

    func testKeyingWritesOnlyTheChannelsThatMoved() throws {
        let rig = Fixtures.twoBones()
        let empty = AnimationClip(name: "pose", duration: 1, loops: false, tracks: [])
        let old = Pose(restOf: rig)
        var new = old
        new.local[1].rotation += 0.4

        let change = ClipEditor.PoseChange(from: old, to: new)
        let keyed = ClipEditor.keying(empty, bone: 1, change: change, rig: rig, at: 0.5)
        XCTAssertEqual(keyed.tracks.count, 1)
        XCTAssertEqual(keyed.tracks[0].bone, "lower")
        XCTAssertEqual(keyed.tracks[0].rotation.map(\.time), [0.5])
        XCTAssertTrue(keyed.tracks[0].position.isEmpty)

        let same = ClipEditor.keying(empty, bone: 0, change: change, rig: rig, at: 0.5)
        XCTAssertTrue(same.tracks.isEmpty, "the upper bone did not move")
    }

    func testKeyingABoneByHandTakesItsRotationAndPositionWhenOffRest() throws {
        let rig = Fixtures.twoBones()
        let empty = AnimationClip(name: "pose", duration: 1, loops: false, tracks: [])
        var pose = Pose(restOf: rig)
        pose.local[0].rotation = 1
        let rotated = ClipEditor.keyingBone(empty, bone: 0, pose: pose, rig: rig, at: 0.25)
        XCTAssertEqual(rotated.tracks[0].rotation.count, 1)
        XCTAssertTrue(rotated.tracks[0].position.isEmpty, "at its rest position: no position key")

        pose.local[0].position.x += 1
        let moved = ClipEditor.keyingBone(empty, bone: 0, pose: pose, rig: rig, at: 0.25)
        XCTAssertEqual(moved.tracks[0].position.count, 1)
    }

    func testDuplicatingKeysCopiesThemLater() throws {
        let walk = try Fixtures.walk()
        let key = KeyRef(bone: "thighNear", channel: .rotation, time: 0.5)
        let clip = ClipEditor.duplicatingKeys(walk, [key], by: 0.25)
        XCTAssertEqual(try XCTUnwrap(track(clip, "thighNear")).rotation.map(\.time), [0, 0.5, 0.75, 1])
        let copy = KeyRef(bone: "thighNear", channel: .rotation, time: 0.75)
        XCTAssertEqual(try XCTUnwrap(ClipEditor.key(in: clip, copy)).value, .rotation(-2.0943952))
    }

    func testKeysAtATimeAndEasing() throws {
        let walk = try Fixtures.walk()
        let atHalf = ClipEditor.keys(in: walk, at: 0.5)
        XCTAssertTrue(atHalf.contains(KeyRef(bone: "thighNear", channel: .rotation, time: 0.5)))
        XCTAssertTrue(atHalf.allSatisfy { abs($0.time - 0.5) < 1e-4 })

        let eased = ClipEditor.settingEasing(walk, atHalf, to: .easeOutBounce)
        for key in atHalf {
            XCTAssertEqual(try XCTUnwrap(ClipEditor.key(in: eased, key)).easing, .easeOutBounce)
        }
        let untouched = KeyRef(bone: "thighNear", channel: .rotation, time: 0)
        XCTAssertEqual(try XCTUnwrap(ClipEditor.key(in: eased, untouched)).easing, .easeInOutSine, "others keep theirs")
    }
}
