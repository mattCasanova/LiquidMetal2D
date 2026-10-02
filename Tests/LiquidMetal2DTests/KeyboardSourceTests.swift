import XCTest
import GameController
@testable import LiquidMetal2D

/// The key map: every keyboard code the engine lists is reachable from one
/// `GCKeyCode`, and no two key codes land on the same input code.
final class KeyboardSourceTests: XCTestCase {

    func testEveryKeyboardCodeHasExactlyOneKey() {
        let mapped = KeyboardSource.map.values
        for code in InputCode.allCases where code.device == .keyboard && !code.isEitherSideModifier {
            XCTAssertEqual(mapped.filter { $0 == code }.count, 1, "\(code) must map from exactly one GCKeyCode")
        }
    }

    func testNoKeyMapsToAnotherDevice() {
        for code in KeyboardSource.map.values {
            XCTAssertEqual(code.device, .keyboard, "\(code) is not a key")
            XCTAssertFalse(code.isEitherSideModifier, "\(code) is derived, never sent")
        }
    }

    func testAFewKnownKeys() {
        XCTAssertEqual(KeyboardSource.map[GCKeyCode.spacebar.rawValue], .space)
        XCTAssertEqual(KeyboardSource.map[GCKeyCode.returnOrEnter.rawValue], .returnKey)
        XCTAssertEqual(KeyboardSource.map[GCKeyCode.leftGUI.rawValue], .leftCommand)
        XCTAssertEqual(KeyboardSource.map[GCKeyCode.F12.rawValue], .f12)
        XCTAssertNil(KeyboardSource.map[GCKeyCode.capsLock.rawValue], "unlisted keys are dropped")
    }
}
