//
//  InputReader+Actions.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// Queries by action through ``InputBindings``, and the capture a controls
/// screen needs. An action with an empty list is never down. Like the set
/// queries, these allocate nothing.
public extension InputReader {
    /// Any code bound to the action is down.
    @inlinable
    func isPressed<A: InputAction>(_ action: A, in bindings: InputBindings<A>) -> Bool {
        let codes = bindings.codes(for: action)
        return !codes.isEmpty && isPressed(anyOf: codes)
    }

    /// Any code bound to the action went down this frame.
    @inlinable
    func isTriggered<A: InputAction>(_ action: A, in bindings: InputBindings<A>) -> Bool {
        let codes = bindings.codes(for: action)
        return !codes.isEmpty && isTriggered(anyOf: codes)
    }

    /// Any code bound to the action went up this frame.
    @inlinable
    func isReleased<A: InputAction>(_ action: A, in bindings: InputBindings<A>) -> Bool {
        let codes = bindings.codes(for: action)
        return !codes.isEmpty && isReleased(anyOf: codes)
    }

    /// -1, 0 or 1 from two actions: positive held minus negative held, so
    /// holding both is 0. A gamepad stick will feed the same number once the
    /// gamepad device exists.
    @inlinable
    func axis<A: InputAction>(negative: A, positive: A, in bindings: InputBindings<A>) -> Float {
        (isPressed(positive, in: bindings) ? 1 : 0) - (isPressed(negative, in: bindings) ? 1 : 0)
    }

    /// The code that went down this frame, for "press a key to bind". A
    /// modifier comes back as its either-side code (`.shift`, not
    /// `.leftShift`), so the binding works with both sides. Codes of devices
    /// that are off are skipped. When several went down in one frame, the
    /// first in ``InputCode`` order wins. `nil` when nothing went down.
    @inlinable
    func firstTriggeredCode() -> InputCode? {
        guard isAnyTriggered else { return nil }
        let enabled = devices
        var raw = 0
        while let code = InputCode(rawValue: raw) {
            raw += 1
            if code.isEitherSideModifier || !enabled.contains(code.device) {
                continue
            }
            if isTriggered(code) {
                return code.eitherSideModifier ?? code
            }
        }
        return nil
    }
}
