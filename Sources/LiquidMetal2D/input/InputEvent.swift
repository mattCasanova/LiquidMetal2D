//
//  InputEvent.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// What one frame's drain of the raw queue produced, in order. The engine
/// hands the list to the current scene, which forwards it to its observers.
///
/// A modifier key sends two events: the physical side, then the derived
/// either-side code (`.triggered(.leftShift)`, `.triggered(.shift)`). The
/// derived one comes with the first side down and goes with the last side up.
/// A tool that turns frame events back into ``RawInputEvent``s must skip codes
/// where `isEitherSideModifier` is true: the input system derives them and
/// traps if one is enqueued.
public enum InputEvent: Hashable, Sendable {
    case triggered(InputCode)
    case released(InputCode)
    case gamepadConnected
    case gamepadDisconnected
}
