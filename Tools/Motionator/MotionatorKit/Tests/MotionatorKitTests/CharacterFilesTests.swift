import XCTest
import LiquidMetal2D
@testable import MotionatorKit

final class CharacterFilesTests: XCTestCase {

    func testACharacterRoundTripsThroughItsFolder() throws {
        let original = try Fixtures.stickFigure()
        XCTAssertEqual(original.clips.count, 5)
        XCTAssertEqual(original.images.keys.sorted(), ["disc"])
        let folder = try Fixtures.temporaryFolder().appendingPathComponent("Stick.character")

        try CharacterFiles.save(original, to: folder)
        let loaded = try CharacterFiles.load(at: folder)

        XCTAssertEqual(loaded, original)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        XCTAssertEqual(names, ["Stick.rig.json", "clips", "images"])
        let clipNames = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("clips").path)
        XCTAssertEqual(clipNames.sorted(),
                       ["idle.clip.json", "jump.clip.json", "slash.clip.json", "throw.clip.json", "walk.clip.json"])
        // The same bytes the engine writes: no second format.
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("Stick.rig.json")),
                       try AnimationFiles.data(for: original.rig))
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("images/disc.png")), original.images["disc"])
    }

    func testAFolderContentsListEveryKnownFileByPath() throws {
        let character = try Fixtures.stickFigure()
        let folder = try Fixtures.temporaryFolder().appendingPathComponent("Stick.character")
        try CharacterFiles.save(character, to: folder)
        try Data("not ours".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        try Data("not ours".utf8).write(to: folder.appendingPathComponent("clips/readme.md"))

        let onDisk = try CharacterFiles.contents(at: folder)
        let written = CharacterFiles.contents(of: try CharacterFiles.wrapper(for: character, rigName: "Stick"))

        XCTAssertEqual(onDisk.keys.sorted(), [
            "Stick.rig.json", "clips/idle.clip.json", "clips/jump.clip.json", "clips/slash.clip.json",
            "clips/throw.clip.json", "clips/walk.clip.json", "images/disc.png"
        ])
        XCTAssertEqual(onDisk, written, "what the wrapper holds is what lands on disk")

        try Data("{}".utf8).write(to: folder.appendingPathComponent("clips/idle.clip.json"))
        XCTAssertNotEqual(try CharacterFiles.contents(at: folder), written)
    }

    func testAClipThatDoesNotFitTheRigIsNamed() throws {
        var character = try Fixtures.stickFigure()
        var bad = try Fixtures.walk()
        bad.name = "broken"
        bad.tracks[0].bone = "noSuchBone"
        character.clips.append(bad)
        let folder = try Fixtures.temporaryFolder().appendingPathComponent("Bad.character")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try AnimationFiles.data(for: character.rig).write(to: folder.appendingPathComponent("Bad.rig.json"))
        let clips = folder.appendingPathComponent("clips")
        try FileManager.default.createDirectory(at: clips, withIntermediateDirectories: true)
        try AnimationFiles.data(for: bad).write(to: clips.appendingPathComponent("broken.clip.json"))

        XCTAssertThrowsError(try CharacterFiles.load(at: folder)) { error in
            guard case CharacterError.clipDoesNotFit(let clip, let reason) = error else {
                return XCTFail("\(error)")
            }
            XCTAssertEqual(clip, "broken")
            XCTAssertTrue(reason.contains("noSuchBone"), reason)
        }
    }

    func testAFolderWithNoRigIsRefused() throws {
        let folder = try Fixtures.temporaryFolder().appendingPathComponent("Empty.character")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        XCTAssertThrowsError(try CharacterFiles.load(at: folder)) { error in
            XCTAssertEqual(error as? CharacterError, .noRig("Empty.character"))
        }
    }

    func testMissingImagesAreListedNotFatal() throws {
        var character = try Fixtures.stickFigure()
        character.images = [:]
        XCTAssertEqual(character.missingImages, ["disc"])
        XCTAssertNoThrow(try CharacterFiles.validate(character))
    }
}
