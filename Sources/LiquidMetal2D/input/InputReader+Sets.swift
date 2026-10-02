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
/// An empty set is a programmer error and traps: "all of nothing" is
/// vacuously true and "any of nothing" never is, and either answer would
/// hide a missing binding.
public extension InputReader {
    /// Any of the codes is down.
    @inlinable
    func isPressed(anyOf codes: some Collection<InputCode>) -> Bool {
        requireCodes(codes)
        for code in codes where isPressed(code) {
            return true
        }
        return false
    }

    /// Every one of the codes is down.
    @inlinable
    func isPressed(allOf codes: some Collection<InputCode>) -> Bool {
        requireCodes(codes)
        for code in codes where !isPressed(code) {
            return false
        }
        return true
    }

    /// Any of the codes went down this frame.
    @inlinable
    func isTriggered(anyOf codes: some Collection<InputCode>) -> Bool {
        requireCodes(codes)
        for code in codes where isTriggered(code) {
            return true
        }
        return false
    }

    /// Any of the codes went up this frame.
    @inlinable
    func isReleased(anyOf codes: some Collection<InputCode>) -> Bool {
        requireCodes(codes)
        for code in codes where isReleased(code) {
            return true
        }
        return false
    }

    /// The combo became complete this frame: every code is held and at least
    /// one of them went down this frame. Holding Command and then pressing B
    /// fires once, on B's frame. A code tapped down and up inside this frame
    /// counts as held, so a very fast press is not lost.
    ///
    /// ```swift
    /// input.isComboTriggered([.command, .b])
    /// input.isComboTriggered([.shift, .a])   // either Shift
    /// ```
    @inlinable
    func isComboTriggered(_ codes: some Collection<InputCode>) -> Bool {
        requireCodes(codes)
        var anyTriggered = false
        for code in codes {
            let triggered = isTriggered(code)
            if !triggered && !isPressed(code) {
                return false
            }
            anyTriggered = anyTriggered || triggered
        }
        return anyTriggered
    }

    @inlinable
    internal func requireCodes(_ codes: some Collection<InputCode>) {
        if codes.isEmpty {
            preconditionFailure("InputReader: a set query needs at least one code")
        }
    }
}
