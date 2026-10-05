//
//  LightUniform.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/5/26.
//

/// One light as the light shader reads it. Mirrors the MSL `LightUniform`
/// field by field; `UniformLayoutTests` pins the stride and offsets.
public struct LightUniform: UniformData {
    /// rgb × intensity; a unused.
    public var color: Vec4
    public var center: Vec2
    public var radius: Float
    public var falloff: Float
    /// Unit vector; only read for a cone.
    public var direction: Vec2
    /// −1 for an all-round light, which the shader treats as "no cone".
    public var cosHalfAngle: Float
    /// cos(halfAngle − edgeSoftness): where the cone's edge fade ends.
    public var cosInner: Float

    public init(
        color: Vec4, center: Vec2, radius: Float, falloff: Float,
        direction: Vec2, cosHalfAngle: Float, cosInner: Float
    ) {
        self.color = color
        self.center = center
        self.radius = radius
        self.falloff = falloff
        self.direction = direction
        self.cosHalfAngle = cosHalfAngle
        self.cosInner = cosInner
    }
}

/// One corner of a light's fan of triangles. Mirrors the MSL `LightVertex`.
public struct LightVertex: UniformData {
    public var position: Vec2
    public var z: Float
    /// Index into the frame's ``LightUniform`` array.
    public var light: UInt32

    public init(position: Vec2, z: Float, light: UInt32) {
        self.position = position
        self.z = z
        self.light = light
    }
}
