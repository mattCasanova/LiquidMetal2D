//
//  TouchPoint.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// One finger on the screen. The id is the platform's for that touch and
/// stays the same from began to ended, so a game can follow a finger across
/// frames.
public struct TouchPoint: Equatable, Sendable {
    public let id: Int
    /// Screen location, top-left origin.
    public let location: Vec2

    public init(id: Int, location: Vec2) {
        self.id = id
        self.location = location
    }
}
