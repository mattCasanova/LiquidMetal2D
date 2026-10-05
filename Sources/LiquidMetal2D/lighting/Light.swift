//
//  Light.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/5/26.
//

/// One light for a ``LightMap``: a pool of colour around `position`,
/// fading to nothing at `radius`. A `halfAngle` under π makes it a cone
/// looking along `direction`. Pass a ``VisibilityPolygon``'s points when
/// adding it and walls cast shadows.
public struct Light: Equatable, Sendable {
    public var position: Vec2
    /// The world plane the light sits on, so it lines up with sprites there.
    public var z: Float = 0
    public var radius: Float
    public var color: Vec3
    public var intensity: Float = 1
    /// Exponent on `1 − d / radius`: 1 is linear, 2 a softer, rounder pool.
    public var falloff: Float = 2
    /// Radians; the centre of a cone. Ignored when `halfAngle` is π.
    public var direction: Float = 0
    /// Radians; π (the default) is all round.
    public var halfAngle: Float = .pi
    /// Radians of fade at each cone edge.
    public var edgeSoftness: Float = 0.12

    public init(position: Vec2, radius: Float, color: Vec3) {
        self.position = position
        self.radius = radius
        self.color = color
    }

    /// A cone rather than a pool.
    public var isCone: Bool { halfAngle < .pi }
}
