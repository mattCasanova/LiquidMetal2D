//
//  InputWriter.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 3/6/20.
//

/// What the platform layer calls. Events queue up and take effect at the
/// top of the next frame.
@MainActor
public protocol InputWriter {
    func enqueue(_ event: RawInputEvent)

    /// The one-touch API: a location presses the primary pointer button
    /// there; `nil` releases it and removes the pointer.
    func setTouch(location: Vec2?)
}
