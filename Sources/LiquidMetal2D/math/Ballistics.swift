//
//  Ballistics.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/18/26.
//

/// The closed-form motion of a thrown or jumping thing under constant
/// gravity: `p(t) = p0 + v0·t + ½·g·t²` and `v(t) = v0 + g·t`. Nothing
/// steps; for the first hit along an arc see ``ArcSweep``.
///
/// Gravity is a vector the caller passes (y-up worlds use `(0, −g)`), so
/// an upside-down room or a sideways level costs nothing. The functions
/// that solve for a height or an x need gravity along y alone and assert
/// it. Time is in seconds. No `@MainActor`: pure values, usable from
/// tests, tools and rules code.
///
/// The "launch to hit a target" functions solve the standard problem and
/// return nil when no real solution exists (the target is out of range),
/// never a guess. A zero gravity, speed or time where a formula divides by
/// it is a programmer error and traps.
public enum Ballistics {

    // MARK: - Motion

    /// Where the arc is `t` seconds after launch.
    @inlinable
    public static func position(start: Vec2, velocity: Vec2, gravity: Vec2, at t: Float) -> Vec2 {
        return start + velocity * t + gravity * (0.5 * t * t)
    }

    /// The velocity `t` seconds after launch.
    @inlinable
    public static func velocity(_ velocity: Vec2, gravity: Vec2, at t: Float) -> Vec2 {
        return velocity + gravity * t
    }

    // MARK: - Apex

    /// Time of the highest point against this gravity: when the velocity
    /// along gravity's axis is zero. 0 if the arc is already falling.
    /// Gravity must have a y component.
    @inlinable
    public static func apexTime(velocity: Vec2, gravity: Vec2) -> Float {
        precondition(gravity.y != 0, "Ballistics.apexTime: gravity needs a y component")
        return max(0, -velocity.y / gravity.y)
    }

    /// The highest point of the arc (the start if it is already falling).
    /// Gravity must have a y component.
    @inlinable
    public static func apex(start: Vec2, velocity: Vec2, gravity: Vec2) -> Vec2 {
        let t = apexTime(velocity: velocity, gravity: gravity)
        return position(start: start, velocity: velocity, gravity: gravity, at: t)
    }

    // MARK: - Solving for a time

    /// The times at which the arc is at height `y`: none, one (it only
    /// touches `y` at the apex) or two, ascending, never negative. For
    /// gravity along y alone (asserted), with a y component.
    @inlinable
    public static func times(atHeight y: Float, start: Vec2, velocity: Vec2, gravity: Vec2) -> (Float?, Float?) {
        assert(gravity.x == 0, "Ballistics.times(atHeight:): gravity must be along y alone")
        precondition(gravity.y != 0, "Ballistics.times(atHeight:): gravity needs a y component")
        // ½·gy·t² + vy·t + (y0 − y) = 0, solved the stable way: one root
        // from the quadratic formula, the other from the product of roots,
        // so a height equal to the start gives exactly 0.
        let a = gravity.y / 2
        let b = velocity.y
        let c = start.y - y
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return (nil, nil) }
        let root = discriminant.squareRoot()
        let q = -0.5 * (b + (b < 0 ? -root : root))
        var first: Float
        var second: Float
        if q == 0 {
            // b and c are both 0: the arc starts at `y` with no vertical speed.
            first = 0
            second = 0
        } else {
            first = q / a
            second = c / q
        }
        if first > second { swap(&first, &second) }
        if discriminant == 0 { return (first >= 0 ? first : nil, nil) }
        if first < 0 { return (second >= 0 ? second : nil, nil) }
        return (first, second)
    }

    /// The time at which the arc reaches `x`, or nil when there is no
    /// sideways motion or `x` is behind the start. Gravity must be along y
    /// alone, so x moves at a constant rate.
    @inlinable
    public static func time(atX x: Float, start: Vec2, velocity: Vec2) -> Float? {
        guard velocity.x != 0 else { return nil }
        let t = (x - start.x) / velocity.x
        return t >= 0 ? t : nil
    }

    // MARK: - Launching to a target

    /// The launch velocity of magnitude `speed` whose arc passes through
    /// `target`: the lower, flatter arc, or with `highArc` the lobbed one.
    /// nil when `speed` cannot reach the target. Gravity along y alone
    /// (asserted) with a y component; `speed` above 0.
    @inlinable
    public static func launchVelocity(
        from start: Vec2, to target: Vec2, speed: Float, gravity: Vec2, highArc: Bool = false
    ) -> Vec2? {
        assert(gravity.x == 0, "Ballistics.launchVelocity(speed:): gravity must be along y alone")
        precondition(gravity.y != 0, "Ballistics.launchVelocity(speed:): gravity needs a y component")
        precondition(speed > 0, "Ballistics.launchVelocity(speed:): speed must be above 0, got \(speed)")
        // Solved with gravity pulling down; an upward gravity is the same
        // problem with y flipped.
        let flip: Float = gravity.y < 0 ? 1 : -1
        let g = abs(gravity.y)
        let dx = target.x - start.x
        let dy = (target.y - start.y) * flip
        let speedSquared = speed * speed
        if dx == 0 {
            // Straight up or down: only reachable if the apex is high enough.
            guard dy <= speedSquared / (2 * g) else { return nil }
            let up = dy >= 0 || highArc
            return Vec2(0, (up ? speed : -speed) * flip)
        }
        let discriminant = speedSquared * speedSquared - g * (g * dx * dx + 2 * dy * speedSquared)
        guard discriminant >= 0 else { return nil }
        let root = discriminant.squareRoot()
        // tan θ = (v² ∓ √disc) / (g·dx): the direction vector (g·dx, v² ∓ √disc)
        // keeps the sign of dx and needs no angle.
        let direction = Vec2(g * dx, highArc ? speedSquared + root : speedSquared - root).normalized
        return Vec2(direction.x * speed, direction.y * speed * flip)
    }

    /// The launch velocity whose arc passes through `target` with its apex
    /// `apexHeight` above the start (against gravity). nil when the target
    /// is above that apex. Gravity along y alone (asserted) with a y
    /// component; `apexHeight` above 0.
    @inlinable
    public static func launchVelocity(from start: Vec2, to target: Vec2, apexHeight: Float, gravity: Vec2) -> Vec2? {
        assert(gravity.x == 0, "Ballistics.launchVelocity(apexHeight:): gravity must be along y alone")
        precondition(gravity.y != 0, "Ballistics.launchVelocity(apexHeight:): gravity needs a y component")
        precondition(apexHeight > 0, "Ballistics.launchVelocity(apexHeight:): apexHeight must be above 0")
        let flip: Float = gravity.y < 0 ? 1 : -1
        let g = abs(gravity.y)
        let dy = (target.y - start.y) * flip
        guard dy <= apexHeight else { return nil }
        // Up to the apex, then down from it to the target's height.
        let riseSpeed = (2 * g * apexHeight).squareRoot()
        let time = riseSpeed / g + (2 * (apexHeight - dy) / g).squareRoot()
        return Vec2((target.x - start.x) / time, riseSpeed * flip)
    }

    /// The launch velocity whose arc reaches `target` in exactly `time`
    /// seconds, for any gravity. `time` above 0.
    @inlinable
    public static func launchVelocity(from start: Vec2, to target: Vec2, time: Float, gravity: Vec2) -> Vec2 {
        precondition(time > 0, "Ballistics.launchVelocity(time:): time must be above 0, got \(time)")
        return (target - start - gravity * (0.5 * time * time)) / time
    }
}
