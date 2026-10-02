//
//  PointerState.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// Where the pointer is this frame. Buttons are ``InputCode``s
/// (`pointerPrimary` and friends) and go through the pressed/triggered queries.
public struct PointerState: Equatable, Sendable {
    /// Screen location, top-left origin; `nil` when there is no pointer
    /// (no finger down, or the mouse is outside the view).
    public let location: Vec2?
    /// The scroll steps summed over this frame.
    public let scrollDelta: Vec2
    /// Every finger on the screen, oldest first. Empty on the Mac, where
    /// the mouse is the pointer and sends no touches.
    public let touches: [TouchPoint]

    public init(location: Vec2?, scrollDelta: Vec2, touches: [TouchPoint]) {
        self.location = location
        self.scrollDelta = scrollDelta
        self.touches = touches
    }
}
