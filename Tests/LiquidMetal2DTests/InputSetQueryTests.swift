import XCTest
@testable import LiquidMetal2D

/// Either-side modifiers and the any / all / combo queries.
@MainActor
final class InputSetQueryTests: XCTestCase {

    private func makeInput() -> InputSystem {
        InputSystem(devices: [.pointer, .keyboard], unproject: { $0 })
    }

    private func frame(_ input: InputSystem, _ events: RawInputEvent...) {
        for event in events {
            input.enqueue(event)
        }
        input.beginFrame()
    }

    // MARK: - Either-side modifiers

    func testEitherSideShiftFollowsBothSides() {
        let input = makeInput()
        input.enqueue(.down(.leftShift))
        XCTAssertEqual(input.beginFrame(), [.triggered(.leftShift), .triggered(.shift)])
        XCTAssertTrue(input.isTriggered(.shift))

        frame(input, .down(.rightShift))
        XCTAssertFalse(input.isTriggered(.shift), "already down from the left side")
        XCTAssertTrue(input.isRepeating(.shift))

        input.enqueue(.up(.leftShift))
        XCTAssertEqual(input.beginFrame(), [.released(.leftShift)])
        XCTAssertTrue(input.isPressed(.shift), "the right side still holds it")

        input.enqueue(.up(.rightShift))
        XCTAssertEqual(input.beginFrame(), [.released(.rightShift), .released(.shift)])
        XCTAssertFalse(input.isPressed(.shift))
        XCTAssertTrue(input.isReleased(.shift))
    }

    func testEveryModifierHasItsEitherSideCode() {
        let pairs: [(InputCode, InputCode, InputCode)] = [
            (.leftShift, .rightShift, .shift), (.leftControl, .rightControl, .control),
            (.leftOption, .rightOption, .option), (.leftCommand, .rightCommand, .command)
        ]
        for (left, right, either) in pairs {
            XCTAssertEqual(left.eitherSideModifier, either)
            XCTAssertEqual(right.eitherSideModifier, either)
            XCTAssertEqual(either.modifierSides?.left, left)
            XCTAssertEqual(either.modifierSides?.right, right)
            XCTAssertTrue(either.isEitherSideModifier)
            XCTAssertEqual(either.device, .keyboard)
        }
        XCTAssertNil(InputCode.a.eitherSideModifier)
        XCTAssertFalse(InputCode.leftShift.isEitherSideModifier)
    }

    // MARK: - Any and all

    func testPressedAnyAndAll() {
        let input = makeInput()
        frame(input, .down(.w))

        XCTAssertTrue(input.isPressed(anyOf: [.w, .d]))
        XCTAssertFalse(input.isPressed(allOf: [.w, .d]))

        frame(input, .down(.d))
        XCTAssertTrue(input.isPressed(allOf: [.w, .d]))
        XCTAssertFalse(input.isPressed(anyOf: [.a, .s]))
    }

    func testTriggeredAndReleasedAny() {
        let input = makeInput()
        let confirm: [InputCode] = [.space, .returnKey, .pointerPrimary]
        frame(input, .down(.returnKey))

        XCTAssertTrue(input.isTriggered(anyOf: confirm))
        frame(input)
        XCTAssertFalse(input.isTriggered(anyOf: confirm), "held, not triggered")

        frame(input, .up(.returnKey))
        XCTAssertTrue(input.isReleased(anyOf: confirm))
        XCTAssertFalse(input.isReleased(anyOf: [.space]))
    }

    // MARK: - Combos

    func testComboFiresWhenTheKeyCompletesItAfterTheModifier() {
        let input = makeInput()
        frame(input, .down(.leftCommand))
        XCTAssertFalse(input.isComboTriggered([.command, .b]), "B is not down yet")

        frame(input)
        frame(input, .down(.b))
        XCTAssertTrue(input.isComboTriggered([.command, .b]))

        frame(input)
        XCTAssertFalse(input.isComboTriggered([.command, .b]), "fires once, on the completing frame")
    }

    func testComboFiresWhenTheModifierCompletesItAfterTheKey() {
        let input = makeInput()
        frame(input, .down(.a))
        frame(input, .down(.rightShift))

        XCTAssertTrue(input.isComboTriggered([.shift, .a]), "the combo is complete either way round")
    }

    func testComboFiresWhenBothGoDownInOneFrame() {
        let input = makeInput()
        frame(input, .down(.leftShift), .down(.a))

        XCTAssertTrue(input.isComboTriggered([.shift, .a]))
    }

    func testComboCountsATapInsideTheFrame() {
        let input = makeInput()
        frame(input, .down(.leftCommand))
        frame(input, .down(.b), .up(.b))

        XCTAssertFalse(input.isPressed(.b))
        XCTAssertTrue(input.isComboTriggered([.command, .b]), "a fast press is not lost")
    }

    func testComboNeedsEveryCode() {
        let input = makeInput()
        frame(input, .down(.b))

        XCTAssertFalse(input.isComboTriggered([.command, .b]))
        XCTAssertFalse(input.isComboTriggered([.shift, .command, .b]))
    }

    func testComboDoesNotFireOnTheModifierAlone() {
        let input = makeInput()
        frame(input, .down(.b))
        frame(input)
        frame(input, .up(.b))
        frame(input, .down(.leftCommand))

        XCTAssertFalse(input.isComboTriggered([.command, .b]), "B is up again")
    }

    // MARK: - Combos: exact modifiers

    func testAnExtraModifierBlocksTheShorterCombo() {
        let input = makeInput()
        frame(input, .down(.leftCommand))
        frame(input, .down(.leftShift))
        frame(input, .down(.z))

        XCTAssertFalse(input.isComboTriggered([.command, .z]), "undo stays quiet inside redo")
        XCTAssertTrue(input.isComboTriggered([.command, .shift, .z]))
    }

    func testOtherHeldKeysAndButtonsDoNotBlockACombo() {
        let input = makeInput()
        frame(input, .down(.w), .down(.pointerPrimary))
        frame(input, .down(.leftCommand))
        frame(input, .down(.z))

        XCTAssertTrue(input.isComboTriggered([.command, .z]), "only modifiers must match")
    }

    func testNamingOneSideNamesTheModifier() {
        let input = makeInput()
        frame(input, .down(.leftShift))
        frame(input, .down(.a))

        XCTAssertTrue(input.isComboTriggered([.leftShift, .a]), "the held .shift is named through its side")
    }

    func testAComboSkipsTheModifierCheckWithTheKeyboardOff() {
        let input = InputSystem(devices: [.pointer], unproject: { $0 })
        frame(input, .down(.pointerPrimary))
        frame(input, .down(.pointerSecondary))

        XCTAssertTrue(input.isComboTriggered([.pointerPrimary, .pointerSecondary]),
                      "no keyboard: asking about Shift would trap")
    }

    func testAHeldModifierBlocksAMouseComboWithTheKeyboardOn() {
        let input = makeInput()
        frame(input, .down(.leftShift))
        frame(input, .down(.pointerPrimary))
        frame(input, .down(.pointerSecondary))

        XCTAssertFalse(input.isComboTriggered([.pointerPrimary, .pointerSecondary]), "Shift is not named")
        XCTAssertTrue(input.isComboTriggered([.shift, .pointerPrimary, .pointerSecondary]))
    }

    // MARK: - Disabled devices

    func testSetQueriesTreatADisabledDeviceAsNeverDown() {
        let input = InputSystem(devices: [.keyboard], unproject: { $0 })
        let jump: [InputCode] = [.space, .gamepadA, .pointerPrimary]
        input.enqueue(.down(.space))
        input.beginFrame()

        XCTAssertTrue(input.isTriggered(anyOf: jump), "the keyboard half of the binding still works")
        XCTAssertTrue(input.isPressed(anyOf: jump))
        XCTAssertFalse(input.isPressed(allOf: jump), "a gamepad button that cannot be down")
        XCTAssertFalse(input.isComboTriggered([.space, .gamepadA]))
        XCTAssertFalse(input.isTriggered(anyOf: [.gamepadA]), "a list of only disabled codes is never down")

        input.enqueue(.up(.space))
        input.beginFrame()
        XCTAssertTrue(input.isReleased(anyOf: jump))
    }

    func testSetQueriesTakeAnyCollection() {
        let input = makeInput()
        frame(input, .down(.space))

        XCTAssertTrue(input.isTriggered(anyOf: Set([InputCode.space, .escape])))
        XCTAssertTrue(input.isPressed(anyOf: CollectionOfOne(InputCode.space)))
        // An empty set traps (requireCodes); documented, not tested.
    }
}
