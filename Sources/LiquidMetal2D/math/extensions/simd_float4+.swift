//
//  File.swift
//
//
//  Created by Matt Casanova on 4/15/20.
//

import simd

public extension simd_float4 {
    var xyz: simd_float3 { simd_float3(x, y, z) }

    var rgb: simd_float3 { simd_float3(x, y, z) }

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

public func simd_epsilon_equal(lhs: simd_float4, rhs: simd_float4) -> Bool {
    let diff = simd_abs(lhs - rhs)
    return diff.x < epsilon && diff.y < epsilon && diff.z < epsilon && diff.w < epsilon
}
