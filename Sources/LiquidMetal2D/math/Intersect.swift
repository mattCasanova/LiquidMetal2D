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
    public static func pointCircle(point: Vec2, circle: Vec2, radius: Float) -> Bool {
        return simd_length_squared(point - circle) - (radius * radius) < GameMath.epsilon
    }

    /// Returns `true` if a point lies inside or on a `Circle`.
    public static func pointCircle(point: Vec2, circle: Circle) -> Bool {
        return pointCircle(point: point, circle: circle.center, radius: circle.radius)
    }

    // MARK: - Point vs AABB

    /// Returns `true` if a point lies inside or on an axis-aligned bounding box.
    public static func pointAABB(point: Vec2, center: Vec2, width: Float, height: Float) -> Bool {
        let halfWidth = width / 2
        let halfHeight = height / 2
        let adjustedPoint = point - center

        return GameMath.isInRange(value: adjustedPoint.x, low: -halfWidth, high: halfWidth) &&
            GameMath.isInRange(value: adjustedPoint.y, low: -halfHeight, high: halfHeight)
    }

    /// Returns `true` if a point lies inside or on an `AABB`.
    public static func pointAABB(point: Vec2, aabb: AABB) -> Bool {
        return pointAABB(point: point, center: aabb.center, width: aabb.width, height: aabb.height)
    }

    // MARK: - Point vs Line Segment

    /// Returns `true` if a point lies on a line segment (within epsilon tolerance).
    public static func pointLineSegment(point: Vec2, start: Vec2, end: Vec2) -> Bool {
        let lineVector = end - start
        let pointLineVector = point - start

        if abs(lineVector.cross(pointLineVector)) > GameMath.epsilon {
            return false
        }

        let projectedLength = simd_dot(pointLineVector, simd_normalize(lineVector))
        return GameMath.isInRange(
            value: projectedLength * projectedLength,
            low: 0,
            high: simd_length_squared(lineVector))
    }

    // MARK: - Circle vs Circle

    /// Returns `true` if two circles overlap or touch.
    public static func circleCircle(
        center1: Vec2, center2: Vec2, radius1: Float, radius2: Float
    ) -> Bool {
        let radius = radius1 + radius2
        return simd_length_squared(center1 - center2) - (radius * radius) < GameMath.epsilon
    }

    /// Returns `true` if two `Circle` instances overlap or touch.
    public static func circleCircle(_ first: Circle, _ second: Circle) -> Bool {
        return circleCircle(
            center1: first.center, center2: second.center,
            radius1: first.radius, radius2: second.radius)
    }

    // MARK: - Circle vs AABB

    /// Returns `true` if a circle and an axis-aligned bounding box overlap or touch.
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
    public static func circleAABB(circle: Circle, aabb: AABB) -> Bool {
        return circleAABB(
            circleCenter: circle.center, radius: circle.radius,
            aabbCenter: aabb.center, width: aabb.width, height: aabb.height)
    }

    // MARK: - Circle vs Line Segment

    /// Returns `true` if a circle and a line segment overlap or touch.
    public static func circleLineSegment(
        center: Vec2, radius: Float, start: Vec2, end: Vec2
    ) -> Bool {
        let lineVector = end - start
        let pointLineVector = center - start

        let projectedLength = simd_dot(pointLineVector, simd_normalize(lineVector))

        let adjustedStartLength = projectedLength + radius
        let adjustedEndLength = projectedLength - radius

        if adjustedStartLength < 0 ||
            (adjustedEndLength * adjustedEndLength) > simd_length_squared(lineVector) {
            return false
        }

        let pointLineLengthSquared = simd_length_squared(pointLineVector)

        return (pointLineLengthSquared - (projectedLength * projectedLength)) < (radius * radius)
    }

    // MARK: - AABB vs AABB

    /// Returns `true` if two axis-aligned bounding boxes overlap or touch.
    public static func aabbAABB(
        center1: Vec2, width1: Float, height1: Float,
        center2: Vec2, width2: Float, height2: Float
    ) -> Bool {
        return pointAABB(
            point: center1, center: center2,
            width: width1 + width2, height: height1 + height2)
    }

    /// Returns `true` if two `AABB` instances overlap or touch.
    public static func aabbAABB(_ first: AABB, _ second: AABB) -> Bool {
        return aabbAABB(
            center1: first.center, width1: first.width, height1: first.height,
            center2: second.center, width2: second.width, height2: second.height)
    }
}
