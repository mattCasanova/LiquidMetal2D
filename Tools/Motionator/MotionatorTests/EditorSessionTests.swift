import XCTest
import LiquidMetal2D
import MotionatorKit
@testable import Motionator

@MainActor
final class EditorSessionTests: XCTestCase {

    private func character(bones: [String], clips: [AnimationClip] = []) -> Character {
        var rig = SkeletonDefinition(
            bones: [Bone(name: bones[0], parent: nil, length: 1, rest: .identity)], attachments: [])
        for name in bones.dropFirst() {
            rig = try! RigEditor.addingBone(rig, named: name, parent: 0, length: 1, rest: .identity)  // swiftlint:disable:this force_try line_length
        }
        rig.attachments = bones.map { Attachment(name: $0 + "Part", bone: 0, size: Vec2(1, 1), offset: Vec2(0, 0)) }
        return Character(rig: rig, clips: clips)
    }

    func testReconcileKeepsTheSelectionByNameWhenTheRigChanges() {
        let session = EditorSession()
        let old = character(bones: ["root", "arm", "leg"])
        let new = character(bones: ["root", "leg"])

        session.selection = .bone(2)
        session.reconcile(from: old, to: new)
        XCTAssertEqual(session.selection, .bone(1), "the leg moved up one")

        session.selection = .bone(1)
        session.reconcile(from: old, to: new)
        XCTAssertNil(session.selection, "the arm is gone")

        session.selection = .attachment(2)
        session.reconcile(from: old, to: new)
        XCTAssertEqual(session.selection, .attachment(1))

        session.pendingBones = ["arm", "leg"]
        session.reconcile(from: old, to: new)
        XCTAssertEqual(session.pendingBones, ["leg"])
    }

    func testReconcileKeepsTheClipPlayheadKeysAndEventThatStillExist() {
        let session = EditorSession()
        var walk = AnimationClip(name: "walk", duration: 2, loops: true, tracks: [])
        walk = ClipEditor.settingKey(walk, bone: "arm", time: 1, value: .rotation(0.5))
        walk = ClipEditor.settingKey(walk, bone: "arm", time: 2, value: .rotation(0.7))
        walk.events = [AnimationEvent(time: 0.5, name: "step")]
        let old = character(bones: ["root", "arm"], clips: [walk])

        session.mode = .animate
        session.clipName = "walk"
        session.playhead = 1.8
        session.selectedKeys = [
            KeyRef(bone: "arm", channel: .rotation, time: 1), KeyRef(bone: "arm", channel: .rotation, time: 2)
        ]
        session.selectedEvent = 0

        var shorter = ClipEditor.settingDuration(walk, to: 1.5, scalingKeys: false)
        shorter.events = []
        session.reconcile(from: old, to: character(bones: ["root", "arm"], clips: [shorter]))
        XCTAssertEqual(session.clipName, "walk")
        XCTAssertEqual(session.playhead, 1.5, "clamped to the new length")
        XCTAssertEqual(session.selectedKeys, [KeyRef(bone: "arm", channel: .rotation, time: 1)])
        XCTAssertNil(session.selectedEvent)

        session.reconcile(from: old, to: character(bones: ["root", "arm"]))
        XCTAssertNil(session.clipName, "the clip is gone")
        XCTAssertEqual(session.selectedKeys, [])
    }
}
