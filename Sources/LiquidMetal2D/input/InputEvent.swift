//
//  InputEvent.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// What one frame's drain of the raw queue produced, in order. The engine
/// hands the list to the current scene, which forwards it to its observers.
public enum InputEvent: Hashable, Sendable {
    case triggered(InputCode)
    case released(InputCode)
    case gamepadConnected
    case gamepadDisconnected
}
