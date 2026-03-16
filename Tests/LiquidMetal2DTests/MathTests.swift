import XCTest
import simd
@testable import LiquidMetal2D

// MARK: - Math Utility Tests

final class MathUtilityTests: XCTestCase {

    // MARK: Constants

    func testPiConstant() {
        XCTAssertEqual(GameMath.pi, Float.pi)
    }

    func testPiOverTwo() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.piOverTwo, Float.pi / 2))
    }

    func testTwoPi() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.twoPi, Float.pi * 2))
    }

    // MARK: Degree/Radian Conversion

    func testRadianToDegree() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.radianToDegree(GameMath.pi), 180))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.radianToDegree(GameMath.piOverTwo), 90))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.radianToDegree(0), 0))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.radianToDegree(GameMath.twoPi), 360))
    }

    func testDegreeToRadian() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.degreeToRadian(180), GameMath.pi))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.degreeToRadian(90), GameMath.piOverTwo))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.degreeToRadian(0), 0))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.degreeToRadian(360), GameMath.twoPi))
    }

    func testRoundTripConversion() {
        let original: Float = 45.0
        XCTAssertTrue(GameMath.isFloatEqual(
            GameMath.radianToDegree(GameMath.degreeToRadian(original)), original))
    }

    // MARK: Clamp (generic)

    func testClampWithinRange() {
        XCTAssertEqual(GameMath.clamp(value: 5, low: 0, high: 10), 5)
    }

    func testClampBelowRange() {
        XCTAssertEqual(GameMath.clamp(value: -5, low: 0, high: 10), 0)
    }

    func testClampAboveRange() {
        XCTAssertEqual(GameMath.clamp(value: 15, low: 0, high: 10), 10)
    }

    func testClampAtBoundaries() {
        XCTAssertEqual(GameMath.clamp(value: 0, low: 0, high: 10), 0)
        XCTAssertEqual(GameMath.clamp(value: 10, low: 0, high: 10), 10)
    }

    // MARK: Clamp (SIMD)

    func testClampSimdFloat2() {
        let value = simd_float2(-1, 5)
        let result = GameMath.clamp(
            value: value, low: simd_float2(0, 0), high: simd_float2(3, 3))
        XCTAssertEqual(result.x, 0)
        XCTAssertEqual(result.y, 3)
    }

    func testClampSimdFloat3() {
        let value = simd_float3(-1, 2, 10)
        let result = GameMath.clamp(
            value: value, low: simd_float3(0, 0, 0), high: simd_float3(5, 5, 5))
        XCTAssertEqual(result.x, 0)
        XCTAssertEqual(result.y, 2)
        XCTAssertEqual(result.z, 5)
    }

    // MARK: WrapEdge

    func testWrapEdgeWithinRange() {
        XCTAssertEqual(GameMath.wrapEdge(value: 5, low: 0, high: 10), 5)
    }

    func testWrapEdgeBelowRange() {
        XCTAssertEqual(GameMath.wrapEdge(value: -1, low: 0, high: 10), 10)
    }

    func testWrapEdgeAboveRange() {
        XCTAssertEqual(GameMath.wrapEdge(value: 11, low: 0, high: 10), 0)
    }

    func testWrapEdgeWithFloat() {
        XCTAssertEqual(GameMath.wrapEdge(value: -0.1, low: Float(0), high: Float(1)), Float(1))
        XCTAssertEqual(GameMath.wrapEdge(value: 1.1, low: Float(0), high: Float(1)), Float(0))
    }

    // MARK: Wrap

    func testWrapWithinRange() {
        XCTAssertEqual(GameMath.wrap(value: 5, low: 0, high: 10), 5)
    }

    func testWrapAboveRange() {
        XCTAssertEqual(GameMath.wrap(value: 12, low: 0, high: 10), 2)
    }

    func testWrapBelowRange() {
        XCTAssertEqual(GameMath.wrap(value: -3, low: 0, high: 10), 7)
    }

    func testWrapLargeValue() {
        let result = GameMath.wrap(value: 1000, low: 0, high: 10)
        XCTAssertTrue(result >= 0 && result <= 10, "wrap(1000, 0, 10) should be in range, got \(result)")
    }

    func testWrapLargeNegativeValue() {
        let result = GameMath.wrap(value: -1000, low: 0, high: 10)
        XCTAssertTrue(result >= 0 && result <= 10, "wrap(-1000, 0, 10) should be in range, got \(result)")
    }

    func testWrapExactResult() {
        XCTAssertEqual(GameMath.wrap(value: 13, low: 0, high: 10), 3)
        XCTAssertEqual(GameMath.wrap(value: -2, low: 0, high: 10), 8)
    }

    func testWrapNonZeroLow() {
        XCTAssertEqual(GameMath.wrap(value: 25, low: 10, high: 20), 15)
    }

    func testWrapAngle() {
        let result = GameMath.wrap(value: Float.pi * 3, low: 0, high: GameMath.twoPi)
        XCTAssertTrue(GameMath.isFloatEqual(result, Float.pi),
                      "3π wrapped to [0, 2π] should be π, got \(result)")
    }

    // MARK: IsInRange

    func testIsInRangeInside() {
        XCTAssertTrue(GameMath.isInRange(value: 5, low: 0, high: 10))
    }

    func testIsInRangeAtBoundaries() {
        XCTAssertTrue(GameMath.isInRange(value: 0, low: 0, high: 10))
        XCTAssertTrue(GameMath.isInRange(value: 10, low: 0, high: 10))
    }

    func testIsInRangeOutside() {
        XCTAssertFalse(GameMath.isInRange(value: -1, low: 0, high: 10))
        XCTAssertFalse(GameMath.isInRange(value: 11, low: 0, high: 10))
    }

    // MARK: IsFloatEqual

    func testIsFloatEqualSameValue() {
        XCTAssertTrue(GameMath.isFloatEqual(1.0, 1.0))
    }

    func testIsFloatEqualWithinEpsilon() {
        XCTAssertTrue(GameMath.isFloatEqual(1.0, 1.0 + GameMath.epsilon * 0.5))
    }

    func testIsFloatEqualDifferentValues() {
        XCTAssertFalse(GameMath.isFloatEqual(1.0, 2.0))
    }

    // MARK: Power of Two

    func testIsPowerOfTwo() {
        XCTAssertTrue(GameMath.isPowerOfTwo(1))
        XCTAssertTrue(GameMath.isPowerOfTwo(2))
        XCTAssertTrue(GameMath.isPowerOfTwo(4))
        XCTAssertTrue(GameMath.isPowerOfTwo(64))
        XCTAssertTrue(GameMath.isPowerOfTwo(1024))
    }

    func testIsNotPowerOfTwo() {
        XCTAssertFalse(GameMath.isPowerOfTwo(0))
        XCTAssertFalse(GameMath.isPowerOfTwo(3))
        XCTAssertFalse(GameMath.isPowerOfTwo(5))
        XCTAssertFalse(GameMath.isPowerOfTwo(100))
        XCTAssertFalse(GameMath.isPowerOfTwo(-4))
    }

    func testNextPowerOfTwoFromNonPower() {
        XCTAssertEqual(GameMath.nextPowerOfTwo(3), 4)
        XCTAssertEqual(GameMath.nextPowerOfTwo(5), 8)
        XCTAssertEqual(GameMath.nextPowerOfTwo(100), 128)
    }

    // nextPowerOfTwo intentionally returns the NEXT power, even if input is already a power
    func testNextPowerOfTwoFromPower() {
        XCTAssertEqual(GameMath.nextPowerOfTwo(1), 2)
        XCTAssertEqual(GameMath.nextPowerOfTwo(4), 8)
        XCTAssertEqual(GameMath.nextPowerOfTwo(64), 128)
    }
}

// MARK: - SIMD Float2 Extension Tests

final class SimdFloat2ExtensionTests: XCTestCase {

    func testAngle() {
        let right = simd_float2(1, 0)
        XCTAssertTrue(GameMath.isFloatEqual(right.angle, 0))

        let up = simd_float2(0, 1)
        XCTAssertTrue(GameMath.isFloatEqual(up.angle, GameMath.piOverTwo))

        let left = simd_float2(-1, 0)
        XCTAssertTrue(GameMath.isFloatEqual(left.angle, GameMath.pi))
    }

    func testLength() {
        let v = simd_float2(3, 4)
        XCTAssertTrue(GameMath.isFloatEqual(v.length, 5))
    }

    func testLengthSquared() {
        let v = simd_float2(3, 4)
        XCTAssertTrue(GameMath.isFloatEqual(v.lengthSquared, 25))
    }

    func testNormalized() {
        let v = simd_float2(3, 4)
        let n = v.normalized
        XCTAssertTrue(GameMath.isFloatEqual(n.length, 1.0))
        XCTAssertTrue(GameMath.isFloatEqual(n.x, 0.6))
        XCTAssertTrue(GameMath.isFloatEqual(n.y, 0.8))
    }

    func testInitFromAngle() {
        let v = simd_float2(angle: 0)
        XCTAssertTrue(GameMath.isFloatEqual(v.x, 1))
        XCTAssertTrue(GameMath.isFloatEqual(v.y, 0))

        let v90 = simd_float2(angle: GameMath.piOverTwo)
        XCTAssertTrue(GameMath.isFloatEqual(v90.x, 0))
        XCTAssertTrue(GameMath.isFloatEqual(v90.y, 1))
    }

    func testCross() {
        let right = simd_float2(1, 0)
        let up = simd_float2(0, 1)

        XCTAssertTrue(right.cross(up) > 0)
        XCTAssertTrue(up.cross(right) < 0)
        XCTAssertTrue(GameMath.isFloatEqual(right.cross(right), 0))
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
        XCTAssertEqual(v.to3D(3), simd_float3(1, 2, 3))
    }

    func testTo3DDefaultZ() {
        let v = simd_float2(1, 2)
        XCTAssertEqual(v.to3D(), simd_float3(1, 2, 0))
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
        XCTAssertTrue(GameMath.isFloatEqual(v.x, 1))
        XCTAssertTrue(GameMath.isFloatEqual(v.y, 0))
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
        XCTAssertTrue(GameMath.isFloatEqual(v.length, 7))
    }

    func testLengthSquared() {
        let v = simd_float3(2, 3, 6)
        XCTAssertTrue(GameMath.isFloatEqual(v.lengthSquared, 49))
    }

    func testNormalized() {
        let v = simd_float3(0, 0, 5)
        let n = v.normalized
        XCTAssertTrue(GameMath.isFloatEqual(n.z, 1.0))
        XCTAssertTrue(GameMath.isFloatEqual(n.length, 1.0))
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

    func testEpsilonEqual3() {
        let a = simd_float3(1, 2, 3)
        let b = simd_float3(1, 2, 3)
        let c = simd_float3(1, 2, 4)
        XCTAssertTrue(simd_epsilon_equal(lhs: a, rhs: b))
        XCTAssertFalse(simd_epsilon_equal(lhs: a, rhs: c))
    }
}

// MARK: - SIMD Float4 Extension Tests

final class SimdFloat4ExtensionTests: XCTestCase {

    func testXYZSwizzle() {
        let v = simd_float4(1, 2, 3, 4)
        XCTAssertEqual(v.xyz, simd_float3(1, 2, 3))
    }

    func testRGBSwizzle() {
        let v = simd_float4(0.1, 0.2, 0.3, 0.4)
        XCTAssertEqual(v.rgb, simd_float3(0.1, 0.2, 0.3))
    }

    func testRGBAAccess() {
        var v = simd_float4(0.1, 0.2, 0.3, 0.4)
        XCTAssertEqual(v.r, 0.1)
        XCTAssertEqual(v.g, 0.2)
        XCTAssertEqual(v.b, 0.3)
        XCTAssertEqual(v.a, 0.4)
        v.a = 1.0
        XCTAssertEqual(v.w, 1.0)
    }

    func testTexTransAliases() {
        var v = simd_float4(1, 2, 3, 4)
        XCTAssertEqual(v.sx, 1)
        XCTAssertEqual(v.su, 2)
        XCTAssertEqual(v.tx, 3)
        XCTAssertEqual(v.ty, 4)
        v.sx = 10
        XCTAssertEqual(v.x, 10)
    }

    func testSet4() {
        var v = simd_float4()
        v.set(1, 2, 3, 4)
        XCTAssertEqual(v, simd_float4(1, 2, 3, 4))
    }

    func testSetRGBA() {
        var v = simd_float4()
        v.set(r: 0.1, g: 0.2, b: 0.3, a: 1.0)
        XCTAssertEqual(v.x, 0.1)
        XCTAssertEqual(v.w, 1.0)
    }

    func testSetRepeating() {
        var v = simd_float4()
        v.set(repeating: 5)
        XCTAssertEqual(v, simd_float4(5, 5, 5, 5))
    }

    func testEpsilonEqual4() {
        let a = simd_float4(1, 2, 3, 4)
        let b = simd_float4(1, 2, 3, 4)
        let c = simd_float4(1, 2, 3, 5)
        XCTAssertTrue(simd_epsilon_equal(lhs: a, rhs: b))
        XCTAssertFalse(simd_epsilon_equal(lhs: a, rhs: c))
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
        XCTAssertEqual(mtx[0][0], 1)
        XCTAssertEqual(mtx[1][1], 1)
        XCTAssertEqual(mtx[2][2], 1)
    }

    func testMakeRotate2D() {
        let mtx = simd_float4x4.makeRotate2D(GameMath.piOverTwo)
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][0], cos(GameMath.piOverTwo)))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][1], sin(GameMath.piOverTwo)))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][0], -sin(GameMath.piOverTwo)))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][1], cos(GameMath.piOverTwo)))
    }

    func testMakeRotate2DZeroAngle() {
        let mtx = simd_float4x4.makeRotate2D(0)
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][0], 1))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][1], 1))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][1], 0))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][0], 0))
    }

    func testMakeTransform2DIdentity() {
        let mtx = simd_float4x4.makeTransform2D(
            scale: simd_float2(1, 1), angle: 0, translate: simd_float3(0, 0, 0))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][0], 1))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][1], 1))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[3][0], 0))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[3][1], 0))
    }

    func testMakeTransform2DWithTranslation() {
        let mtx = simd_float4x4.makeTransform2D(
            scale: simd_float2(1, 1), angle: 0, translate: simd_float3(5, 10, 0))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[3][0], 5))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[3][1], 10))
    }

    func testMakeTransform2DWithScale() {
        let mtx = simd_float4x4.makeTransform2D(
            scale: simd_float2(2, 3), angle: 0, translate: simd_float3(0, 0, 0))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][0], 2))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][1], 3))
    }

    func testMakeLookAt2D() {
        let mtx = simd_float4x4.makeLookAt2D(simd_float3(0, 0, 50))
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

    // MARK: Point vs Circle (protocol overload)

    func testPointCircleWithProtocol() {
        let obj = GameObj()
        let collider = CircleCollider(obj: obj, radius: 2)
        XCTAssertTrue(Intersect.pointCircle(point: simd_float2(0, 0), circle: collider))
        XCTAssertFalse(Intersect.pointCircle(point: simd_float2(5, 5), circle: collider))
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

    // MARK: Circle vs Circle (protocol overload)

    func testCircleCircleWithProtocol() {
        let obj1 = GameObj()
        let obj2 = GameObj()
        obj2.position.set(1, 0)
        let c1 = CircleCollider(obj: obj1, radius: 1)
        let c2 = CircleCollider(obj: obj2, radius: 1)
        XCTAssertTrue(Intersect.circleCircle(c1, c2))
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
        XCTAssertTrue(Intersect.circleAABB(
            circleCenter: simd_float2(1.5, 1.5), radius: 1,
            aabbCenter: simd_float2(0, 0), width: 2, height: 2))
    }

    // MARK: Circle vs Line Segment

    func testCircleIntersectsLineSegment() {
        XCTAssertTrue(Intersect.circleLineSegment(
            center: simd_float2(0, 0), radius: 1,
            start: simd_float2(-5, 0), end: simd_float2(5, 0)))
    }

    func testCircleMissesLineSegment() {
        XCTAssertFalse(Intersect.circleLineSegment(
            center: simd_float2(0, 5), radius: 1,
            start: simd_float2(-5, 0), end: simd_float2(5, 0)))
    }

    func testCircleAtLineSegmentEnd() {
        let result = Intersect.circleLineSegment(
            center: simd_float2(10, 0.5), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertTrue(result, "Circle overlapping line segment endpoint should intersect")
    }

    func testCirclePastLineSegmentEnd() {
        let result = Intersect.circleLineSegment(
            center: simd_float2(12, 0), radius: 0.5,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertFalse(result, "Circle past line segment end should not intersect")
    }

    func testCircleBeforeLineSegmentStart() {
        let result = Intersect.circleLineSegment(
            center: simd_float2(-2, 0), radius: 0.5,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertFalse(result, "Circle before line segment start should not intersect")
    }

    func testCircleOverlapsLineSegmentStart() {
        let result = Intersect.circleLineSegment(
            center: simd_float2(-0.5, 0), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertTrue(result, "Circle overlapping line segment start should intersect")
    }

    func testCirclePerpendicularNearMiss() {
        let result = Intersect.circleLineSegment(
            center: simd_float2(5, 1.5), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertFalse(result, "Circle near but not touching line should not intersect")
    }

    func testCirclePerpendicularJustTouching() {
        let result = Intersect.circleLineSegment(
            center: simd_float2(5, 0.9), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 0))
        XCTAssertTrue(result, "Circle just touching line should intersect")
    }

    func testCircleIntersectsDiagonalLine() {
        let result = Intersect.circleLineSegment(
            center: simd_float2(5, 5), radius: 1,
            start: simd_float2(0, 0), end: simd_float2(10, 10))
        XCTAssertTrue(result, "Circle on diagonal line should intersect")
    }

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

// MARK: - MutableCircle / CircleCollider Tests

final class CircleColliderTests: XCTestCase {

    func testCircleColliderTracksGameObj() {
        let obj = GameObj()
        obj.position.set(5, 10)
        let collider = CircleCollider(obj: obj, radius: 2)

        // center should reflect obj position
        XCTAssertEqual(collider.center.x, 5)
        XCTAssertEqual(collider.center.y, 10)

        // moving obj should move collider center
        obj.position.set(20, 30)
        XCTAssertEqual(collider.center.x, 20)
        XCTAssertEqual(collider.center.y, 30)
    }

    func testCircleColliderCenterSetUpdatesObj() {
        let obj = GameObj()
        let collider = CircleCollider(obj: obj, radius: 1)

        collider.center = simd_float2(7, 8)
        XCTAssertEqual(obj.position.x, 7)
        XCTAssertEqual(obj.position.y, 8)
    }

    func testCircleColliderRadius() {
        let obj = GameObj()
        let collider = CircleCollider(obj: obj, radius: 3)
        XCTAssertEqual(collider.radius, 3)
        collider.radius = 5
        XCTAssertEqual(collider.radius, 5)
    }
}
