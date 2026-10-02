//
//  RawInputEvent.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// What the platform layer feeds the input system, any time an OS callback
/// fires. Nothing changes state until the next ``InputSystem/beginFrame()``
/// drains the queue, so polling and observers always agree.
public enum RawInputEvent: Equatable, Sendable {
    /// A button or key went down. A second `down` for a code already down
    /// is OS key repeat and is ignored.
    case down(InputCode)
    /// A button or key went up.
    case up(InputCode)
    /// The pointer moved, in screen space with a top-left origin. `nil`
    /// means there is no pointer: the finger lifted, or the mouse left the view.
    case pointerMoved(Vec2?)
    /// A scroll step; the frame sums them into ``PointerState/scrollDelta``.
    case scroll(Vec2)
    /// A finger went down, with the platform's id for it. The first finger
    /// down is also the pointer: it sets the location and presses
    /// `pointerPrimary`. Ids are unique while the finger is down.
    case touchBegan(id: Int, Vec2)
    case touchMoved(id: Int, Vec2)
    case touchEnded(id: Int)
    /// The app or window lost focus: every held code is released so nothing
    /// sticks down, and the pointer goes away.
    case focusLost
}
