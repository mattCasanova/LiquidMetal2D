import XCTest
@testable import LiquidMetal2D

private enum Action: String, InputAction {
    case jump, attack, moveLeft, moveRight, debugWarp
}

private let defaults: [Action: [InputCode]] = [
    .jump: [.space, .w, .gamepadA],
    .attack: [.pointerPrimary, .j],
    .moveLeft: [.a, .arrowLeft],
    .moveRight: [.d, .arrowRight],
    .debugWarp: []
]

/// Actions bound to codes: lookups, the movement axis, remapping, saving
/// and the capture a controls screen uses.
@MainActor
final class InputBindingsTests: XCTestCase {

    private func makeInput() -> InputSystem {
        InputSystem(devices: [.pointer, .keyboard], unproject: { $0 })
    }

    private func frame(_ input: InputSystem, _ events: RawInputEvent...) {
        for event in events {
            input.enqueue(event)
        }
        input.beginFrame()
    }

    // MARK: - Lookups

    func testAnActionIsAnyOfItsCodes() {
        let input = makeInput()
        let bindings = InputBindings<Action>(defaults: defaults)
        frame(input, .down(.w))

        XCTAssertTrue(input.isTriggered(.jump, in: bindings))
        XCTAssertTrue(input.isPressed(.jump, in: bindings))
        XCTAssertFalse(input.isTriggered(.attack, in: bindings))

        frame(input, .up(.w))
        XCTAssertTrue(input.isReleased(.jump, in: bindings))
        XCTAssertFalse(input.isPressed(.jump, in: bindings))
    }

    func testAnEmptyBindingIsNeverDown() {
        let input = makeInput()
        let bindings = InputBindings<Action>(defaults: defaults)
        frame(input, .down(.space), .down(.pointerPrimary))

        XCTAssertFalse(input.isPressed(.debugWarp, in: bindings))
        XCTAssertFalse(input.isTriggered(.debugWarp, in: bindings), "and does not trap")
        XCTAssertFalse(input.isReleased(.debugWarp, in: bindings))
    }

    func testAGamepadCodeInABindingIsSkippedWithoutAGamepad() {
        let input = makeInput()
        let bindings = InputBindings<Action>(defaults: defaults)
        frame(input, .down(.space))

        XCTAssertTrue(input.isTriggered(.jump, in: bindings), "jump names gamepadA; the keyboard half works")
    }

    func testAxis() {
        let input = makeInput()
        let bindings = InputBindings<Action>(defaults: defaults)
        XCTAssertEqual(input.axis(negative: .moveLeft, positive: .moveRight, in: bindings), 0)

        frame(input, .down(.arrowRight))
        XCTAssertEqual(input.axis(negative: .moveLeft, positive: .moveRight, in: bindings), 1)

        frame(input, .down(.a))
        XCTAssertEqual(input.axis(negative: .moveLeft, positive: .moveRight, in: bindings), 0, "both held")

        frame(input, .up(.arrowRight))
        XCTAssertEqual(input.axis(negative: .moveLeft, positive: .moveRight, in: bindings), -1)
    }

    // MARK: - Remapping

    func testSetAddRemoveAndReset() {
        var bindings = InputBindings<Action>(defaults: defaults)

        bindings.set([.k], for: .jump)
        XCTAssertEqual(bindings.codes(for: .jump), [.k])

        bindings.add(.gamepadB, to: .jump)
        bindings.add(.k, to: .jump)
        XCTAssertEqual(bindings.codes(for: .jump), [.k, .gamepadB], "no duplicates")

        bindings.remove(.k, from: .jump)
        XCTAssertEqual(bindings.codes(for: .jump), [.gamepadB])

        bindings.set([], for: .attack)
        bindings.reset(.jump)
        XCTAssertEqual(bindings.codes(for: .jump), [.space, .w, .gamepadA])
        XCTAssertEqual(bindings.codes(for: .attack), [], "reset touches one action")

        bindings.resetAll()
        XCTAssertEqual(bindings, InputBindings<Action>(defaults: defaults))
    }

    func testActionsBoundToACodeShowConflicts() {
        var bindings = InputBindings<Action>(defaults: defaults)
        XCTAssertEqual(bindings.actions(boundTo: .space), [.jump])

        bindings.add(.space, to: .attack)
        XCTAssertEqual(bindings.actions(boundTo: .space), [.jump, .attack])
        XCTAssertEqual(bindings.actions(boundTo: .f12), [])
    }

    func testRemappedBindingsDriveTheLookups() {
        let input = makeInput()
        var bindings = InputBindings<Action>(defaults: defaults)
        bindings.set([.k], for: .jump)
        frame(input, .down(.space))

        XCTAssertFalse(input.isTriggered(.jump, in: bindings), "space no longer jumps")
        frame(input, .down(.k))
        XCTAssertTrue(input.isTriggered(.jump, in: bindings))
    }

    // MARK: - Saving

    func testSavedBindingsRoundTripThroughJSON() throws {
        var bindings = InputBindings<Action>(defaults: defaults)
        bindings.set([.k, .shift], for: .jump)

        let data = try JSONEncoder().encode(bindings.saved)
        var loaded = InputBindings<Action>(defaults: defaults)
        loaded.restore(try JSONDecoder().decode([String: [InputCode]].self, from: data))

        XCTAssertEqual(loaded, bindings)
    }

    /// Pins the file shape: an object of action name to code names.
    func testFilesInTodaysShapeKeepLoading() throws {
        let json = #"{"jump":["k","gamepadB"],"moveLeft":["q"]}"#
        var bindings = InputBindings<Action>(defaults: defaults)

        bindings.restore(try JSONDecoder().decode([String: [InputCode]].self, from: Data(json.utf8)))

        XCTAssertEqual(bindings.codes(for: .jump), [.k, .gamepadB])
        XCTAssertEqual(bindings.codes(for: .moveLeft), [.q])
        XCTAssertEqual(bindings.codes(for: .attack), [.pointerPrimary, .j], "absent from the file: keeps its list")
    }

    func testRestoreSkipsAnActionTheGameNoLongerHas() {
        var bindings = InputBindings<Action>(defaults: defaults)

        bindings.restore(["jump": [.k], "grapple": [.g]])

        XCTAssertEqual(bindings.codes(for: .jump), [.k])
        XCTAssertEqual(bindings, {
            var expected = InputBindings<Action>(defaults: defaults)
            expected.set([.k], for: .jump)
            return expected
        }())
    }

    // MARK: - Capture

    func testFirstTriggeredCodeForAControlsScreen() {
        let input = makeInput()
        XCTAssertNil(input.firstTriggeredCode())

        frame(input, .down(.k))
        XCTAssertEqual(input.firstTriggeredCode(), .k)

        frame(input)
        XCTAssertNil(input.firstTriggeredCode(), "held, not triggered")

        frame(input, .down(.pointerSecondary))
        XCTAssertEqual(input.firstTriggeredCode(), .pointerSecondary)
    }

    func testCapturingAModifierBindsEitherSide() {
        let input = makeInput()
        frame(input, .down(.rightShift))

        XCTAssertEqual(input.firstTriggeredCode(), .shift)
    }

    func testCaptureSkipsDisabledDevices() {
        let input = InputSystem(devices: [.keyboard], unproject: { $0 })
        frame(input, .down(.tab))

        XCTAssertEqual(input.firstTriggeredCode(), .tab, "the pointer is off and is not asked about")
    }
}
