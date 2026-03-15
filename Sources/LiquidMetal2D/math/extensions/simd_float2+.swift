//
//  File.swift
//
//
//  Created by Matt Casanova on 4/7/20.
//

import simd

/// Extension for simd_float2 that adds convenience methods for setting or converting between types
public extension simd_float2 {

    /// The angle between this vector and the x axis
    var angle: Float { atan2(y, x) }

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
    init(simd3: simd_float3) {
        self.init(simd3.x, simd3.y)
    }

    /// Convenience setter for setting x and y components from floats in one line.
    mutating func set(_ x: Float = 0, _ y: Float = 0) {
        self.x = x
        self.y = y
    }

    mutating func set(u: Float, v: Float) {
        self.x = u
        self.y = v
    }

    mutating func set(angle: Float) {
        self.x = cos(angle)
        self.y = sin(angle)
    }

    mutating func set(repeating: Float) {
        self.x = repeating
        self.y = repeating
    }

    func to3D(_ z: Float = 0) -> simd_float3 {
        return simd_float3(x, y, z)
    }

    func to4D(z: Float, w: Float) -> simd_float4 {
        return simd_float4(x, y, z, w)
    }
}

public func simd_epsilon_equal(lhs: simd_float2, rhs: simd_float2) -> Bool {
    let diff = simd_abs(lhs - rhs)
    return diff.x < epsilon && diff.y < epsilon
}
