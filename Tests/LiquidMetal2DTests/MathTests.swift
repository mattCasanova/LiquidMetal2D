import XCTest
import simd
@testable import LiquidMetal2D

// MARK: - Math Utility Tests

final class MathUtilityTests: XCTestCase {

    // MARK: Constants

    func testPiConstant() {
        XCTAssertTrue(isFloatEqual(pi, Float.pi))
    }

    func testPiOverTwo() {
        XCTAssertTrue(isFloatEqual(piOverTwo, Float.pi / 2))
    }

    func testTwoPi() {
        XCTAssertTrue(isFloatEqual(twoPi, Float.pi * 2))
    }

    // MARK: Degree/Radian Conversion

    func testRadianToDegree() {
        XCTAssertTrue(isFloatEqual(radianToDegree(pi), 180))
        XCTAssertTrue(isFloatEqual(radianToDegree(piOverTwo), 90))
        XCTAssertTrue(isFloatEqual(radianToDegree(0), 0))
        XCTAssertTrue(isFloatEqual(radianToDegree(twoPi), 360))
    }

    func testDegreeToRadian() {
        XCTAssertTrue(isFloatEqual(degreeToRadian(180), pi))
        XCTAssertTrue(isFloatEqual(degreeToRadian(90), piOverTwo))
        XCTAssertTrue(isFloatEqual(degreeToRadian(0), 0))
        XCTAssertTrue(isFloatEqual(degreeToRadian(360), twoPi))
    }

    func testRoundTripConversion() {
        let original: Float = 45.0
        XCTAssertTrue(isFloatEqual(radianToDegree(degreeToRadian(original)), original))
    }

    // MARK: Clamp

    func testClampWithinRange() {
        XCTAssertEqual(clamp(value: 5, low: 0, high: 10), 5)
    }

    func testClampBelowRange() {
        XCTAssertEqual(clamp(value: -5, low: 0, high: 10), 0)
    }

    func testClampAboveRange() {
        XCTAssertEqual(clamp(value: 15, low: 0, high: 10), 10)
    }

    func testClampAtBoundaries() {
        XCTAssertEqual(clamp(value: 0, low: 0, high: 10), 0)
        XCTAssertEqual(clamp(value: 10, low: 0, high: 10), 10)
    }

    // MARK: WrapEdge

    func testWrapEdgeWithinRange() {
        XCTAssertEqual(wrapEdge(value: 5, low: 0, high: 10), 5)
    }

    func testWrapEdgeBelowRange() {
        XCTAssertEqual(wrapEdge(value: -1, low: 0, high: 10), 10)
    }

    func testWrapEdgeAboveRange() {
        XCTAssertEqual(wrapEdge(value: 11, low: 0, high: 10), 0)
    }

    // MARK: Wrap

    func testWrapWithinRange() {
        XCTAssertEqual(wrap(value: 5, low: 0, high: 10), 5)
    }

    func testWrapAboveRange() {
        XCTAssertEqual(wrap(value: 12, low: 0, high: 10), 2)
    }

    func testWrapBelowRange() {
        XCTAssertEqual(wrap(value: -3, low: 0, high: 10), 7)
    }

    // These test the stack overflow risk — large values far outside range.
    // The recursive implementation handles small offsets fine, but truly huge values
    // could blow the stack. These values are large enough to stress-test it.
    func testWrapLargeValue() {
        let result = wrap(value: 1000, low: 0, high: 10)
        XCTAssertTrue(result >= 0 && result <= 10, "wrap(1000, 0, 10) should be in range, got \(result)")
    }

    func testWrapLargeNegativeValue() {
        let result = wrap(value: -1000, low: 0, high: 10)
        XCTAssertTrue(result >= 0 && result <= 10, "wrap(-1000, 0, 10) should be in range, got \(result)")
    }

    // This should produce the correct modular result, not just "in range"
    func testWrapExactResult() {
        // 13 wraps to 3 in range [0, 10]
        XCTAssertEqual(wrap(value: 13, low: 0, high: 10), 3)
        // -2 wraps to 8 in range [0, 10]
        XCTAssertEqual(wrap(value: -2, low: 0, high: 10), 8)
    }

    // Wrap with non-zero low bound
    func testWrapNonZeroLow() {
        // 25 in range [10, 20] should be 15
        XCTAssertEqual(wrap(value: 25, low: 10, high: 20), 15)
    }

    // Angle wrapping — common game use case
    func testWrapAngle() {
        let result = wrap(value: Float.pi * 3, low: 0, high: twoPi)
        XCTAssertTrue(isFloatEqual(result, Float.pi), "3π wrapped to [0, 2π] should be π, got \(result)")
    }

    // MARK: IsInRange

    func testIsInRangeInside() {
        XCTAssertTrue(isInRange(value: 5, low: 0, high: 10))
    }

    func testIsInRangeAtBoundaries() {
        XCTAssertTrue(isInRange(value: 0, low: 0, high: 10))
        XCTAssertTrue(isInRange(value: 10, low: 0, high: 10))
    }

    func testIsInRangeOutside() {
        XCTAssertFalse(isInRange(value: -1, low: 0, high: 10))
        XCTAssertFalse(isInRange(value: 11, low: 0, high: 10))
    }

    // MARK: IsFloatEqual

    func testIsFloatEqualSameValue() {
        XCTAssertTrue(isFloatEqual(1.0, 1.0))
    }

    func testIsFloatEqualWithinEpsilon() {
        XCTAssertTrue(isFloatEqual(1.0, 1.0 + epsilon * 0.5))
    }

    func testIsFloatEqualDifferentValues() {
        XCTAssertFalse(isFloatEqual(1.0, 2.0))
    }

    // MARK: Power of Two

    func testIsPowerOfTwo() {
        XCTAssertTrue(isPowerOfTwo(1))
        XCTAssertTrue(isPowerOfTwo(2))
        XCTAssertTrue(isPowerOfTwo(4))
        XCTAssertTrue(isPowerOfTwo(64))
        XCTAssertTrue(isPowerOfTwo(1024))
    }

    func testIsNotPowerOfTwo() {
        XCTAssertFalse(isPowerOfTwo(0))
        XCTAssertFalse(isPowerOfTwo(3))
        XCTAssertFalse(isPowerOfTwo(5))
        XCTAssertFalse(isPowerOfTwo(100))
        XCTAssertFalse(isPowerOfTwo(-4))
    }

    func testNextPowerOfTwoFromNonPower() {
        XCTAssertEqual(nextPowerOfTwo(3), 4)
        XCTAssertEqual(nextPowerOfTwo(5), 8)
        XCTAssertEqual(nextPowerOfTwo(100), 128)
    }

    // nextPowerOfTwo intentionally returns the NEXT power, even if input is already a power
    func testNextPowerOfTwoFromPower() {
        XCTAssertEqual(nextPowerOfTwo(1), 2)
        XCTAssertEqual(nextPowerOfTwo(4), 8)
        XCTAssertEqual(nextPowerOfTwo(64), 128)
    }
}

// MARK: - SIMD Float2 Extension Tests

final class SimdFloat2ExtensionTests: XCTestCase {

    func testAngle() {
        let right = simd_float2(1, 0)
        XCTAssertTrue(isFloatEqual(right.angle, 0))

        let up = simd_float2(0, 1)
        XCTAssertTrue(isFloatEqual(up.angle, piOverTwo))

        let left = simd_float2(-1, 0)
        XCTAssertTrue(isFloatEqual(left.angle, pi))
    }

    func testLength() {
        let v = simd_float2(3, 4)
        XCTAssertTrue(isFloatEqual(v.length, 5))
    }

    func testLengthSquared() {
        let v = simd_float2(3, 4)
        XCTAssertTrue(isFloatEqual(v.lengthSquared, 25))
    }

    func testNormalized() {
        let v = simd_float2(3, 4)
        let n = v.normalized
        XCTAssertTrue(isFloatEqual(n.length, 1.0))
        XCTAssertTrue(isFloatEqual(n.x, 0.6))
        XCTAssertTrue(isFloatEqual(n.y, 0.8))
    }

    func testInitFromAngle() {
        let v = simd_float2(angle: 0)
        XCTAssertTrue(isFloatEqual(v.x, 1))
        XCTAssertTrue(isFloatEqual(v.y, 0))

        let v90 = simd_float2(angle: piOverTwo)
        XCTAssertTrue(isFloatEqual(v90.x, 0))
        XCTAssertTrue(isFloatEqual(v90.y, 1))
    }

    func testCross() {
        let right = simd_float2(1, 0)
        let up = simd_float2(0, 1)

        // Up is counterclockwise from right → positive
        XCTAssertTrue(right.cross(up) > 0)
        // Right is clockwise from up → negative
        XCTAssertTrue(up.cross(right) < 0)
        // Parallel vectors → zero
        XCTAssertTrue(isFloatEqual(right.cross(right), 0))
    }

    func testTextureCoordinateAliases() {
        var v = simd_float2(0.5, 0.75)
        XCTAssertEqual(v.u, 0.5)
        XCTAssertEqual(v.v, 0.75)
        v.u = 0.1
        v.v = 0.9
        XCTAssertEqual(v.x, 0.1)
        XCTAssertEqual(v.y, 0.9)
    }

    func testTo3D() {
        let v = simd_float2(1, 2)
        let v3 = v.to3D(3)
        XCTAssertEqual(v3, simd_float3(1, 2, 3))
    }

    func testTo3DDefaultZ() {
        let v = simd_float2(1, 2)
        let v3 = v.to3D()
        XCTAssertEqual(v3, simd_float3(1, 2, 0))
    }

    func testEpsilonEqual() {
        let a = simd_float2(1, 2)
        let b = simd_float2(1, 2)
        let c = simd_float2(1, 3)
        XCTAssertTrue(simd_epsilon_equal(lhs: a, rhs: b))
        XCTAssertFalse(simd_epsilon_equal(lhs: a, rhs: c))
    }

    func testSet() {
        var v = simd_float2()
        v.set(5, 10)
        XCTAssertEqual(v.x, 5)
        XCTAssertEqual(v.y, 10)
    }

    func testSetAngle() {
        var v = simd_float2()
        v.set(angle: 0)
        XCTAssertTrue(isFloatEqual(v.x, 1))
        XCTAssertTrue(isFloatEqual(v.y, 0))
    }
}

// MARK: - SIMD Float3 Extension Tests

final class SimdFloat3ExtensionTests: XCTestCase {

    func testXYSwizzle() {
        let v = simd_float3(1, 2, 3)
        XCTAssertEqual(v.xy, simd_float2(1, 2))
    }

    func testLength() {
        let v = simd_float3(2, 3, 6)
        XCTAssertTrue(isFloatEqual(v.length, 7)) // 2² + 3² + 6² = 49 → √49 = 7
    }

    func testLengthSquared() {
        let v = simd_float3(2, 3, 6)
        XCTAssertTrue(isFloatEqual(v.lengthSquared, 49))
    }

    func testNormalized() {
        let v = simd_float3(0, 0, 5)
        let n = v.normalized
        XCTAssertTrue(isFloatEqual(n.z, 1.0))
        XCTAssertTrue(isFloatEqual(n.length, 1.0))
    }

    func testRGBAccess() {
        var v = simd_float3(0.1, 0.2, 0.3)
        XCTAssertEqual(v.r, 0.1)
        XCTAssertEqual(v.g, 0.2)
        XCTAssertEqual(v.b, 0.3)
        v.b = 0.9
        XCTAssertEqual(v.z, 0.9)
    }

    func testTo4D() {
        let v = simd_float3(1, 2, 3)
        XCTAssertEqual(v.to4D(4), simd_float4(1, 2, 3, 4))
    }

    func testTo4DDefaultW() {
        let v = simd_float3(1, 2, 3)
        XCTAssertEqual(v.to4D(), simd_float4(1, 2, 3, 0))
    }
}

// MARK: - SIMD Float4x4 Extension Tests

final class SimdFloat4x4ExtensionTests: XCTestCase {

    func testSetToZero() {
        var mtx = simd_float4x4(1)
        mtx.setToZero()
        for col in 0..<4 {
            for row in 0..<4 {
                XCTAssertEqual(mtx[col][row], 0)
            }
        }
    }

    func testSetDiagonal() {
        var mtx = simd_float4x4()
        mtx.setDiagonal(simd_float4(2, 3, 4, 5))
        XCTAssertEqual(mtx[0][0], 2)
        XCTAssertEqual(mtx[1][1], 3)
        XCTAssertEqual(mtx[2][2], 4)
        XCTAssertEqual(mtx[3][3], 5)
        // Off-diagonals should be zero
        XCTAssertEqual(mtx[0][1], 0)
        XCTAssertEqual(mtx[1][0], 0)
    }

    func testMakeScale2D() {
        let mtx = simd_float4x4.makeScale2D(simd_float2(2, 3))
        XCTAssertEqual(mtx[0][0], 2)
        XCTAssertEqual(mtx[1][1], 3)
        XCTAssertEqual(mtx[2][2], 1)
        XCTAssertEqual(mtx[3][3], 1)
    }

    func testMakeTranslate2D() {
        let mtx = simd_float4x4.makeTranslate2D(simd_float3(5, 10, 15))
        XCTAssertEqual(mtx[3][0], 5)
        XCTAssertEqual(mtx[3][1], 10)
        XCTAssertEqual(mtx[3][2], 15)
        XCTAssertEqual(mtx[3][3], 1)
        // Should be identity in upper-left 3x3
        XCTAssertEqual(mtx[0][0], 1)
        XCTAssertEqual(mtx[1][1], 1)
        XCTAssertEqual(mtx[2][2], 1)
    }

    func testMakeRotate2D() {
        // 90 degree rotation
        let mtx = simd_float4x4.makeRotate2D(piOverTwo)
        XCTAssertTrue(isFloatEqual(mtx[0][0], cos(piOverTwo)))
        XCTAssertTrue(isFloatEqual(mtx[0][1], sin(piOverTwo)))
        XCTAssertTrue(isFloatEqual(mtx[1][0], -sin(piOverTwo)))
        XCTAssertTrue(isFloatEqual(mtx[1][1], cos(piOverTwo)))
    }

    func testMakeRotate2DZeroAngle() {
        let mtx = simd_float4x4.makeRotate2D(0)
        // Should be identity-like
        XCTAssertTrue(isFloatEqual(mtx[0][0], 1))
        XCTAssertTrue(isFloatEqual(mtx[1][1], 1))
        XCTAssertTrue(isFloatEqual(mtx[0][1], 0))
        XCTAssertTrue(isFloatEqual(mtx[1][0], 0))
    }

    func testMakeTransform2D() {
        // Identity transform: scale 1, no rotation, no translation
        let mtx = simd_float4x4.makeTransform2D(
            scale: simd_float2(1, 1), angle: 0, translate: simd_float3(0, 0, 0))
        XCTAssertTrue(isFloatEqual(mtx[0][0], 1))
        XCTAssertTrue(isFloatEqual(mtx[1][1], 1))
        XCTAssertTrue(isFloatEqual(mtx[3][0], 0))
        XCTAssertTrue(isFloatEqual(mtx[3][1], 0))
    }

    func testMakeTransform2DWithTranslation() {
        let mtx = simd_float4x4.makeTransform2D(
            scale: simd_float2(1, 1), angle: 0, translate: simd_float3(5, 10, 0))
        XCTAssertTrue(isFloatEqual(mtx[3][0], 5))
        XCTAssertTrue(isFloatEqual(mtx[3][1], 10))
    }

    func testMakeTransform2DWithScale() {
        let mtx = simd_float4x4.makeTransform2D(
            scale: simd_float2(2, 3), angle: 0, translate: simd_float3(0, 0, 0))
        XCTAssertTrue(isFloatEqual(mtx[0][0], 2))
        XCTAssertTrue(isFloatEqual(mtx[1][1], 3))
    }

    func testMakeLookAt2D() {
        let mtx = simd_float4x4.makeLookAt2D(simd_float3(0, 0, 50))
        // Translation should only affect z
        XCTAssertEqual(mtx[3][0], 0)
        XCTAssertEqual(mtx[3][1], 0)
        XCTAssertEqual(mtx[3][2], -50)
        XCTAssertEqual(mtx[3][3], 1)
    }
}

// MARK: - Intersect Tests

final class IntersectTests: XCTestCase {

    // MARK: Point vs Circle

    func testPointInsideCircle() {
        XCTAssertTrue(Intersect.pointCircle(
            point: simd_float2(0, 0), circle: simd_float2(0, 0), radius: 1))
    }

    func testPointOnCircleEdge() {
        XCTAssertTrue(Intersect.pointCircle(
            point: simd_float2(1, 0), circle: simd_float2(0, 0), radius: 1))
    }

    func testPointOutsideCircle() {
        XCTAssertFalse(Intersect.pointCircle(
            point: simd_float2(2, 0), circle: simd_float2(0, 0), radius: 1))
    }

    func testPointOffsetCircle() {
        XCTAssertTrue(Intersect.pointCircle(
            point: simd_float2(5, 5), circle: simd_float2(5, 5.5), radius: 1))
    }

    // MARK: Point vs AABB

    func testPointInsideAABB() {
        XCTAssertTrue(Intersect.pointAABB(
            point: simd_float2(0, 0), center: simd_float2(0, 0), width: 2, height: 2))
    }

    func testPointOnAABBEdge() {
        XCTAssertTrue(Intersect.pointAABB(
            point: simd_float2(1, 0), center: simd_float2(0, 0), width: 2, height: 2))
    }

    func testPointOutsideAABB() {
        XCTAssertFalse(Intersect.pointAABB(
            point: simd_float2(2, 0), center: simd_float2(0, 0), width: 2, height: 2))
    }

    func testPointOffsetAABB() {
        XCTAssertTrue(Intersect.pointAABB(
            point: simd_float2(5.5, 5.5), center: simd_float2(5, 5), width: 2, height: 2))
    }

    // MARK: Point vs Line Segment

    func testPointOnLineSegment() {
        // Point at midpoint of horizontal line from (0,0) to (10,0)
        let result = Intersect.pointLineSegment(
            point: simd_float2(5, 0), start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertTrue(result, "Point at midpoint of line should intersect")
    }

    func testPointAtLineStart() {
        let result = Intersect.pointLineSegment(
            point: simd_float2(0, 0), start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertTrue(result, "Point at start of line should intersect")
    }

    func testPointOffLine() {
        let result = Intersect.pointLineSegment(
            point: simd_float2(5, 5), start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertFalse(result, "Point far from line should not intersect")
    }

    // This tests the potential bug — point beyond the end of the segment
    // but still on the infinite line. Should return false.
    func testPointBeyondLineEnd() {
        let result = Intersect.pointLineSegment(
            point: simd_float2(15, 0), start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertFalse(result, "Point beyond line end should not intersect")
    }

    // MARK: Circle vs Circle

    func testCirclesOverlapping() {
        XCTAssertTrue(Intersect.circleCircle(
            center1: simd_float2(0, 0), center2: simd_float2(1, 0), radius1: 1, radius2: 1))
    }

    func testCirclesTouching() {
        XCTAssertTrue(Intersect.circleCircle(
            center1: simd_float2(0, 0), center2: simd_float2(2, 0), radius1: 1, radius2: 1))
    }

    func testCirclesSeparated() {
        XCTAssertFalse(Intersect.circleCircle(
            center1: simd_float2(0, 0), center2: simd_float2(5, 0), radius1: 1, radius2: 1))
    }

    // MARK: Circle vs AABB

    func testCircleOverlappingAABB() {
        XCTAssertTrue(Intersect.circleAABB(
            circleCenter: simd_float2(1.5, 0), radius: 1,
            aabbCenter: simd_float2(0, 0), width: 2, height: 2))
    }

    func testCircleInsideAABB() {
        XCTAssertTrue(Intersect.circleAABB(
            circleCenter: simd_float2(0, 0), radius: 0.5,
            aabbCenter: simd_float2(0, 0), width: 2, height: 2))
    }

    func testCircleFarFromAABB() {
        XCTAssertFalse(Intersect.circleAABB(
            circleCenter: simd_float2(5, 0), radius: 1,
            aabbCenter: simd_float2(0, 0), width: 2, height: 2))
    }

    func testCircleAtAABBCorner() {
        // Circle just barely touching the corner of the AABB
        // Corner is at (1, 1), circle at (1.5, 1.5) with radius 1
        // Distance from corner = sqrt(0.5) ≈ 0.707 < 1
        XCTAssertTrue(Intersect.circleAABB(
            circleCenter: simd_float2(1.5, 1.5), radius: 1,
            aabbCenter: simd_float2(0, 0), width: 2, height: 2))
    }

    // MARK: Circle vs Line Segment

    func testCircleIntersectsLineSegment() {
        // Circle at origin with radius 1, line passing through
        XCTAssertTrue(Intersect.circleLineSegment(
            center: simd_float2(0, 0), radius: 1,
            start: simd_float2(-5, 0), end: simd_float2(5, 0)))
    }

    func testCircleMissesLineSegment() {
        // Circle at (0, 5), line along x-axis — far apart
        XCTAssertFalse(Intersect.circleLineSegment(
            center: simd_float2(0, 5), radius: 1,
            start: simd_float2(-5, 0), end: simd_float2(5, 0)))
    }

    // Edge case: circle near the end of the segment
    func testCircleAtLineSegmentEnd() {
        // Circle at (10, 0.5) with radius 1, line from (0,0) to (10,0)
        // The circle's center is 0.5 units from the endpoint — within radius
        let result = Intersect.circleLineSegment(
            center: simd_float2(10, 0.5), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertTrue(result, "Circle overlapping line segment endpoint should intersect")
    }

    // Edge case: circle just past the end of the segment
    func testCirclePastLineSegmentEnd() {
        // Circle at (12, 0) with radius 0.5, line from (0,0) to (10,0)
        // Circle is 2 units past the end, radius 0.5 — should NOT intersect
        let result = Intersect.circleLineSegment(
            center: simd_float2(12, 0), radius: 0.5,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertFalse(result, "Circle past line segment end should not intersect")
    }

    // Circle before the start of the segment
    func testCircleBeforeLineSegmentStart() {
        // Circle at (-2, 0) with radius 0.5, line from (0,0) to (10,0)
        let result = Intersect.circleLineSegment(
            center: simd_float2(-2, 0), radius: 0.5,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertFalse(result, "Circle before line segment start should not intersect")
    }

    // Circle overlapping the start point of the segment
    func testCircleOverlapsLineSegmentStart() {
        // Circle at (-0.5, 0) with radius 1, line from (0,0) to (10,0)
        // Circle center is 0.5 from start, radius 1 — should intersect
        let result = Intersect.circleLineSegment(
            center: simd_float2(-0.5, 0), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertTrue(result, "Circle overlapping line segment start should intersect")
    }

    // Circle perpendicular to line, close but not touching
    func testCirclePerpendicularNearMiss() {
        // Circle at (5, 1.5) with radius 1, line along x-axis
        // Perpendicular distance is 1.5, radius is 1 — should NOT intersect
        let result = Intersect.circleLineSegment(
            center: simd_float2(5, 1.5), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertFalse(result, "Circle near but not touching line should not intersect")
    }

    // Circle perpendicular to line, just touching
    func testCirclePerpendicularJustTouching() {
        // Circle at (5, 0.9) with radius 1, line along x-axis
        // Perpendicular distance is 0.9, radius is 1 — should intersect
        let result = Intersect.circleLineSegment(
            center: simd_float2(5, 0.9), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertTrue(result, "Circle just touching line should intersect")
    }

    // Diagonal line segment
    func testCircleIntersectsDiagonalLine() {
        // Line from (0,0) to (10,10), circle at (5,5) radius 1
        let result = Intersect.circleLineSegment(
            center: simd_float2(5, 5), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 10))
        XCTAssertTrue(result, "Circle on diagonal line should intersect")
    }

    // Circle at exact endpoint
    func testCircleCenteredOnLineEnd() {
        let result = Intersect.circleLineSegment(
            center: simd_float2(10, 0), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertTrue(result, "Circle centered on line endpoint should intersect")
    }

    // MARK: AABB vs AABB

    func testAABBsOverlapping() {
        XCTAssertTrue(Intersect.aabbAABB(
            center1: simd_float2(0, 0), width1: 2, height1: 2,
            center2: simd_float2(1, 0), width2: 2, height2: 2))
    }

    func testAABBsSeparated() {
        XCTAssertFalse(Intersect.aabbAABB(
            center1: simd_float2(0, 0), width1: 2, height1: 2,
            center2: simd_float2(5, 0), width2: 2, height2: 2))
    }

    func testAABBsTouching() {
        XCTAssertTrue(Intersect.aabbAABB(
            center1: simd_float2(0, 0), width1: 2, height1: 2,
            center2: simd_float2(2, 0), width2: 2, height2: 2))
    }
}
