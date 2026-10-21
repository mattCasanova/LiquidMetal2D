import XCTest
import LiquidMetal2D
import MotionatorKit
import SwiftUI
@testable import Motionator

@MainActor
final class CharacterDocumentTests: XCTestCase {

    func testApplyKeepsTheOldValueForUndoAndRedo() throws {
        let document = CharacterDocument()
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        XCTAssertEqual(document.character.rig.bones.count, 1)

        undoManager.beginUndoGrouping()
        document.apply({ character in
            var character = character
            character.rig = try! RigEditor.addingBone(  // swiftlint:disable:this force_try
                character.rig, named: "arm", parent: 0, length: 2, rest: .identity)
            return character
        }, named: "Add Bone", undoManager: undoManager)
        undoManager.endUndoGrouping()

        XCTAssertEqual(document.character.rig.bones.map(\.name), ["root", "arm"])
        XCTAssertEqual(document.version, 1)
        XCTAssertEqual(undoManager.undoActionName, "Add Bone")

        undoManager.undo()
        XCTAssertEqual(document.character.rig.bones.map(\.name), ["root"])
        XCTAssertEqual(document.version, 2, "an undo is a change the viewport must see")

        undoManager.redo()
        XCTAssertEqual(document.character.rig.bones.map(\.name), ["root", "arm"])
    }

    func testANewDocumentSnapshotsAsACharacterFolder() throws {
        let document = CharacterDocument()
        let snapshot = try document.snapshot(contentType: .character)
        XCTAssertEqual(snapshot.rigName, "character")
        XCTAssertEqual(snapshot.character, document.character)

        let wrapper = try CharacterFiles.wrapper(for: snapshot.character, rigName: snapshot.rigName)

        XCTAssertTrue(wrapper.isDirectory)
        let names = try XCTUnwrap(wrapper.fileWrappers?.keys.sorted())
        XCTAssertEqual(names, ["character.rig.json", "clips", "images"])
    }

    func testAReloadTakesOutsideChangesAndIgnoresTheDocumentsOwnWrites() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MotionatorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let folder = parent.appendingPathComponent("Hero.character")
        try CharacterFiles.save(CharacterDocument().character, to: folder)
        let document = try CharacterDocument(contentsOf: folder)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        XCTAssertFalse(try document.hasChangedOnDisk(at: folder))
        XCTAssertNil(try document.reloadIfChanged(at: folder, undoManager: undoManager), "nothing changed")

        // The document's own save: the system writes the wrapper it hands over.
        undoManager.beginUndoGrouping()
        document.apply({ character in
            var character = character
            character.rig = try! RigEditor.addingBone(  // swiftlint:disable:this force_try
                character.rig, named: "arm", parent: 0, length: 2, rest: .identity)
            return character
        }, named: "Add Bone", undoManager: undoManager)
        undoManager.endUndoGrouping()
        let wrapper = try document.wrapper(for: try document.snapshot(contentType: .character))
        try wrapper.write(to: folder, options: .atomic, originalContentsURL: nil)
        XCTAssertFalse(try document.hasChangedOnDisk(at: folder))
        XCTAssertNil(try document.reloadIfChanged(at: folder, undoManager: undoManager))
        XCTAssertTrue(undoManager.canUndo, "an own write keeps the undo stack")

        // Someone else adds a clip.
        var outside = document.character
        outside.clips.append(AnimationClip(name: "idle", duration: 1, loops: true, tracks: []))
        try CharacterFiles.save(outside, to: folder)
        XCTAssertTrue(try document.hasChangedOnDisk(at: folder))
        let previous = try XCTUnwrap(try document.reloadIfChanged(at: folder, undoManager: undoManager))
        XCTAssertEqual(previous.clips.count, 0)
        XCTAssertEqual(document.character.clips.map(\.name), ["idle"])
        XCTAssertEqual(document.character.rig.bones.map(\.name), ["root", "arm"])
        XCTAssertEqual(document.version, 2)
        XCTAssertFalse(undoManager.canUndo, "undo would bring back a character no longer on disk")
        XCTAssertNil(try document.reloadIfChanged(at: folder, undoManager: undoManager), "now known")

        // A folder that does not read is left for the next change.
        try Data("{".utf8).write(to: folder.appendingPathComponent("clips/idle.clip.json"))
        XCTAssertThrowsError(try document.reloadIfChanged(at: folder, undoManager: undoManager))
        XCTAssertEqual(document.character.clips.map(\.name), ["idle"])
        XCTAssertTrue(try document.hasChangedOnDisk(at: folder))
    }

    func testOpeningAFolderKeepsItsRigName() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MotionatorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let folder = parent.appendingPathComponent("Hero.character")
        var character = CharacterDocument().character
        character.rig.bones[0].name = "pelvis"
        try CharacterFiles.save(character, to: folder)
        let file = try FileWrapper(url: folder, options: .immediate)

        XCTAssertEqual(CharacterDocument.rigName(in: file), "Hero")
        XCTAssertNil(CharacterDocument.rigName(in: FileWrapper(directoryWithFileWrappers: [:])))
        XCTAssertEqual(try CharacterFiles.read(file).rig.bones[0].name, "pelvis")
    }
}
