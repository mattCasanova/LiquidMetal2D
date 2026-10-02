//
//  InputReader.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 3/6/20.
//

/// What a scene polls. The vocabulary is Mach 5's:
///
/// | Query | True when |
/// |---|---|
/// | `isPressed` | down at the end of this frame |
/// | `isTriggered` | went down during this frame |
/// | `isReleased` | went up during this frame |
/// | `isRepeating` | down this frame and last |
///
/// A tap that goes down and up inside one frame is both triggered and
/// released, and not pressed. Asking about a device the engine was not
/// created with is a programmer error and traps.
///
/// For sets of codes see the extension: `isPressed(anyOf:)`,
/// `isPressed(allOf:)`, `isTriggered(anyOf:)`, `isReleased(anyOf:)` and
/// `isComboTriggered(_:)`. `.shift`, `.control`, `.option` and `.command`
/// are down while either side is. In the set queries a code of a device
/// that is off counts as never down, so one binding list can name keys and
/// gamepad buttons whatever devices a build turns on.
@MainActor
public protocol InputReader: AnyObject {
    /// The devices the engine was created with.
    var devices: InputDevices { get }

    func isPressed(_ code: InputCode) -> Bool
    func isTriggered(_ code: InputCode) -> Bool
    func isReleased(_ code: InputCode) -> Bool
    func isRepeating(_ code: InputCode) -> Bool
    /// Any code went down this frame: "press any key".
    var isAnyTriggered: Bool { get }

    /// The pointer's location and scroll for this frame.
    var pointer: PointerState { get }
    /// The pointer's location unprojected onto the plane at world `z`, hovering or not.
    func pointerWorld(forZ z: Float) -> Vec3?

    /// The pointer's location while its primary button (or the finger) is down.
    func getScreenTouch() -> Vec2?
    /// ``getScreenTouch()`` unprojected onto the plane at world `z`.
    func getWorldTouch(forZ z: Float) -> Vec3?
}
