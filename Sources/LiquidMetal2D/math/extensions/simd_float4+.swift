//
//  Vec4+.swift
//
//
//  Created by Matt Casanova on 4/15/20.
//

/// Convenience methods for Vec4 including color, sprite sheet UV, and swizzle accessors.
public extension Vec4 {
    /// The x, y, and z components as a Vec3.
    var xyz: Vec3 { Vec3(x, y, z) }

    /// Color RGB components as a Vec3 (maps to x, y, z).
    var rgb: Vec3 { Vec3(x, y, z) }

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
    /// Alpha channel accessor (maps to w).
    var a: Float {
        get { w }
        set { w = newValue }
    }

    /// Sprite sheet UV scale X (maps to x).
    var sx: Float {
        get { x }
        set { x = newValue }
    }
    /// Sprite sheet UV scale Y (maps to y).
    var su: Float {
        get { y }
        set { y = newValue }
    }
    /// Sprite sheet UV translate X (maps to z).
    var tx: Float {
        get { z }
        set { z = newValue }
    }
    /// Sprite sheet UV translate Y (maps to w).
    var ty: Float {
        get { w }
        set { w = newValue }
    }

    /// Sets all four components from floats in one call.
    mutating func set(_ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    /// Sets components using color channel names (r, g, b, a).
    mutating func set(r: Float, g: Float, b: Float, a: Float) {
        self.x = r
        self.y = g
        self.z = b
        self.w = a
    }

    /// Sets components using sprite sheet UV transform names (sx, sy, tx, ty).
    mutating func set(sx: Float, sy: Float, tx: Float, ty: Float) {
        self.x = sx
        self.y = sy
        self.z = tx
        self.w = ty
    }

    /// Sets all four components to the same value.
    mutating func set(repeating: Float) {
        self.x = repeating
        self.y = repeating
        self.z = repeating
        self.w = repeating
    }
}

/// Returns `true` if two Vec4 values are equal within `GameMath.epsilon` tolerance.
public func simd_epsilon_equal(lhs: Vec4, rhs: Vec4) -> Bool {
    let diff = simd_abs(lhs - rhs)
    return diff.x < GameMath.epsilon
    && diff.y < GameMath.epsilon
    && diff.z < GameMath.epsilon
    && diff.w < GameMath.epsilon
}
