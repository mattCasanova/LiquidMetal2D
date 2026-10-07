import XCTest
import LiquidMetal2D
@testable import MotionatorKit

final class RigEditorTests: XCTestCase {

    private func assertSameWorld(
        _ a: [RigidTransform2D], _ b: [RigidTransform2D], file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(a.count, b.count, file: file, line: line)
        for (x, y) in zip(a, b) {
            XCTAssertEqual(x.position.x, y.position.x, accuracy: 1e-4, file: file, line: line)
            XCTAssertEqual(x.position.y, y.position.y, accuracy: 1e-4, file: file, line: line)
            XCTAssertEqual(x.rotation, y.rotation, accuracy: 1e-4, file: file, line: line)
        }
    }

    func testRemovingABoneReparentsItsChildrenInPlace() throws {
        let character = try Fixtures.stickFigure()
        let rig = character.rig
        let spine = try rig.boneIndex(named: "spine")
        let head = try rig.boneIndex(named: "head")
        let before = RigEditor.restWorld(of: rig)

        let (edited, clips) = try RigEditor.removingBone(rig, spine, in: character.clips)

        let newHead = try edited.boneIndex(named: "head")
        XCTAssertEqual(edited.bones[newHead].parent, rig.bones[spine].parent, "to the grandparent")
        assertSameWorld([RigEditor.restWorld(of: edited)[newHead]], [before[head]])
        XCTAssertFalse(edited.attachments.contains { edited.bones[$0.bone].name == "spine" })
        let onSpine = rig.attachments.filter { $0.bone == spine }.count
        XCTAssertEqual(edited.attachments.count, rig.attachments.count - onSpine)
        XCTAssertFalse(clips.contains { $0.tracks.contains { $0.bone == "spine" } })
        XCTAssertNoThrow(try CharacterFiles.validate(Character(rig: edited, clips: clips)))
    }

    func testReparentingKeepsTheWorldRestPose() throws {
        let rig = try Fixtures.stickFigure().rig
        let hand = try rig.boneIndex(named: "lowerArmNear")
        let head = try rig.boneIndex(named: "head")
        let before = RigEditor.restWorld(of: rig)

        let edited = try RigEditor.reparenting(rig, hand, to: head)

        let newHand = try edited.boneIndex(named: "lowerArmNear")
        XCTAssertEqual(edited.bones[newHand].parent, try edited.boneIndex(named: "head"))
        let after = RigEditor.restWorld(of: edited)
        for bone in rig.bones {
            assertSameWorld([after[try edited.boneIndex(named: bone.name)]],
                            [before[try rig.boneIndex(named: bone.name)]])
        }
        XCTAssertNoThrow(try edited.validate(), "parents before children after the reorder")
    }

    func testReparentingToADescendantIsRefused() throws {
        let rig = try Fixtures.stickFigure().rig
        let spine = try rig.boneIndex(named: "spine")
        let head = try rig.boneIndex(named: "head")
        XCTAssertThrowsError(try RigEditor.reparenting(rig, spine, to: head)) { error in
            XCTAssertEqual(error as? RigEditError, .cycle(bone: "spine", parent: "head"))
        }
    }

    func testRenamingABoneRenamesItsTracks() throws {
        let character = try Fixtures.stickFigure()
        let thigh = try character.rig.boneIndex(named: "thighNear")

        let (rig, clips) = try RigEditor.renamingBone(character.rig, thigh, to: "legNear", in: character.clips)

        XCTAssertEqual(rig.bones[thigh].name, "legNear")
        let walk = try XCTUnwrap(clips.first { $0.name == "walk" })
        XCTAssertTrue(walk.tracks.contains { $0.bone == "legNear" })
        XCTAssertFalse(walk.tracks.contains { $0.bone == "thighNear" })
        XCTAssertThrowsError(try RigEditor.renamingBone(rig, thigh, to: "head", in: clips)) { error in
            XCTAssertEqual(error as? RigEditError, .duplicateBoneName("head"))
        }
    }

    func testAddingAnAttachmentSizesItFromPixels() throws {
        let rig = Fixtures.twoBones()
        let edited = try RigEditor.addingAttachment(
            rig, image: "arm", pixelSize: Vec2(200, 50), pixelsPerUnit: 100, bone: 0)
        let arm = try XCTUnwrap(edited.attachments.last)
        XCTAssertEqual(arm.name, "arm")
        XCTAssertEqual(arm.textureName, "arm")
        XCTAssertEqual(arm.size, Vec2(2, 0.5))
        XCTAssertEqual(arm.offset, Vec2(1, 0), "centred on the bone")
        XCTAssertEqual(arm.drawOrder, 2, "on top")
        let again = try RigEditor.addingAttachment(
            edited, image: "arm", pixelSize: Vec2(10, 10), pixelsPerUnit: 10, bone: 1)
        XCTAssertEqual(again.attachments.last?.name, "arm 2")
    }

    func testAddingABoneAppendsAChild() throws {
        let rig = Fixtures.twoBones()
        let edited = try RigEditor.addingBone(
            rig, named: "tip", parent: 1, length: 0.5, rest: RigidTransform2D(position: Vec2(1, 0)))
        XCTAssertEqual(edited.bones.count, 3)
        XCTAssertEqual(edited.bones[2].parent, 1)
        XCTAssertThrowsError(try RigEditor.addingBone(edited, named: "tip", parent: nil, length: 1, rest: .identity))
    }

    func testMovingAttachmentsRenumbersTheDrawOrder() throws {
        let rig = try Fixtures.stickFigure().rig
        let before = RigEditor.attachmentsByDrawOrder(rig)
        let moved = RigEditor.movingAttachments(rig, from: IndexSet(integer: 0), to: 3)

        let after = RigEditor.attachmentsByDrawOrder(moved)
        XCTAssertEqual(after, [before[1], before[2], before[0]] + Array(before[3...]), "the first part now draws third")
        XCTAssertEqual(moved.attachments.map(\.drawOrder).sorted(), Array(0..<rig.attachments.count), "0… again")
        XCTAssertEqual(moved.attachments.map(\.name), rig.attachments.map(\.name), "the array order is untouched")
    }

    func testInvertedUndoesATransform() {
        let transform = RigidTransform2D(position: Vec2(3, -2), rotation: 0.7)
        let identity = transform.composed(with: transform.inverted)
        XCTAssertEqual(identity.position.x, 0, accuracy: 1e-6)
        XCTAssertEqual(identity.position.y, 0, accuracy: 1e-6)
        XCTAssertEqual(identity.rotation, 0, accuracy: 1e-6)
    }
}
