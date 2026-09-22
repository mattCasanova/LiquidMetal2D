//
//  SeededRandom.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

/// A small, fast, seedable random number generator (SplitMix64).
///
/// The same seed always gives the same sequence, so tests can assert exact
/// values and a replay can reproduce an effect. Use it anywhere the engine
/// takes a `RandomNumberGenerator`; the default everywhere is still
/// `SystemRandomNumberGenerator`.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Concrete wrapper around `any RandomNumberGenerator`, because the standard
/// library's `random(in:using:)` takes a generic `inout` generator and an
/// existential can't be passed there directly.
struct AnyRandomNumberGenerator: RandomNumberGenerator {
    var base: any RandomNumberGenerator

    mutating func next() -> UInt64 {
        return base.next()
    }
}
