//
//  Vec3+.swift
//
//
//  Created by Matt Casanova on 4/13/20.
//

/// Convenience methods for Vec3 including swizzles, color accessors, and type conversions.
public extension Vec3 {
    /// The x and y components as a Vec2.
    var xy: Vec2 { Vec2(x, y) }

    /// The length (magnitude) of this vector
    var length: Float { simd_length(self) }

    /// The squared length of this vector (avoids a sqrt — use for comparisons)
    var lengthSquared: Float { simd_length_squared(self) }

    /// Returns a unit vector in the same direction, or zero if length is zero
    var normalized: Vec3 { simd_normalize(self) }

    /// Red channel accessor (maps to x).
    var r: Float {
        get { x }
        set { x = newValue }
    }
    /// Green channel accessor (maps to y).
    var g: Float {
        get { y }
        set { y = newValue }
    }
    /// Blue channel accessor (maps to z).
    var b: Float {
        get { z }
        set { z = newValue }
    }

    /// Sets x, y, and z components from floats in one call.
    mutating func set(_ x: Float = 0, _ y: Float = 0, _ z: Float = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Sets components using color channel names (r, g, b).
    mutating func set(r: Float, g: Float, b: Float) {
        self.x = r
        self.y = g
        self.z = b
    }

    /// Sets all three components to the same value.
    mutating func set(repeating: Float) {
        self.x = repeating
        self.y = repeating
        self.z = repeating
    }

    /// Returns a random Vec3 with each component sampled from the given ranges.
    static func random(x: ClosedRange<Float>, y: ClosedRange<Float>, z: ClosedRange<Float>) -> Vec3 {
        return Vec3(Float.random(in: x), Float.random(in: y), Float.random(in: z))
    }

    /// Returns the dot product of this vector and `other`.
    func dot(_ other: Vec3) -> Float {
        return simd_dot(self, other)
    }

    /// Returns the distance from this vector to `other`.
    func distance(to other: Vec3) -> Float {
        return simd_distance(self, other)
    }

    /// Extends this Vec3 to a Vec4 with the given w component (default 0).
    func to4D(_ w: Float = 0) -> Vec4 {
        return Vec4(x, y, z, w)
    }
}

/// Returns `true` if two Vec3 values are equal within `GameMath.epsilon` tolerance.
public func simd_epsilon_equal(lhs: Vec3, rhs: Vec3) -> Bool {
    let diff = simd_abs(lhs - rhs)
    return diff.x < GameMath.epsilon && diff.y < GameMath.epsilon && diff.z < GameMath.epsilon
}
