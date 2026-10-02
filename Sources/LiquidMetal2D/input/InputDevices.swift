//
//  InputDevices.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// The input devices an app turns on when it creates its engine:
///
/// ```swift
/// DefaultEngine(renderer: …, documents: …, inputDevices: [.pointer, .keyboard], …)
/// ```
///
/// The default is `[.pointer]`, which is exactly the one-touch behaviour the
/// engine always had. Asking the input system about a device that is not on
/// is a programmer error and traps.
public struct InputDevices: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Touch on iOS; the mouse (hover, buttons, scroll) on the Mac.
    public static let pointer = InputDevices(rawValue: 1 << 0)
    /// Physical keys through `GCKeyboard`, on both platforms.
    public static let keyboard = InputDevices(rawValue: 1 << 1)
    /// An extended gamepad through `GCController`.
    public static let gamepad = InputDevices(rawValue: 1 << 2)

    /// A name for messages.
    var name: String {
        switch self {
        case .pointer: return "pointer"
        case .keyboard: return "keyboard"
        case .gamepad: return "gamepad"
        default: return "devices(\(rawValue))"
        }
    }
}
