import XCTest
@testable import LiquidMetal2D

/// Input codes save by name, so adding a code never remaps a saved binding.
final class InputCodeCodableTests: XCTestCase {

    func testEveryCodeRoundTrips() throws {
        let data = try JSONEncoder().encode(InputCode.allCases)
        let decoded = try JSONDecoder().decode([InputCode].self, from: data)

        XCTAssertEqual(decoded, InputCode.allCases)
    }

    func testCodesAreWrittenAsTheirCaseNames() throws {
        let data = try JSONEncoder().encode([InputCode.space, .gamepadA, .shift, .pointerPrimary])

        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"["space","gamepadA","shift","pointerPrimary"]"#)
    }

    /// Pins the saved names. Renaming a case breaks every file that names it;
    /// that needs a decode path for the old name, not just a new case name.
    func testFilesInTodaysShapeKeepLoading() throws {
        let json = #"{"jump":["space","w","gamepadA"],"attack":["pointerPrimary","leftCommand","f12"]}"#

        let bindings = try JSONDecoder().decode([String: [InputCode]].self, from: Data(json.utf8))

        XCTAssertEqual(bindings["jump"], [.space, .w, .gamepadA])
        XCTAssertEqual(bindings["attack"], [.pointerPrimary, .leftCommand, .f12])
    }

    func testEveryNameIsUniqueAndLooksUp() {
        let names = InputCode.allCases.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
        for code in InputCode.allCases {
            XCTAssertEqual(InputCode(name: code.name), code)
        }
        XCTAssertEqual(InputCode.returnKey.name, "returnKey")
        XCTAssertNil(InputCode(name: "jetpack"))
    }

    func testAnUnknownNameIsADecodingError() {
        let json = #"["space","jetpack"]"#

        XCTAssertThrowsError(try JSONDecoder().decode([InputCode].self, from: Data(json.utf8))) { error in
            guard case DecodingError.dataCorrupted(let context) = error else {
                return XCTFail("expected dataCorrupted, got \(error)")
            }
            XCTAssertTrue(context.debugDescription.contains("jetpack"))
        }
    }
}
