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
}
