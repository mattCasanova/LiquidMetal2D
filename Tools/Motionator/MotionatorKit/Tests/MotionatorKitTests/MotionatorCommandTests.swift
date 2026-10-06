import XCTest
import Metal
@testable import MotionatorKit

@MainActor
final class MotionatorCommandTests: XCTestCase {

    private struct Result {
        var code: Int32
        var out: String
        var err: String
    }

    private func run(_ arguments: [String]) -> Result {
        var out = ""
        var err = ""
        let code = MotionatorCommand.run(arguments, out: { out += $0 + "\n" }, err: { err += $0 + "\n" })
        return Result(code: code, out: out, err: err)
    }

    func testNoArgumentsPrintsUsage() {
        let result = run([])
        XCTAssertEqual(result.code, MotionatorCommand.ExitCode.badArguments)
        XCTAssertTrue(result.err.contains("usage:"))
    }

    func testInfoListsBonesAndClips() {
        let result = run(["info", Fixtures.rigURL.path])
        XCTAssertEqual(result.code, 0, result.err)
        XCTAssertTrue(result.out.contains("thighNear"))
        XCTAssertTrue(result.out.contains("walk 1.0s loops"))
    }

    func testValidateIsOkForTheStickFigure() {
        let result = run(["validate", Fixtures.rigURL.path])
        XCTAssertEqual(result.code, 0, result.err)
        XCTAssertTrue(result.out.hasPrefix("ok:"))
    }

    func testSheetWritesAPng() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("No Metal device on this host") }
        let out = try Fixtures.temporaryFolder().appendingPathComponent("walk.png")
        let result = run(["sheet", Fixtures.rigURL.path, "walk", "--frames", "3", "--size", "48", "--out", out.path])
        XCTAssertEqual(result.code, 0, result.err)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
        XCTAssertTrue(result.out.contains("3 frames of walk, 144×"))
    }

    func testAMissingClipFails() {
        let result = run(["sheet", Fixtures.rigURL.path, "moonwalk"])
        XCTAssertEqual(result.code, MotionatorCommand.ExitCode.failed)
        XCTAssertTrue(result.err.contains("moonwalk"))
    }
}
