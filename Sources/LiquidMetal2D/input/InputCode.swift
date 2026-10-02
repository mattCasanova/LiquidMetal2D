//
//  InputCode.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// Every button-like input the engine knows, in one enum: pointer buttons,
/// keyboard keys and gamepad buttons. A game binds its actions to lists of
/// these; the engine never maps actions itself.
///
/// Keys are physical, named by their US-layout position (`GCKeyboard` reports
/// key codes, not characters). The raw value is the index into the input
/// system's state tables, so the enum must stay `Int`-backed and contiguous.
public enum InputCode: Int, Hashable, CaseIterable, Sendable {
    // Pointer buttons
    case pointerPrimary, pointerSecondary, pointerMiddle

    // Keyboard: letters
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    // Keyboard: digits (the top row)
    case digit0, digit1, digit2, digit3, digit4, digit5, digit6, digit7, digit8, digit9
    // Keyboard: whitespace and editing
    case space, returnKey, escape, tab, backspace
    // Keyboard: arrows
    case arrowUp, arrowDown, arrowLeft, arrowRight
    // Keyboard: modifiers
    case leftShift, rightShift, leftControl, rightControl
    case leftOption, rightOption, leftCommand, rightCommand
    // Keyboard: either-side modifiers. Down while either physical side is
    // down; the input system derives them, no source sends them.
    case shift, control, option, command
    // Keyboard: function row
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    // Gamepad (fed from Phase 6 of the input plan)
    case gamepadA, gamepadB, gamepadX, gamepadY
    case gamepadLeftShoulder, gamepadRightShoulder, gamepadLeftTrigger, gamepadRightTrigger
    case gamepadLeftStickPress, gamepadRightStickPress
    case gamepadDpadUp, gamepadDpadDown, gamepadDpadLeft, gamepadDpadRight
    case gamepadMenu, gamepadOptions

    /// The device this code comes from. Decides which enabled-device set
    /// accepts the code and which observers hear it.
    public var device: InputDevices {
        switch self {
        case .pointerPrimary, .pointerSecondary, .pointerMiddle:
            return .pointer
        case .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m,
             .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z,
             .digit0, .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9,
             .space, .returnKey, .escape, .tab, .backspace,
             .arrowUp, .arrowDown, .arrowLeft, .arrowRight,
             .leftShift, .rightShift, .leftControl, .rightControl,
             .leftOption, .rightOption, .leftCommand, .rightCommand,
             .shift, .control, .option, .command,
             .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12:
            return .keyboard
        case .gamepadA, .gamepadB, .gamepadX, .gamepadY,
             .gamepadLeftShoulder, .gamepadRightShoulder, .gamepadLeftTrigger, .gamepadRightTrigger,
             .gamepadLeftStickPress, .gamepadRightStickPress,
             .gamepadDpadUp, .gamepadDpadDown, .gamepadDpadLeft, .gamepadDpadRight,
             .gamepadMenu, .gamepadOptions:
            return .gamepad
        }
    }

    /// For a left or right modifier key, the either-side code it drives.
    /// `nil` for every other code: most keys have no such group.
    public var eitherSideModifier: InputCode? {
        switch self {
        case .leftShift, .rightShift: return .shift
        case .leftControl, .rightControl: return .control
        case .leftOption, .rightOption: return .option
        case .leftCommand, .rightCommand: return .command
        default: return nil
        }
    }

    /// For an either-side modifier, its two physical keys; `nil` for every other code.
    public var modifierSides: (left: InputCode, right: InputCode)? {
        switch self {
        case .shift: return (.leftShift, .rightShift)
        case .control: return (.leftControl, .rightControl)
        case .option: return (.leftOption, .rightOption)
        case .command: return (.leftCommand, .rightCommand)
        default: return nil
        }
    }

    /// Whether this is one of the derived either-side modifiers.
    public var isEitherSideModifier: Bool { modifierSides != nil }
}
