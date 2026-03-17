//
//  Math.swift
//
//
//  Created by Matt Casanova on 4/2/20.
//

import simd

/// Namespace for math constants and utility functions.
public enum GameMath {

    // MARK: - Constants

    public static let epsilon: Float   = 0.00001
    public static let pi: Float        = Float.pi
    public static let piOverTwo: Float = Float.pi / 2
    public static let twoPi: Float     = Float.pi * 2

    private static let radianConversion: Float = 180 / Float.pi
    private static let degreeConversion: Float = Float.pi / 180

    // MARK: - Angle Conversion

    public static func radianToDegree(_ radian: Float) -> Float {
        return radian * radianConversion
    }

    public static func degreeToRadian(_ degree: Float) -> Float {
        return degree * degreeConversion
    }

    // MARK: - Clamping

    /// Clamps a value to the range [low, high].
    public static func clamp<T: Comparable>(value: T, low: T, high: T) -> T {
        return min(max(value, low), high)
    }

    /// Clamps a simd_float2 component-wise to the range [low, high].
    public static func clamp(value: simd_float2, low: simd_float2, high: simd_float2) -> simd_float2 {
        return simd_clamp(value, low, high)
    }

    /// Clamps a simd_float3 component-wise to the range [low, high].
    public static func clamp(value: simd_float3, low: simd_float3, high: simd_float3) -> simd_float3 {
        return simd_clamp(value, low, high)
    }

    // MARK: - Wrapping

    /// Snaps to the opposite edge when value crosses a boundary.
    /// Unlike `wrap`, this doesn't preserve the overshoot amount.
    public static func wrapEdge<T: Comparable>(value: T, low: T, high: T) -> T {
        if value < low { return high }
        if value > high { return low }
        return value
    }

    /// Wraps a float value into the range [low, high] using modulo arithmetic.
    /// Safe for any input magnitude — no recursion or stack overflow risk.
    public static func wrap(value: Float, low: Float, high: Float) -> Float {
        let range = high - low
        guard range > 0 else { return low }

        let offset = (value - low).truncatingRemainder(dividingBy: range)
        return offset >= 0 ? low + offset : low + offset + range
    }

    // MARK: - Range Checking

    public static func isInRange<T: Comparable>(value: T, low: T, high: T) -> Bool {
        return value >= low && value <= high
    }

    // MARK: - Float Comparison

    public static func isFloatEqual(_ x: Float, _ y: Float) -> Bool {
        return abs(x - y) < epsilon
    }

    // MARK: - Power of Two

    public static func isPowerOfTwo(_ value: Int) -> Bool {
        // A power of two only has one bit set. Subtracting 1 flips all lower bits.
        // AND-ing them together gives 0 only for powers of two.
        return (value > 0) && (value & (value - 1)) == 0
    }

    /// Returns the next power of two greater than the input value.
    /// Note: if the input is already a power of two, this returns the NEXT one
    /// (e.g., 4 → 8, 64 → 128). This is intentional.
    public static func nextPowerOfTwo(_ value: Int) -> Int {
        var x = value
        x |= x >> 1
        x |= x >> 2
        x |= x >> 4
        x |= x >> 8
        x |= x >> 16
        x += 1
        return x
    }
}
