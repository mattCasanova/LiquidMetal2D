//
//  MetalMath.swift
//
//
//  Created by Matt Casanova on 4/2/20.
//

public let epsilon: Float   = 0.00001
public let pi: Float        = 3.14159265358979
public let piOverTwo: Float = pi / 2
public let twoPi: Float     = 2 * pi

let radianConversion = 180 / pi
let degreeConversion = pi / 180

public func radianToDegree(_ radian: Float) -> Float {
    return radian * radianConversion
}

public func degreeToRadian(_ degree: Float) -> Float {
    return degree * degreeConversion
}

public func clamp<T: Comparable>(value: T, low: T, high: T) -> T {
    if value < low {
        return low
    }

    if value > high {
        return high
    }

    return value
}

public func wrapEdge<T: Comparable>(value: T, low: T, high: T) -> T {
    if value < low {
        return high
    }

    if value > high {
        return low
    }
    return value
}

public func wrap<T: Comparable & Numeric>(value: T, low: T, high: T) -> T {
    if value < low {
        return wrap(value: high + value - low, low: low, high: high)
    }

    if value > high {
        return wrap(value: low + value - high, low: low, high: high)
    }

    return value
}

public func isInRange<T: Comparable>(value: T, low: T, high: T) -> Bool {
    return (value >= low && value <= high)
}

public func isFloatEqual(_ x: Float, _ y: Float) -> Bool {
    return abs(x - y) < epsilon
}

public func isPowerOfTwo(_ value: Int) -> Bool {
    // Make sure it is a positive number. Since a power of two only has one bit
    // turned on, if we subtract 1 and 'and' them together no bits should be on.
    return ((value > 0) && (value & (value - 1)) == 0)
}

public func nextPowerOfTwo(_ value: Int) -> Int {
    // Turn on all of the bits lower than the highest on bit. Then add one.
    var x = value
    x |= x >> 1
    x |= x >> 2
    x |= x >> 4
    x |= x >> 8
    x |= x >> 16
    x += 1
    return x
}
