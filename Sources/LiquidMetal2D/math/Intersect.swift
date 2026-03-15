//
//  Intersect.swift
//
//
//  Created by Matt Casanova on 4/4/20.
//

import simd

/// Namespace for 2D intersection/collision tests.
/// Uses an enum instead of a class to prevent accidental instantiation.
public enum Intersect {
    public static func pointCircle(point: simd_float2, circle: simd_float2, radius: Float) -> Bool {
        return simd_length_squared(point - circle) - (radius * radius) < epsilon
    }

    public static func pointCircle(point: simd_float2, circle: Circle) -> Bool {
        return simd_length_squared(point - circle.center) - (circle.radius * circle.radius) < epsilon
    }

    public static func pointAABB(point: simd_float2, center: simd_float2, width: Float, height: Float) -> Bool {
        let halfWidth = width / 2
        let halfHeight = height / 2

        // Move point into AABB space, ie, treat aabb as if it were at the origin
        let adjustedPoint = point - center

        // If the new point is inside the rect, it is intersecting
        return isInRange(value: adjustedPoint.x, low: -halfWidth, high: halfWidth) &&
            isInRange(value: adjustedPoint.y, low: -halfHeight, high: halfHeight)
    }

    public static func pointLineSegment(point: simd_float2, start: simd_float2, end: simd_float2) -> Bool {
        let lineVector = end - start
        let pointLineVector = point - start

        // If the sin of the angle between the two vectors in greater than zero, the point isn't on the line
        if abs(lineVector.cross(pointLineVector)) > epsilon {
            return false
        }

        let projectedLength = simd_dot(pointLineVector, simd_normalize(lineVector))
        return isInRange(value: projectedLength * projectedLength, low: 0, high: simd_length_squared(lineVector))
    }

    public static func circleCircle(
        center1: simd_float2, center2: simd_float2, radius1: Float, radius2: Float
    ) -> Bool {
        let radius = radius1 + radius2
        return simd_length_squared(center1 - center2) - (radius * radius) < epsilon
    }

    public static func circleCircle(_ first: Circle, _ second: Circle) -> Bool {
        let radius = first.radius + second.radius
        return simd_length_squared(first.center - second.center) - (radius * radius) < epsilon
    }

    public static func circleAABB(
        circleCenter: simd_float2, radius: Float, aabbCenter: simd_float2, width: Float, height: Float
    ) -> Bool {
        let halfWidth = width / 2
        let halfHeight = height / 2

        let adjustedPoint = circleCenter - aabbCenter

        let closestPoint = simd_clamp(
            adjustedPoint,
            simd_float2(-halfWidth, -halfHeight),
            simd_float2(halfWidth, halfHeight))

        if isInRange(value: adjustedPoint.x, low: -halfWidth, high: halfWidth) &&
            isInRange(value: adjustedPoint.y, low: -halfHeight, high: halfHeight) {
            return true
        }

        return simd_length_squared(adjustedPoint - closestPoint) < (radius * radius)
    }

    public static func circleLineSegment(
        center: simd_float2, radius: Float, start: simd_float2, end: simd_float2
    ) -> Bool {
        let lineVector = end - start
        let pointLineVector = center - start

        let projectedLength = simd_dot(pointLineVector, simd_normalize(lineVector))

        let adjustedStartLength = projectedLength + radius
        let adjustedEndLength = projectedLength - radius

        if adjustedStartLength < 0 || (adjustedEndLength * adjustedEndLength) > simd_length_squared(lineVector) {
            return false
        }

        let pointLineLengthSquared = simd_length_squared(pointLineVector)

        // Use pythagorean theorem to get length of third side and compare with radius
        return (pointLineLengthSquared - (projectedLength * projectedLength)) < (radius * radius)
    }

    // swiftlint:disable:next function_parameter_count
    public static func aabbAABB(
        center1: simd_float2, width1: Float, height1: Float,
        center2: simd_float2, width2: Float, height2: Float
    ) -> Bool {
        return Intersect.pointAABB(point: center1, center: center2, width: width1 + width2, height: height1 + height2)
    }
}
