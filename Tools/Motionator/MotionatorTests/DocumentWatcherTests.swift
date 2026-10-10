import XCTest
import LiquidMetal2D
import MotionatorKit
@testable import Motionator

@MainActor
final class DocumentWatcherTests: XCTestCase {

    private func folder() throws -> URL {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MotionatorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let folder = parent.appendingPathComponent("Hero.character")
        try CharacterFiles.save(CharacterDocument().character, to: folder)
        return folder
    }

    func testAChangeInsideTheClipsFolderIsReported() async throws {
        let folder = try folder()
        let reported = expectation(description: "a change in clips/")
        let watcher = DocumentWatcher(url: folder, settleDelay: 0.05) { reported.fulfill() }

        try Data("{}".utf8).write(to: folder.appendingPathComponent("clips/idle.clip.json"))

        await fulfillment(of: [reported], timeout: 2)
        withExtendedLifetime(watcher) {}
    }

    func testAFileWrittenInPlaceIsReported() async throws {
        let folder = try folder()
        let reported = expectation(description: "the rig was written in place")
        let watcher = DocumentWatcher(url: folder, settleDelay: 0.05) { reported.fulfill() }

        // What a text editor or a script does: the same file, new bytes, no rename.
        let handle = try FileHandle(forWritingTo: folder.appendingPathComponent("Hero.rig.json"))
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data("{}".utf8))
        try handle.close()

        await fulfillment(of: [reported], timeout: 2)
        withExtendedLifetime(watcher) {}
    }

    func testAFolderReplacedWholeIsReportedAndWatchingGoesOn() async throws {
        let folder = try folder()
        var count = 0
        let first = expectation(description: "the folder was replaced")
        let second = expectation(description: "a change inside the new folder")
        let watcher = DocumentWatcher(url: folder, settleDelay: 0.05) {
            count += 1
            (count == 1 ? first : second).fulfill()
        }

        // What a safe save does: a new folder takes the old one's place.
        var character = CharacterDocument().character
        character.rig.bones[0].name = "pelvis"
        try CharacterFiles.save(character, to: folder)
        await fulfillment(of: [first], timeout: 2)

        try Data("{}".utf8).write(to: folder.appendingPathComponent("clips/idle.clip.json"))
        await fulfillment(of: [second], timeout: 2)
        withExtendedLifetime(watcher) {}
    }
}
