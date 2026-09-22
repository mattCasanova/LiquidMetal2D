//
//  AnimationEvent.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

/// A named moment in a clip: a footstep, a landing, the frame a sword leaves the hand.
///
/// The ``Animator`` reports each one through ``Animator/onEvent`` as play passes it,
/// so game code reacts on the exact frame instead of guessing a time.
public struct AnimationEvent: Codable, Equatable, Sendable {
    /// Seconds from the start of the clip, within `0...duration`.
    public var time: Float
    public var name: String

    public init(time: Float, name: String) {
        self.time = time
        self.name = name
    }
}
