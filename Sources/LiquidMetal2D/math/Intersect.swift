//
//  Intersect.swift
//
//
//  Created by Matt Casanova on 4/4/20.
//

/// Namespace for 2D intersection/collision tests.
/// Uses an enum instead of a class to prevent accidental instantiation.
public enum Intersect {

    // MARK: - Point vs Circle

    /// Returns `true` if a point lies inside or on a circle.
    @inlinable
    public static func pointCircle(point: Vec2, circle: Vec2, radius: Float) -> Bool {
        return simd_length_squared(point - circle) <= radius * radius
    }

    /// Returns `true` if a point lies inside or on a `Circle`.
    @inlinable
    public static func pointCircle(point: Vec2, circle: Circle) -> Bool {
        return pointCircle(point: point, circle: circle.center, radius: circle.radius)
    }

    // MARK: - Point vs AABB

    /// Returns `true` if a point lies inside or on an axis-aligned bounding box.
    @inlinable
    public static func pointAABB(point: Vec2, center: Vec2, width: Float, height: Float) -> Bool {
        let halfWidth = width / 2
        let halfHeight = height / 2
        let adjustedPoint = point - center

        return GameMath.isInRange(value: adjustedPoint.x, low: -halfWidth, high: halfWidth) &&
            GameMath.isInRange(value: adjustedPoint.y, low: -halfHeight, high: halfHeight)
    }

    /// Returns `true` if a point lies inside or on an `AABB`.
    @inlinable
    public static func pointAABB(point: Vec2, aabb: AABB) -> Bool {
        return pointAABB(point: point, center: aabb.center, width: aabb.width, height: aabb.height)
    }

    // MARK: - Point vs Line Segment

    /// Returns `true` if a point lies within `GameMath.epsilon` of a line segment.
    ///
    /// The tolerance is a distance, so it means the same thing on a 1-unit
    /// segment and a 1000-unit one. No square roots: the perpendicular
    /// distance test is `cross² <= epsilon² * length²`, and the "between the
    /// endpoints" test compares the dot product against `length²`.
    @inlinable
    public static func pointLineSegment(point: Vec2, start: Vec2, end: Vec2) -> Bool {
        let line = end - start
        let lengthSquared = simd_length_squared(line)
        guard lengthSquared > 0 else {
            // Degenerate segment: it is a point.
            return simd_epsilon_equal(lhs: point, rhs: start)
        }

        let toPoint = point - start
        let cross = line.cross(toPoint)
        guard cross * cross <= GameMath.epsilon * GameMath.epsilon * lengthSquared else {
            return false
        }

        let along = simd_dot(toPoint, line)
        return along >= 0 && along <= lengthSquared
    }

    // MARK: - Circle vs Circle

    /// Returns `true` if two circles overlap or touch.
    @inlinable
    public static func circleCircle(
        center1: Vec2, center2: Vec2, radius1: Float, radius2: Float
    ) -> Bool {
        let radius = radius1 + radius2
        return simd_length_squared(center1 - center2) <= radius * radius
    }

    /// Returns `true` if two `Circle` instances overlap or touch.
    @inlinable
    public static func circleCircle(_ first: Circle, _ second: Circle) -> Bool {
        return circleCircle(
            center1: first.center, center2: second.center,
            radius1: first.radius, radius2: second.radius)
    }

    // MARK: - Circle vs AABB

    /// Returns `true` if a circle and an axis-aligned bounding box overlap or touch.
    @inlinable
    public static func circleAABB(
        circleCenter: Vec2, radius: Float, aabbCenter: Vec2, width: Float, height: Float
    ) -> Bool {
        let halfWidth = width / 2
        let halfHeight = height / 2
        let adjustedPoint = circleCenter - aabbCenter

        let closestPoint = simd_clamp(
            adjustedPoint,
            Vec2(-halfWidth, -halfHeight),
            Vec2(halfWidth, halfHeight))

        if GameMath.isInRange(value: adjustedPoint.x, low: -halfWidth, high: halfWidth) &&
            GameMath.isInRange(value: adjustedPoint.y, low: -halfHeight, high: halfHeight) {
            return true
        }

        return simd_length_squared(adjustedPoint - closestPoint) < (radius * radius)
    }

    /// Returns `true` if a `Circle` and an `AABB` overlap or touch.
    @inlinable
    public static func circleAABB(circle: Circle, aabb: AABB) -> Bool {
        return circleAABB(
            circleCenter: circle.center, radius: circle.radius,
            aabbCenter: aabb.center, width: aabb.width, height: aabb.height)
    }

    // MARK: - Circle vs Line Segment

    /// Returns `true` if a circle and a line segment overlap or touch.
    ///
    /// No square roots and no divides. The dot product of `center - start`
    /// with the segment says which part of the segment is closest: behind
    /// `start`, past `end`, or somewhere between. In between, the cross
    /// product is `length × distance`, so `distance ≤ radius` becomes
    /// `cross² ≤ radius² × length²`. A zero-length segment has a dot of 0 and
    /// takes the first branch, which tests it as a point.
    @inlinable
    public static func circleLineSegment(
        center: Vec2, radius: Float, start: Vec2, end: Vec2
    ) -> Bool {
        let line = end - start
        let toCenter = center - start
        let radiusSquared = radius * radius
        let along = simd_dot(toCenter, line)

        if along <= 0 {
            return simd_length_squared(toCenter) <= radiusSquared
        }
        let lengthSquared = simd_length_squared(line)
        if along >= lengthSquared {
            return simd_length_squared(center - end) <= radiusSquared
        }
        let cross = line.cross(toCenter)
        return cross * cross <= radiusSquared * lengthSquared
    }

    // MARK: - Ray vs Line Segment

    /// Distance along a ray to where it crosses a segment, or nil when the
    /// ray misses, runs parallel, or would have to go backwards.
    ///
    /// Solves `origin + t·direction = start + u·(end − start)` with two
    /// cross products; a hit needs `t ≥ 0` and `0 ≤ u ≤ 1`. `direction`
    /// should be a unit vector so `t` is a distance. A zero-length segment
    /// counts as parallel: it blocks nothing.
    @inlinable
    public static func raySegment(origin: Vec2, direction: Vec2, start: Vec2, end: Vec2) -> Float? {
        let edge = end - start
        let denominator = direction.cross(edge)
        guard abs(denominator) >= 1e-8 else { return nil }
        let toStart = start - origin
        let t = toStart.cross(edge) / denominator
        let u = toStart.cross(direction) / denominator
        guard t >= 0, u >= 0, u <= 1 else { return nil }
        return t
    }

    // MARK: - Segment vs AABB

    /// Where a segment enters an axis-aligned box: the fraction along
    /// `start → end` in 0…1 and the unit normal of the face it crosses, or
    /// nil when it misses. A start point strictly inside the box returns 0
    /// with the normal of the nearest face, so a caller sees the overlap
    /// instead of stepping out through it. A start point on a face is
    /// outside: heading away from the face it misses, heading in it hits
    /// at 0. That is what lets a thing resting on a box launch off it.
    ///
    /// The slab method: each axis clips the segment to the box's extent on
    /// that axis; the latest entry is where the segment enters, the
    /// earliest exit is where it leaves, and a miss is an entry after the
    /// exit or an exit at or before the start. The test is closed, so a
    /// segment that only touches a face or a corner, or ends on a face,
    /// counts as a hit; the one exception is a segment running exactly
    /// along a face's line, which slides past (a thing sitting on the box
    /// can move along it).
    @inlinable
    public static func segmentAABB(
        start: Vec2, end: Vec2, center: Vec2, width: Float, height: Float
    ) -> (t: Float, normal: Vec2)? {
        let half = Vec2(width / 2, height / 2)
        let low = center - half
        let high = center + half
        if start.x > low.x, start.x < high.x, start.y > low.y, start.y < high.y {
            return (0, nearestFaceNormal(of: start - center, half: half))
        }
        let delta = end - start
        var entry = -Float.infinity
        var exit = Float.infinity
        var normal = Vec2()
        for axis in 0..<2 {
            let s = start[axis]
            let d = delta[axis]
            if d == 0 {
                // Parallel to this slab: the start must already be strictly
                // between its faces; on a face line it slides past.
                guard s > low[axis], s < high[axis] else { return nil }
                continue
            }
            var near = (low[axis] - s) / d
            var far = (high[axis] - s) / d
            var nearSign: Float = -1
            if near > far {
                swap(&near, &far)
                nearSign = 1
            }
            if near > entry {
                entry = near
                normal = axis == 0 ? Vec2(nearSign, 0) : Vec2(0, nearSign)
            }
            exit = min(exit, far)
        }
        guard entry <= exit, exit > 0, entry <= 1 else { return nil }
        return (max(entry, 0), normal)
    }

    /// The outward normal of the face of a box (half-extents `half`,
    /// centred at the origin) nearest to `point`, a point inside it.
    @inlinable
    public static func nearestFaceNormal(of point: Vec2, half: Vec2) -> Vec2 {
        let toLeft = point.x + half.x
        let toRight = half.x - point.x
        let toBottom = point.y + half.y
        let toTop = half.y - point.y
        let nearest = min(min(toLeft, toRight), min(toBottom, toTop))
        if nearest == toLeft { return Vec2(-1, 0) }
        if nearest == toRight { return Vec2(1, 0) }
        if nearest == toBottom { return Vec2(0, -1) }
        return Vec2(0, 1)
    }

    // MARK: - Segment vs Segment

    /// The fraction along `first` where it crosses `second`, or nil when
    /// they miss, run parallel or lie on one line (a collinear overlap has
    /// no single crossing; callers that care test the endpoints).
    ///
    /// Solves `a + t·(b − a) = c + u·(d − c)` with two cross products; a
    /// hit needs both `t` and `u` in 0…1, endpoints included.
    @inlinable
    public static func segmentSegment(_ first: LineSegment, _ second: LineSegment) -> Float? {
        let direction = first.end - first.start
        let edge = second.end - second.start
        let denominator = direction.cross(edge)
        guard abs(denominator) >= 1e-8 else { return nil }
        let toStart = second.start - first.start
        let t = toStart.cross(edge) / denominator
        let u = toStart.cross(direction) / denominator
        guard t >= 0, t <= 1, u >= 0, u <= 1 else { return nil }
        return t
    }

    // MARK: - AABB vs AABB

    /// Returns `true` if two `AABB` instances overlap or touch.
    @inlinable
    public static func aabbAABB(_ first: AABB, _ second: AABB) -> Bool {
        return pointAABB(
            point: first.center, center: second.center,
            width: first.width + second.width, height: first.height + second.height)
    }
}
