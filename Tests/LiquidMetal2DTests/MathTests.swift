import XCTest
@testable import LiquidMetal2D

// MARK: - Test Helpers

private struct TestAABB: AABB {
    var center: Vec2
    var width: Float
    var height: Float
}

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
        let value = Vec2(-1, 5)
        let result = GameMath.clamp(
            value: value, low: Vec2(0, 0), high: Vec2(3, 3))
        XCTAssertEqual(result.x, 0)
        XCTAssertEqual(result.y, 3)
    }

    func testClampSimdFloat3() {
        let value = Vec3(-1, 2, 10)
        let result = GameMath.clamp(
            value: value, low: Vec3(0, 0, 0), high: Vec3(5, 5, 5))
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
        let right = Vec2(1, 0)
        XCTAssertTrue(GameMath.isFloatEqual(right.angle, 0))

        let up = Vec2(0, 1)
        XCTAssertTrue(GameMath.isFloatEqual(up.angle, GameMath.piOverTwo))

        let left = Vec2(-1, 0)
        XCTAssertTrue(GameMath.isFloatEqual(left.angle, GameMath.pi))
    }

    func testLength() {
        let v = Vec2(3, 4)
        XCTAssertTrue(GameMath.isFloatEqual(v.length, 5))
    }

    func testLengthSquared() {
        let v = Vec2(3, 4)
        XCTAssertTrue(GameMath.isFloatEqual(v.lengthSquared, 25))
    }

    func testNormalized() {
        let v = Vec2(3, 4)
        let n = v.normalized
        XCTAssertTrue(GameMath.isFloatEqual(n.length, 1.0))
        XCTAssertTrue(GameMath.isFloatEqual(n.x, 0.6))
        XCTAssertTrue(GameMath.isFloatEqual(n.y, 0.8))
    }

    func testInitFromAngle() {
        let v = Vec2(angle: 0)
        XCTAssertTrue(GameMath.isFloatEqual(v.x, 1))
        XCTAssertTrue(GameMath.isFloatEqual(v.y, 0))

        let v90 = Vec2(angle: GameMath.piOverTwo)
        XCTAssertTrue(GameMath.isFloatEqual(v90.x, 0))
        XCTAssertTrue(GameMath.isFloatEqual(v90.y, 1))
    }

    func testCross() {
        let right = Vec2(1, 0)
        let up = Vec2(0, 1)

        XCTAssertTrue(right.cross(up) > 0)
        XCTAssertTrue(up.cross(right) < 0)
        XCTAssertTrue(GameMath.isFloatEqual(right.cross(right), 0))
    }

    func testTextureCoordinateAliases() {
        var v = Vec2(0.5, 0.75)
        XCTAssertEqual(v.u, 0.5)
        XCTAssertEqual(v.v, 0.75)
        v.u = 0.1
        v.v = 0.9
        XCTAssertEqual(v.x, 0.1)
        XCTAssertEqual(v.y, 0.9)
    }

    func testTo3D() {
        let v = Vec2(1, 2)
        XCTAssertEqual(v.to3D(3), Vec3(1, 2, 3))
    }

    func testTo3DDefaultZ() {
        let v = Vec2(1, 2)
        XCTAssertEqual(v.to3D(), Vec3(1, 2, 0))
    }

    func testEpsilonEqual() {
        let a = Vec2(1, 2)
        let b = Vec2(1, 2)
        let c = Vec2(1, 3)
        XCTAssertTrue(simd_epsilon_equal(lhs: a, rhs: b))
        XCTAssertFalse(simd_epsilon_equal(lhs: a, rhs: c))
    }

    func testSet() {
        var v = Vec2()
        v.set(5, 10)
        XCTAssertEqual(v.x, 5)
        XCTAssertEqual(v.y, 10)
    }

    func testSetAngle() {
        var v = Vec2()
        v.set(angle: 0)
        XCTAssertTrue(GameMath.isFloatEqual(v.x, 1))
        XCTAssertTrue(GameMath.isFloatEqual(v.y, 0))
    }
}

// MARK: - SIMD Float3 Extension Tests

final class SimdFloat3ExtensionTests: XCTestCase {

    func testXYSwizzle() {
        let v = Vec3(1, 2, 3)
        XCTAssertEqual(v.xy, Vec2(1, 2))
    }

    func testLength() {
        let v = Vec3(2, 3, 6)
        XCTAssertTrue(GameMath.isFloatEqual(v.length, 7))
    }

    func testLengthSquared() {
        let v = Vec3(2, 3, 6)
        XCTAssertTrue(GameMath.isFloatEqual(v.lengthSquared, 49))
    }

    func testNormalized() {
        let v = Vec3(0, 0, 5)
        let n = v.normalized
        XCTAssertTrue(GameMath.isFloatEqual(n.z, 1.0))
        XCTAssertTrue(GameMath.isFloatEqual(n.length, 1.0))
    }

    func testRGBAccess() {
        var v = Vec3(0.1, 0.2, 0.3)
        XCTAssertEqual(v.r, 0.1)
        XCTAssertEqual(v.g, 0.2)
        XCTAssertEqual(v.b, 0.3)
        v.b = 0.9
        XCTAssertEqual(v.z, 0.9)
    }

    func testTo4D() {
        let v = Vec3(1, 2, 3)
        XCTAssertEqual(v.to4D(4), Vec4(1, 2, 3, 4))
    }

    func testTo4DDefaultW() {
        let v = Vec3(1, 2, 3)
        XCTAssertEqual(v.to4D(), Vec4(1, 2, 3, 0))
    }

    func testEpsilonEqual3() {
        let a = Vec3(1, 2, 3)
        let b = Vec3(1, 2, 3)
        let c = Vec3(1, 2, 4)
        XCTAssertTrue(simd_epsilon_equal(lhs: a, rhs: b))
        XCTAssertFalse(simd_epsilon_equal(lhs: a, rhs: c))
    }
}

// MARK: - SIMD Float4 Extension Tests

final class SimdFloat4ExtensionTests: XCTestCase {

    func testXYZSwizzle() {
        let v = Vec4(1, 2, 3, 4)
        XCTAssertEqual(v.xyz, Vec3(1, 2, 3))
    }

    func testRGBSwizzle() {
        let v = Vec4(0.1, 0.2, 0.3, 0.4)
        XCTAssertEqual(v.rgb, Vec3(0.1, 0.2, 0.3))
    }

    func testRGBAAccess() {
        var v = Vec4(0.1, 0.2, 0.3, 0.4)
        XCTAssertEqual(v.r, 0.1)
        XCTAssertEqual(v.g, 0.2)
        XCTAssertEqual(v.b, 0.3)
        XCTAssertEqual(v.a, 0.4)
        v.a = 1.0
        XCTAssertEqual(v.w, 1.0)
    }

    func testTexTransAliases() {
        var v = Vec4(1, 2, 3, 4)
        XCTAssertEqual(v.sx, 1)
        XCTAssertEqual(v.su, 2)
        XCTAssertEqual(v.tx, 3)
        XCTAssertEqual(v.ty, 4)
        v.sx = 10
        XCTAssertEqual(v.x, 10)
    }

    func testSet4() {
        var v = Vec4()
        v.set(1, 2, 3, 4)
        XCTAssertEqual(v, Vec4(1, 2, 3, 4))
    }

    func testSetRGBA() {
        var v = Vec4()
        v.set(r: 0.1, g: 0.2, b: 0.3, a: 1.0)
        XCTAssertEqual(v.x, 0.1)
        XCTAssertEqual(v.w, 1.0)
    }

    func testSetRepeating() {
        var v = Vec4()
        v.set(repeating: 5)
        XCTAssertEqual(v, Vec4(5, 5, 5, 5))
    }

    func testEpsilonEqual4() {
        let a = Vec4(1, 2, 3, 4)
        let b = Vec4(1, 2, 3, 4)
        let c = Vec4(1, 2, 3, 5)
        XCTAssertTrue(simd_epsilon_equal(lhs: a, rhs: b))
        XCTAssertFalse(simd_epsilon_equal(lhs: a, rhs: c))
    }
}

// MARK: - SIMD Float4x4 Extension Tests

final class SimdFloat4x4ExtensionTests: XCTestCase {

    func testSetToZero() {
        var mtx = Mat4(1)
        mtx.setToZero()
        for col in 0..<4 {
            for row in 0..<4 {
                XCTAssertEqual(mtx[col][row], 0)
            }
        }
    }

    func testSetDiagonal() {
        var mtx = Mat4()
        mtx.setDiagonal(Vec4(2, 3, 4, 5))
        XCTAssertEqual(mtx[0][0], 2)
        XCTAssertEqual(mtx[1][1], 3)
        XCTAssertEqual(mtx[2][2], 4)
        XCTAssertEqual(mtx[3][3], 5)
        XCTAssertEqual(mtx[0][1], 0)
        XCTAssertEqual(mtx[1][0], 0)
    }

    func testMakeScale2D() {
        let mtx = Mat4.makeScale2D(Vec2(2, 3))
        XCTAssertEqual(mtx[0][0], 2)
        XCTAssertEqual(mtx[1][1], 3)
        XCTAssertEqual(mtx[2][2], 1)
        XCTAssertEqual(mtx[3][3], 1)
    }

    func testMakeTranslate2D() {
        let mtx = Mat4.makeTranslate2D(Vec3(5, 10, 15))
        XCTAssertEqual(mtx[3][0], 5)
        XCTAssertEqual(mtx[3][1], 10)
        XCTAssertEqual(mtx[3][2], 15)
        XCTAssertEqual(mtx[3][3], 1)
        XCTAssertEqual(mtx[0][0], 1)
        XCTAssertEqual(mtx[1][1], 1)
        XCTAssertEqual(mtx[2][2], 1)
    }

    func testMakeRotate2D() {
        let mtx = Mat4.makeRotate2D(GameMath.piOverTwo)
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][0], cos(GameMath.piOverTwo)))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][1], sin(GameMath.piOverTwo)))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][0], -sin(GameMath.piOverTwo)))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][1], cos(GameMath.piOverTwo)))
    }

    func testMakeRotate2DZeroAngle() {
        let mtx = Mat4.makeRotate2D(0)
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][0], 1))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][1], 1))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][1], 0))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][0], 0))
    }

    func testMakeTransform2DIdentity() {
        let mtx = Mat4.makeTransform2D(
            scale: Vec2(1, 1), angle: 0, translate: Vec3(0, 0, 0))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][0], 1))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][1], 1))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[3][0], 0))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[3][1], 0))
    }

    func testMakeTransform2DWithTranslation() {
        let mtx = Mat4.makeTransform2D(
            scale: Vec2(1, 1), angle: 0, translate: Vec3(5, 10, 0))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[3][0], 5))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[3][1], 10))
    }

    func testMakeTransform2DWithScale() {
        let mtx = Mat4.makeTransform2D(
            scale: Vec2(2, 3), angle: 0, translate: Vec3(0, 0, 0))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[0][0], 2))
        XCTAssertTrue(GameMath.isFloatEqual(mtx[1][1], 3))
    }

    func testMakeLookAt2D() {
        let mtx = Mat4.makeLookAt2D(Vec3(0, 0, 50))
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
            point: Vec2(0, 0), circle: Vec2(0, 0), radius: 1))
    }

    func testPointOnCircleEdge() {
        XCTAssertTrue(Intersect.pointCircle(
            point: Vec2(1, 0), circle: Vec2(0, 0), radius: 1))
    }

    func testPointOutsideCircle() {
        XCTAssertFalse(Intersect.pointCircle(
            point: Vec2(2, 0), circle: Vec2(0, 0), radius: 1))
    }

    func testPointOffsetCircle() {
        XCTAssertTrue(Intersect.pointCircle(
            point: Vec2(5, 5), circle: Vec2(5, 5.5), radius: 1))
    }

    // MARK: Point vs Circle (protocol overload)

    func testPointCircleWithProtocol() {
        let obj = GameObj()
        let collider = CircleCollider(parent: obj, radius: 2)
        XCTAssertTrue(Intersect.pointCircle(point: Vec2(0, 0), circle: collider))
        XCTAssertFalse(Intersect.pointCircle(point: Vec2(5, 5), circle: collider))
    }

    // MARK: Point vs AABB

    func testPointInsideAABB() {
        XCTAssertTrue(Intersect.pointAABB(
            point: Vec2(0, 0), center: Vec2(0, 0), width: 2, height: 2))
    }

    func testPointOnAABBEdge() {
        XCTAssertTrue(Intersect.pointAABB(
            point: Vec2(1, 0), center: Vec2(0, 0), width: 2, height: 2))
    }

    func testPointOutsideAABB() {
        XCTAssertFalse(Intersect.pointAABB(
            point: Vec2(2, 0), center: Vec2(0, 0), width: 2, height: 2))
    }

    func testPointOffsetAABB() {
        XCTAssertTrue(Intersect.pointAABB(
            point: Vec2(5.5, 5.5), center: Vec2(5, 5), width: 2, height: 2))
    }

    // MARK: Point vs Line Segment

    func testPointOnLineSegment() {
        let result = Intersect.pointLineSegment(
            point: Vec2(5, 0), start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertTrue(result, "Point at midpoint of line should intersect")
    }

    func testPointAtLineStart() {
        let result = Intersect.pointLineSegment(
            point: Vec2(0, 0), start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertTrue(result, "Point at start of line should intersect")
    }

    func testPointOffLine() {
        let result = Intersect.pointLineSegment(
            point: Vec2(5, 5), start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertFalse(result, "Point far from line should not intersect")
    }

    func testPointBeyondLineEnd() {
        let result = Intersect.pointLineSegment(
            point: Vec2(15, 0), start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertFalse(result, "Point beyond line end should not intersect")
    }

    // MARK: Circle vs Circle

    func testCirclesOverlapping() {
        XCTAssertTrue(Intersect.circleCircle(
            center1: Vec2(0, 0), center2: Vec2(1, 0), radius1: 1, radius2: 1))
    }

    func testCirclesTouching() {
        XCTAssertTrue(Intersect.circleCircle(
            center1: Vec2(0, 0), center2: Vec2(2, 0), radius1: 1, radius2: 1))
    }

    func testCirclesSeparated() {
        XCTAssertFalse(Intersect.circleCircle(
            center1: Vec2(0, 0), center2: Vec2(5, 0), radius1: 1, radius2: 1))
    }

    // MARK: Circle vs Circle (protocol overload)

    func testCircleCircleWithProtocol() {
        let obj1 = GameObj()
        let obj2 = GameObj()
        obj2.position.set(1, 0)
        let c1 = CircleCollider(parent: obj1, radius: 1)
        let c2 = CircleCollider(parent: obj2, radius: 1)
        XCTAssertTrue(Intersect.circleCircle(c1, c2))
    }

    // MARK: Circle vs AABB

    func testCircleOverlappingAABB() {
        XCTAssertTrue(Intersect.circleAABB(
            circleCenter: Vec2(1.5, 0), radius: 1,
            aabbCenter: Vec2(0, 0), width: 2, height: 2))
    }

    func testCircleInsideAABB() {
        XCTAssertTrue(Intersect.circleAABB(
            circleCenter: Vec2(0, 0), radius: 0.5,
            aabbCenter: Vec2(0, 0), width: 2, height: 2))
    }

    func testCircleFarFromAABB() {
        XCTAssertFalse(Intersect.circleAABB(
            circleCenter: Vec2(5, 0), radius: 1,
            aabbCenter: Vec2(0, 0), width: 2, height: 2))
    }

    func testCircleAtAABBCorner() {
        XCTAssertTrue(Intersect.circleAABB(
            circleCenter: Vec2(1.5, 1.5), radius: 1,
            aabbCenter: Vec2(0, 0), width: 2, height: 2))
    }

    // MARK: Circle vs Line Segment

    func testCircleIntersectsLineSegment() {
        XCTAssertTrue(Intersect.circleLineSegment(
            center: Vec2(0, 0), radius: 1,
            start: Vec2(-5, 0), end: Vec2(5, 0)))
    }

    func testCircleMissesLineSegment() {
        XCTAssertFalse(Intersect.circleLineSegment(
            center: Vec2(0, 5), radius: 1,
            start: Vec2(-5, 0), end: Vec2(5, 0)))
    }

    func testCircleAtLineSegmentEnd() {
        let result = Intersect.circleLineSegment(
            center: Vec2(10, 0.5), radius: 1,
            start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertTrue(result, "Circle overlapping line segment endpoint should intersect")
    }

    func testCirclePastLineSegmentEnd() {
        let result = Intersect.circleLineSegment(
            center: Vec2(12, 0), radius: 0.5,
            start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertFalse(result, "Circle past line segment end should not intersect")
    }

    func testCircleBeforeLineSegmentStart() {
        let result = Intersect.circleLineSegment(
            center: Vec2(-2, 0), radius: 0.5,
            start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertFalse(result, "Circle before line segment start should not intersect")
    }

    func testCircleOverlapsLineSegmentStart() {
        let result = Intersect.circleLineSegment(
            center: Vec2(-0.5, 0), radius: 1,
            start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertTrue(result, "Circle overlapping line segment start should intersect")
    }

    func testCirclePerpendicularNearMiss() {
        let result = Intersect.circleLineSegment(
            center: Vec2(5, 1.5), radius: 1,
            start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertFalse(result, "Circle near but not touching line should not intersect")
    }

    func testCirclePerpendicularJustTouching() {
        let result = Intersect.circleLineSegment(
            center: Vec2(5, 0.9), radius: 1,
            start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertTrue(result, "Circle just touching line should intersect")
    }

    func testCircleIntersectsDiagonalLine() {
        let result = Intersect.circleLineSegment(
            center: Vec2(5, 5), radius: 1,
            start: Vec2(0, 0), end: Vec2(10, 10))
        XCTAssertTrue(result, "Circle on diagonal line should intersect")
    }

    func testCircleCenteredOnLineEnd() {
        let result = Intersect.circleLineSegment(
            center: Vec2(10, 0), radius: 1,
            start: Vec2(0, 0), end: Vec2(10, 0))
        XCTAssertTrue(result, "Circle centered on line endpoint should intersect")
    }

    // MARK: AABB vs AABB

    func testAABBsOverlapping() {
        let a = TestAABB(center: Vec2(0, 0), width: 2, height: 2)
        let b = TestAABB(center: Vec2(1, 0), width: 2, height: 2)
        XCTAssertTrue(Intersect.aabbAABB(a, b))
    }

    func testAABBsSeparated() {
        let a = TestAABB(center: Vec2(0, 0), width: 2, height: 2)
        let b = TestAABB(center: Vec2(5, 0), width: 2, height: 2)
        XCTAssertFalse(Intersect.aabbAABB(a, b))
    }

    func testAABBsTouching() {
        let a = TestAABB(center: Vec2(0, 0), width: 2, height: 2)
        let b = TestAABB(center: Vec2(2, 0), width: 2, height: 2)
        XCTAssertTrue(Intersect.aabbAABB(a, b))
    }
}

// MARK: - MutableCircle / CircleCollider Tests

@MainActor
final class CircleColliderTests: XCTestCase {

    func testCircleColliderTracksGameObj() {
        let obj = GameObj()
        obj.position.set(5, 10)
        let collider = CircleCollider(parent: obj, radius: 2)

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
        let collider = CircleCollider(parent: obj, radius: 1)

        collider.center = Vec2(7, 8)
        XCTAssertEqual(obj.position.x, 7)
        XCTAssertEqual(obj.position.y, 8)
    }

    func testCircleColliderRadius() {
        let obj = GameObj()
        let collider = CircleCollider(parent: obj, radius: 3)
        XCTAssertEqual(collider.radius, 3)
        collider.radius = 5
        XCTAssertEqual(collider.radius, 5)
    }
}

// MARK: - Vector Instance Method Tests

final class VectorMethodTests: XCTestCase {

    func testDotVec2() {
        let a = Vec2(1, 0)
        let b = Vec2(0, 1)
        XCTAssertEqual(a.dot(b), 0)
        XCTAssertEqual(a.dot(a), 1)
    }

    func testDotVec3() {
        let a = Vec3(1, 2, 3)
        let b = Vec3(4, 5, 6)
        XCTAssertEqual(a.dot(b), 32)
    }

    func testNormalizeVec2() {
        let v = Vec2(3, 0).normalized
        XCTAssertTrue(GameMath.isFloatEqual(v.x, 1))
        XCTAssertTrue(GameMath.isFloatEqual(v.y, 0))
    }

    func testNormalizeVec3() {
        let v = Vec3(0, 0, 5).normalized
        XCTAssertTrue(GameMath.isFloatEqual(v.z, 1))
    }

    func testLength() {
        XCTAssertTrue(GameMath.isFloatEqual(Vec2(3, 4).length, 5))
        XCTAssertTrue(GameMath.isFloatEqual(Vec3(0, 3, 4).length, 5))
    }

    func testLengthSquared() {
        XCTAssertTrue(GameMath.isFloatEqual(Vec2(3, 4).lengthSquared, 25))
    }

    func testDistanceVec2() {
        let d = Vec2(0, 0).distance(to: Vec2(3, 4))
        XCTAssertTrue(GameMath.isFloatEqual(d, 5))
    }

    func testDistanceVec3() {
        let d = Vec3(0, 0, 0).distance(to: Vec3(0, 3, 4))
        XCTAssertTrue(GameMath.isFloatEqual(d, 5))
    }
}

// MARK: - Interpolation Tests

final class InterpolationTests: XCTestCase {

    func testLerpFloat() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.lerp(a: 0, b: 10, t: 0), 0))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.lerp(a: 0, b: 10, t: 1), 10))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.lerp(a: 0, b: 10, t: 0.5), 5))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.lerp(a: -5, b: 5, t: 0.5), 0))
    }

    func testLerpVec2() {
        let result = GameMath.lerp(a: Vec2(0, 0), b: Vec2(10, 20), t: 0.5)
        XCTAssertTrue(GameMath.isFloatEqual(result.x, 5))
        XCTAssertTrue(GameMath.isFloatEqual(result.y, 10))
    }

    func testLerpVec3() {
        let result = GameMath.lerp(a: Vec3(0, 0, 0), b: Vec3(10, 20, 30), t: 0.25)
        XCTAssertTrue(GameMath.isFloatEqual(result.x, 2.5))
        XCTAssertTrue(GameMath.isFloatEqual(result.y, 5))
        XCTAssertTrue(GameMath.isFloatEqual(result.z, 7.5))
    }

    func testInverseLerp() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.inverseLerp(a: 0, b: 10, value: 5), 0.5))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.inverseLerp(a: 0, b: 10, value: 0), 0))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.inverseLerp(a: 0, b: 10, value: 10), 1))
    }

    func testRemap() {
        let result = GameMath.remap(value: 5, fromLow: 0, fromHigh: 10, toLow: 0, toHigh: 100)
        XCTAssertTrue(GameMath.isFloatEqual(result, 50))
    }

    func testRemapDifferentRanges() {
        let result = GameMath.remap(value: 0.5, fromLow: 0, fromHigh: 1, toLow: -100, toHigh: 100)
        XCTAssertTrue(GameMath.isFloatEqual(result, 0))
    }
}

// MARK: - Smoothstep Tests

final class SmoothstepTests: XCTestCase {

    func testSmoothstepEdges() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.smoothstep(edge0: 0, edge1: 1, x: 0), 0))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.smoothstep(edge0: 0, edge1: 1, x: 1), 1))
    }

    func testSmoothstepMiddle() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.smoothstep(edge0: 0, edge1: 1, x: 0.5), 0.5))
    }

    func testSmoothstepClamped() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.smoothstep(edge0: 0, edge1: 1, x: -1), 0))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.smoothstep(edge0: 0, edge1: 1, x: 2), 1))
    }

    func testSmootherstepEdges() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.smootherstep(edge0: 0, edge1: 1, x: 0), 0))
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.smootherstep(edge0: 0, edge1: 1, x: 1), 1))
    }

    func testSmootherstepMiddle() {
        XCTAssertTrue(GameMath.isFloatEqual(GameMath.smootherstep(edge0: 0, edge1: 1, x: 0.5), 0.5))
    }
}

// MARK: - Random Tests

final class RandomTests: XCTestCase {

    func testRandomInRange() {
        for _ in 0..<100 {
            let v = Float.random(in: -5...5)
            XCTAssertTrue(v >= -5 && v <= 5)
        }
    }

    func testRandomVec2InRange() {
        for _ in 0..<100 {
            let v = Vec2.random(x: 0...1, y: -1...1)
            XCTAssertTrue(v.x >= 0 && v.x <= 1)
            XCTAssertTrue(v.y >= -1 && v.y <= 1)
        }
    }

    func testRandomDirectionIsUnitLength() {
        for _ in 0..<100 {
            let v = Vec2.randomDirection()
            XCTAssertTrue(GameMath.isFloatEqual(v.length, 1))
        }
    }
}

// MARK: - Bezier Tests

final class BezierTests: XCTestCase {

    func testQuadraticBezierEndpoints() {
        let p0 = Vec2(0, 0)
        let p1 = Vec2(5, 10)
        let p2 = Vec2(10, 0)
        let start = GameMath.quadraticBezier(p0: p0, p1: p1, p2: p2, t: 0)
        let end = GameMath.quadraticBezier(p0: p0, p1: p1, p2: p2, t: 1)
        XCTAssertTrue(simd_epsilon_equal(lhs: start, rhs: p0))
        XCTAssertTrue(simd_epsilon_equal(lhs: end, rhs: p2))
    }

    func testCubicBezierEndpoints() {
        let p0 = Vec2(0, 0)
        let p1 = Vec2(2, 10)
        let p2 = Vec2(8, 10)
        let p3 = Vec2(10, 0)
        let start = GameMath.cubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: 0)
        let end = GameMath.cubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: 1)
        XCTAssertTrue(simd_epsilon_equal(lhs: start, rhs: p0))
        XCTAssertTrue(simd_epsilon_equal(lhs: end, rhs: p3))
    }

    func testQuadraticBezierMidpoint() {
        let p0 = Vec2(0, 0)
        let p1 = Vec2(5, 10)
        let p2 = Vec2(10, 0)
        let mid = GameMath.quadraticBezier(p0: p0, p1: p1, p2: p2, t: 0.5)
        XCTAssertTrue(GameMath.isFloatEqual(mid.x, 5))
        XCTAssertTrue(GameMath.isFloatEqual(mid.y, 5))
    }
}

// MARK: - Easing Tests

final class EasingTests: XCTestCase {

    func testAllEasingsBoundaries() {
        let easings: [(String, (Float) -> Float)] = [
            ("easeInQuad", Easing.easeInQuad),
            ("easeOutQuad", Easing.easeOutQuad),
            ("easeInOutQuad", Easing.easeInOutQuad),
            ("easeInCubic", Easing.easeInCubic),
            ("easeOutCubic", Easing.easeOutCubic),
            ("easeInOutCubic", Easing.easeInOutCubic),
            ("easeInQuart", Easing.easeInQuart),
            ("easeOutQuart", Easing.easeOutQuart),
            ("easeInOutQuart", Easing.easeInOutQuart),
            ("easeInSine", Easing.easeInSine),
            ("easeOutSine", Easing.easeOutSine),
            ("easeInOutSine", Easing.easeInOutSine),
            ("easeInExpo", Easing.easeInExpo),
            ("easeOutExpo", Easing.easeOutExpo),
            ("easeInOutExpo", Easing.easeInOutExpo),
            ("easeOutBounce", Easing.easeOutBounce),
            ("easeInBounce", Easing.easeInBounce),
            ("easeInOutBounce", Easing.easeInOutBounce)
        ]

        for (name, easing) in easings {
            XCTAssertTrue(
                GameMath.isFloatEqual(easing(0), 0),
                "\(name)(0) should be 0, got \(easing(0))")
            XCTAssertTrue(
                GameMath.isFloatEqual(easing(1), 1),
                "\(name)(1) should be 1, got \(easing(1))")
        }
    }

    func testEaseInQuadShape() {
        // ease-in should be below linear at midpoint
        XCTAssertTrue(Easing.easeInQuad(0.5) < 0.5)
    }

    func testEaseOutQuadShape() {
        // ease-out should be above linear at midpoint
        XCTAssertTrue(Easing.easeOutQuad(0.5) > 0.5)
    }

    func testEaseInOutQuadSymmetry() {
        XCTAssertTrue(GameMath.isFloatEqual(Easing.easeInOutQuad(0.5), 0.5))
    }

    func testElasticOvershoots() {
        // Elastic should overshoot past 1 at some point
        var foundOvershoot = false
        for i in 1..<20 {
            let t = Float(i) / 20.0
            if Easing.easeOutElastic(t) > 1.0 {
                foundOvershoot = true
                break
            }
        }
        XCTAssertTrue(foundOvershoot, "easeOutElastic should overshoot past 1")
    }

    func testBackOvershoots() {
        // Back easing should go below 0 at start (easeIn) or above 1 near end (easeOut)
        XCTAssertTrue(Easing.easeInBack(0.2) < 0, "easeInBack should go below 0")
        XCTAssertTrue(Easing.easeOutBack(0.8) > 1, "easeOutBack should overshoot past 1")
    }
}
