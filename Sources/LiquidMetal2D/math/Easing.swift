//
//  Easing.swift
//
//
//  Created by Matt Casanova on 3/16/26.
//

/// Standard easing functions. Input t should be in range 0–1.
public enum Easing {

    // MARK: - Quadratic

    /// Starts slow, accelerates. t² curve.
    public static func easeInQuad(_ t: Float) -> Float {
        return t * t
    }

    /// Starts fast, decelerates. Inverse t² curve.
    public static func easeOutQuad(_ t: Float) -> Float {
        return t * (2 - t)
    }

    /// Slow start and end, fast middle. Quadratic.
    public static func easeInOutQuad(_ t: Float) -> Float {
        return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }

    // MARK: - Cubic

    /// Starts slow, accelerates. t³ curve.
    public static func easeInCubic(_ t: Float) -> Float {
        return t * t * t
    }

    /// Starts fast, decelerates. Inverse t³ curve.
    public static func easeOutCubic(_ t: Float) -> Float {
        let u = t - 1
        return u * u * u + 1
    }

    /// Slow start and end, fast middle. Cubic.
    public static func easeInOutCubic(_ t: Float) -> Float {
        if t < 0.5 {
            return 4 * t * t * t
        }
        let u = 2 * t - 2
        return (u * u * u + 2) / 2
    }

    // MARK: - Quartic

    /// Starts slow, accelerates. t⁴ curve.
    public static func easeInQuart(_ t: Float) -> Float {
        return t * t * t * t
    }

    /// Starts fast, decelerates. Inverse t⁴ curve.
    public static func easeOutQuart(_ t: Float) -> Float {
        let u = t - 1
        return 1 - u * u * u * u
    }

    /// Slow start and end, fast middle. Quartic.
    public static func easeInOutQuart(_ t: Float) -> Float {
        if t < 0.5 {
            return 8 * t * t * t * t
        }
        let u = t - 1
        return 1 - 8 * u * u * u * u
    }

    // MARK: - Sine

    /// Starts slow, accelerates. Sine curve.
    public static func easeInSine(_ t: Float) -> Float {
        return 1 - cos(t * Float.pi / 2)
    }

    /// Starts fast, decelerates. Sine curve.
    public static func easeOutSine(_ t: Float) -> Float {
        return sin(t * Float.pi / 2)
    }

    /// Slow start and end, fast middle. Sine curve.
    public static func easeInOutSine(_ t: Float) -> Float {
        return (1 - cos(Float.pi * t)) / 2
    }

    // MARK: - Exponential

    /// Starts slow, accelerates exponentially.
    public static func easeInExpo(_ t: Float) -> Float {
        return t == 0 ? 0 : pow(2, 10 * (t - 1))
    }

    /// Starts fast, decelerates exponentially.
    public static func easeOutExpo(_ t: Float) -> Float {
        return t == 1 ? 1 : 1 - pow(2, -10 * t)
    }

    /// Slow start and end, fast middle. Exponential curve.
    public static func easeInOutExpo(_ t: Float) -> Float {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        if t < 0.5 {
            return pow(2, 20 * t - 10) / 2
        }
        return (2 - pow(2, -20 * t + 10)) / 2
    }

    // MARK: - Elastic

    /// Oscillates with increasing amplitude, like a spring winding up.
    public static func easeInElastic(_ t: Float) -> Float {
        return sin(13 * Float.pi / 2 * t) * pow(2, 10 * (t - 1))
    }

    /// Oscillates with decreasing amplitude, like a spring settling.
    public static func easeOutElastic(_ t: Float) -> Float {
        return sin(-13 * Float.pi / 2 * (t + 1)) * pow(2, -10 * t) + 1
    }

    /// Elastic oscillation at both ends.
    public static func easeInOutElastic(_ t: Float) -> Float {
        if t < 0.5 {
            return 0.5 * sin(13 * Float.pi * t) * pow(2, 10 * (2 * t - 1))
        }
        return 0.5 * (sin(-13 * Float.pi * t) * pow(2, -10 * (2 * t - 1)) + 2)
    }

    // MARK: - Bounce

    /// Bounces at the end, like a ball hitting the floor.
    public static func easeOutBounce(_ t: Float) -> Float {
        if t < 1 / 2.75 {
            return 7.5625 * t * t
        } else if t < 2 / 2.75 {
            let u = t - 1.5 / 2.75
            return 7.5625 * u * u + 0.75
        } else if t < 2.5 / 2.75 {
            let u = t - 2.25 / 2.75
            return 7.5625 * u * u + 0.9375
        } else {
            let u = t - 2.625 / 2.75
            return 7.5625 * u * u + 0.984375
        }
    }

    /// Bounces at the start, like a ball thrown upward.
    public static func easeInBounce(_ t: Float) -> Float {
        return 1 - easeOutBounce(1 - t)
    }

    /// Bounces at both start and end.
    public static func easeInOutBounce(_ t: Float) -> Float {
        if t < 0.5 {
            return (1 - easeOutBounce(1 - 2 * t)) / 2
        }
        return (1 + easeOutBounce(2 * t - 1)) / 2
    }

    // MARK: - Back (overshoot)

    /// Pulls back slightly before accelerating forward.
    public static func easeInBack(_ t: Float) -> Float {
        let s: Float = 1.70158
        return t * t * ((s + 1) * t - s)
    }

    /// Overshoots the target then settles back.
    public static func easeOutBack(_ t: Float) -> Float {
        let s: Float = 1.70158
        let u = t - 1
        return u * u * ((s + 1) * u + s) + 1
    }

    /// Pulls back at start, overshoots at end.
    public static func easeInOutBack(_ t: Float) -> Float {
        let s: Float = 1.70158 * 1.525
        if t < 0.5 {
            return (4 * t * t * ((s + 1) * 2 * t - s)) / 2
        }
        let u = 2 * t - 2
        return (u * u * ((s + 1) * u + s) + 2) / 2
    }
}
