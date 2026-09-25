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
    /// Finds the closest point on the segment to the circle's center and
    /// compares the squared distance to `radius²`. No square roots, and the
    /// segment's end caps are round, as they must be.
    @inlinable
    public static func circleLineSegment(
        center: Vec2, radius: Float, start: Vec2, end: Vec2
    ) -> Bool {
        let line = end - start
        let lengthSquared = simd_length_squared(line)
        guard lengthSquared > 0 else {
            // Degenerate segment: it is a point.
            return pointCircle(point: start, circle: center, radius: radius)
        }

        let t = GameMath.clamp(value: simd_dot(center - start, line) / lengthSquared, low: 0, high: 1)
        let closest = start + line * t
        return simd_length_squared(center - closest) <= radius * radius
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
