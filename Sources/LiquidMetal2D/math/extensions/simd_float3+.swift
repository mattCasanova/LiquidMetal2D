//
//  Vec3+.swift
//
//
//  Created by Matt Casanova on 4/13/20.
//


public extension Vec3 {
    var xy: Vec2 { Vec2(x, y) }

    /// The length (magnitude) of this vector
    var length: Float { simd_length(self) }

    /// The squared length of this vector (avoids a sqrt — use for comparisons)
    var lengthSquared: Float { simd_length_squared(self) }

    /// Returns a unit vector in the same direction, or zero if length is zero
    var normalized: Vec3 { simd_normalize(self) }

    var r: Float {
        get { x }
        set { x = newValue }
    }
    var g: Float {
        get { y }
        set { y = newValue }
    }
    var b: Float {
        get { z }
        set { z = newValue }
    }

    mutating func set(_ x: Float = 0, _ y: Float = 0, _ z: Float = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    mutating func set(r: Float, g: Float, b: Float) {
        self.x = r
        self.y = g
        self.z = b
    }

    mutating func set(repeating: Float) {
        self.x = repeating
        self.y = repeating
        self.z = repeating
    }

    func to4D(_ w: Float = 0) -> Vec4 {
        return Vec4(x, y, z, w)
    }
}

public func simd_epsilon_equal(lhs: Vec3, rhs: Vec3) -> Bool {
    let diff = simd_abs(lhs - rhs)
    return diff.x < GameMath.epsilon && diff.y < GameMath.epsilon && diff.z < GameMath.epsilon
}
