//
//  Vec2+.swift
//
//
//  Created by Matt Casanova on 4/7/20.
//

/// Extension for Vec2 that adds convenience methods for setting or converting between types
public extension Vec2 {

    /// The angle between this vector and the x axis
    var angle: Float { atan2(y, x) }

    /// The length (magnitude) of this vector
    var length: Float { simd_length(self) }

    /// The squared length of this vector (avoids a sqrt — use for comparisons)
    var lengthSquared: Float { simd_length_squared(self) }

    /// Returns a unit vector in the same direction, or zero if length is zero
    var normalized: Vec2 { simd_normalize(self) }

    /// Convenience access for getting the u component when treating this like a texture coordinate
    var u: Float {
        get { x }
        set { x = newValue }
    }

    /// Convenience access for getting the v component when treating this like a texture coordinate
    var v: Float {
        get { y }
        set { y = newValue }
    }

    /// Construct a vector from an angle
    init(angle: Float) {
        self.init(cos(angle), sin(angle))
    }

    /// Construct a 2D point/vector from a 3D point/vector. The z component will be lost.
    init(simd3: Vec3) {
        self.init(simd3.x, simd3.y)
    }

    /// Convenience setter for setting x and y components from floats in one line.
    mutating func set(_ x: Float = 0, _ y: Float = 0) {
        self.x = x
        self.y = y
    }

    /// Sets the x and y components from texture coordinates u and v.
    mutating func set(u: Float, v: Float) {
        self.x = u
        self.y = v
    }

    /// Sets this vector to a unit vector at the given angle (radians).
    mutating func set(angle: Float) {
        self.x = cos(angle)
        self.y = sin(angle)
    }

    /// Sets both components to the same value.
    mutating func set(repeating: Float) {
        self.x = repeating
        self.y = repeating
    }

    /// Returns the dot product of this vector and `other`.
    func dot(_ other: Vec2) -> Float {
        return simd_dot(self, other)
    }

    /// Returns the distance from this vector to `other`.
    func distance(to other: Vec2) -> Float {
        return simd_distance(self, other)
    }

    /// Returns the z-component of the cross product of two 2D vectors (treating them as 3D with z=0).
    /// While a true cross product requires 3D vectors, the z-component of the result is useful in 2D
    /// for determining the sign of the angle between two vectors — positive means `other` is
    /// counterclockwise from `self`, negative means clockwise. This is commonly used to decide
    /// which direction to rotate toward a target.
    func cross(_ other: Vec2) -> Float {
        return x * other.y - y * other.x
    }

    /// Returns a random Vec2 with each component sampled from the given ranges.
    static func random(x: ClosedRange<Float>, y: ClosedRange<Float>) -> Vec2 {
        return Vec2(Float.random(in: x), Float.random(in: y))
    }

    /// Random unit vector (point on unit circle).
    static func randomDirection() -> Vec2 {
        let angle = Float.random(in: 0...GameMath.twoPi)
        return Vec2(cos(angle), sin(angle))
    }

    /// Extends this Vec2 to a Vec3 with the given z component (default 0).
    func to3D(_ z: Float = 0) -> Vec3 {
        return Vec3(x, y, z)
    }

    /// Extends this Vec2 to a Vec4 with the given z and w components.
    func to4D(z: Float, w: Float) -> Vec4 {
        return Vec4(x, y, z, w)
    }

    /// Linearly interpolates between this vector and `to` by factor `t` (0 = self, 1 = to).
    func lerp(to: Vec2, t: Float) -> Vec2 {
        simd_mix(self, to, Vec2(repeating: t))
    }
}

/// Returns `true` if two Vec2 values are equal within `GameMath.epsilon` tolerance.
public func simd_epsilon_equal(lhs: Vec2, rhs: Vec2) -> Bool {
    let diff = simd_abs(lhs - rhs)
    return diff.x < GameMath.epsilon && diff.y < GameMath.epsilon
}
