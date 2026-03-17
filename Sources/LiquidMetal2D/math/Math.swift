//
//  Math.swift
//
//
//  Created by Matt Casanova on 4/2/20.
//

/// Namespace for math constants and utility functions.
public enum GameMath {

    // MARK: - Constants

    public static let epsilon: Float   = 0.00001
    public static let pi: Float        = Float.pi
    public static let piOverTwo: Float = pi / 2
    public static let twoPi: Float     = pi * 2

    private static let radianConversion: Float = 180 / pi
    private static let degreeConversion: Float = pi / 180

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

    /// Clamps a Vec2 component-wise to the range [low, high].
    public static func clamp(value: Vec2, low: Vec2, high: Vec2) -> Vec2 {
        return simd_clamp(value, low, high)
    }

    /// Clamps a Vec3 component-wise to the range [low, high].
    public static func clamp(value: Vec3, low: Vec3, high: Vec3) -> Vec3 {
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

    // MARK: - Interpolation

    public static func lerp(a: Float, b: Float, t: Float) -> Float {
        return a + (b - a) * t
    }

    public static func lerp(a: Vec2, b: Vec2, t: Float) -> Vec2 {
        return a + (b - a) * t
    }

    public static func lerp(a: Vec3, b: Vec3, t: Float) -> Vec3 {
        return a + (b - a) * t
    }

    /// Given a value between a and b, returns the normalized t (0–1).
    public static func inverseLerp(a: Float, b: Float, value: Float) -> Float {
        return (value - a) / (b - a)
    }

    /// Remaps a value from one range to another.
    public static func remap(value: Float, fromLow: Float, fromHigh: Float, toLow: Float, toHigh: Float) -> Float {
        let t = inverseLerp(a: fromLow, b: fromHigh, value: value)
        return lerp(a: toLow, b: toHigh, t: t)
    }

    // MARK: - Smoothstep

    /// Hermite interpolation — smooth ease-in/ease-out between 0 and 1.
    public static func smoothstep(edge0: Float, edge1: Float, x: Float) -> Float {
        let t = clamp(value: (x - edge0) / (edge1 - edge0), low: 0.0, high: 1.0)
        return t * t * (3 - 2 * t)
    }

    /// Smoother version of smoothstep with zero first and second derivatives at edges.
    public static func smootherstep(edge0: Float, edge1: Float, x: Float) -> Float {
        let t = clamp(value: (x - edge0) / (edge1 - edge0), low: 0.0, high: 1.0)
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    // MARK: - Bezier Curves

    /// Quadratic bezier: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
    public static func quadraticBezier(p0: Vec2, p1: Vec2, p2: Vec2, t: Float) -> Vec2 {
        let u = 1 - t
        return u * u * p0 + 2 * u * t * p1 + t * t * p2
    }

    /// Cubic bezier: B(t) = (1-t)³P0 + 3(1-t)²tP1 + 3(1-t)t²P2 + t³P3
    public static func cubicBezier(p0: Vec2, p1: Vec2, p2: Vec2, p3: Vec2, t: Float) -> Vec2 {
        let u = 1 - t
        return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
    }
}
