//
//  Keyframe.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

/// One key on an animation channel.
public struct Keyframe<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    /// Seconds from the start of the clip.
    public var time: Float
    public var value: Value
    /// Shapes the segment that starts at this key and runs to the next one.
    public var easing: EasingType

    public init(time: Float, value: Value, easing: EasingType = .linear) {
        self.time = time
        self.value = value
        self.easing = easing
    }
}

extension Array {

    /// Samples a channel of keys at time `t`, or `nil` if the channel has no keys.
    ///
    /// Before the first key holds the first value, after the last key holds the
    /// last. Two keys at the same time make an instant jump.
    func sample<Value>(at t: Float, lerp: (Value, Value, Float) -> Value) -> Value?
    where Element == Keyframe<Value> {
        guard let first, let last else { return nil }
        if t <= first.time { return first.value }
        if t >= last.time { return last.value }

        // first.time < t < last.time, so a segment with k0.time <= t < k1.time exists.
        var index = 0
        while self[index + 1].time <= t {
            index += 1
        }
        let k0 = self[index]
        let k1 = self[index + 1]
        let u = (t - k0.time) / (k1.time - k0.time)
        return lerp(k0.value, k1.value, k0.easing.apply(u))
    }

    /// True when no key comes before the one ahead of it.
    func isSortedByTime<Value>() -> Bool where Element == Keyframe<Value> {
        zip(self, dropFirst()).allSatisfy { $0.time <= $1.time }
    }
}
