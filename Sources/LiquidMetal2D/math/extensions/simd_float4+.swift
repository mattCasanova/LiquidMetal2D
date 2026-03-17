//
//  Vec4+.swift
//
//
//  Created by Matt Casanova on 4/15/20.
//


public extension Vec4 {
    var xyz: Vec3 { Vec3(x, y, z) }

    var rgb: Vec3 { Vec3(x, y, z) }

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
    var a: Float {
        get { w }
        set { w = newValue }
    }

    var sx: Float {
        get { x }
        set { x = newValue }
    }
    var su: Float {
        get { y }
        set { y = newValue }
    }
    var tx: Float {
        get { z }
        set { z = newValue }
    }
    var ty: Float {
        get { w }
        set { w = newValue }
    }

    mutating func set(_ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    mutating func set(r: Float, g: Float, b: Float, a: Float) {
        self.x = r
        self.y = g
        self.z = b
        self.w = a
    }

    mutating func set(sx: Float, sy: Float, tx: Float, ty: Float) {
        self.x = sx
        self.y = sy
        self.z = tx
        self.w = ty
    }

    mutating func set(repeating: Float) {
        self.x = repeating
        self.y = repeating
        self.z = repeating
        self.w = repeating
    }
}

public func simd_epsilon_equal(lhs: Vec4, rhs: Vec4) -> Bool {
    let diff = simd_abs(lhs - rhs)
    return diff.x < GameMath.epsilon
    && diff.y < GameMath.epsilon
    && diff.z < GameMath.epsilon
    && diff.w < GameMath.epsilon
}
