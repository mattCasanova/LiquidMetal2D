//
//  InputReader+Sets.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// Queries over a set of codes: bindings ("space or return") and combos
/// ("command and B"). Plain loops, no closures, so per-frame calls pay no
/// actor check; keep a binding in a stored array and a call allocates nothing.
///
/// A code of a device the engine was created without counts as never down
/// here, instead of trapping as a single-code query does: a binding list
/// naming a gamepad button in a keyboard-only build is normal, not a bug.
///
/// An empty set is a programmer error and traps: "all of nothing" is
/// vacuously true and "any of nothing" never is, and either answer would
/// hide a missing binding.
public extension InputReader {
    /// Any of the codes is down.
    @inlinable
    func isPressed(anyOf codes: some Collection<InputCode>) -> Bool {
        requireCodes(codes)
        let enabled = devices
        for code in codes where enabled.contains(code.device) && isPressed(code) {
            return true
        }
        return false
    }

    /// Every one of the codes is down.
    @inlinable
    func isPressed(allOf codes: some Collection<InputCode>) -> Bool {
        requireCodes(codes)
        let enabled = devices
        for code in codes where !enabled.contains(code.device) || !isPressed(code) {
            return false
        }
        return true
    }

    /// Any of the codes went down this frame.
    @inlinable
    func isTriggered(anyOf codes: some Collection<InputCode>) -> Bool {
        requireCodes(codes)
        let enabled = devices
        for code in codes where enabled.contains(code.device) && isTriggered(code) {
            return true
        }
        return false
    }

    /// Any of the codes went up this frame.
    @inlinable
    func isReleased(anyOf codes: some Collection<InputCode>) -> Bool {
        requireCodes(codes)
        let enabled = devices
        for code in codes where enabled.contains(code.device) && isReleased(code) {
            return true
        }
        return false
    }

    /// The combo became complete this frame: every code is held and at least
    /// one of them went down this frame. Holding Command and then pressing B
    /// fires once, on B's frame. A code tapped down and up inside this frame
    /// counts as held, so a very fast press is not lost.
    ///
    /// Modifiers must match exactly, as in system shortcuts: a modifier the
    /// combo does not name must be up, so Command-Z does not fire inside
    /// Command-Shift-Z, and a left-plus-right click does not fire while Shift
    /// is held (that is `[.shift, .pointerPrimary, .pointerSecondary]`).
    /// Naming one side (`.leftShift`) names that modifier. Other held keys and
    /// buttons don't matter. With the keyboard off there are no modifiers to
    /// check; with it on, a held modifier also blocks a gamepad-only combo.
    ///
    /// ```swift
    /// input.isComboTriggered([.command, .z])          // undo
    /// input.isComboTriggered([.command, .shift, .z])  // redo; undo stays quiet
    /// ```
    @inlinable
    func isComboTriggered(_ codes: some Collection<InputCode>) -> Bool {
        requireCodes(codes)
        let enabled = devices
        var anyTriggered = false
        for code in codes {
            // A combo needing a device that is off can never complete.
            guard enabled.contains(code.device) else {
                return false
            }
            let triggered = isTriggered(code)
            if !triggered && !isPressed(code) {
                return false
            }
            anyTriggered = anyTriggered || triggered
        }
        guard anyTriggered else { return false }
        // With the keyboard off there are no modifiers, and asking about one traps.
        return !enabled.contains(.keyboard)
            || (modifierAllowed(.shift, by: codes) && modifierAllowed(.control, by: codes)
                && modifierAllowed(.option, by: codes) && modifierAllowed(.command, by: codes))
    }

    /// The combo names this modifier (or one of its sides), or it is up.
    @inlinable
    internal func modifierAllowed(_ modifier: InputCode, by codes: some Collection<InputCode>) -> Bool {
        for code in codes where code == modifier || code.eitherSideModifier == modifier {
            return true
        }
        return !isPressed(modifier)
    }

    @inlinable
    internal func requireCodes(_ codes: some Collection<InputCode>) {
        if codes.isEmpty {
            preconditionFailure("InputReader: a set query needs at least one code")
        }
    }
}
