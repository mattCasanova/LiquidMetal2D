import XCTest
@testable import LiquidMetal2D

// MARK: - Test Helpers

private struct TestCircle: Circle {
    var center: Vec2
    var radius: Float
}

// MARK: - PointCollider Tests

@MainActor
final class PointColliderTests: XCTestCase {

    private func makePointCollider(at position: Vec2) -> (GameObj, PointCollider) {
        let obj = GameObj()
        obj.position = position
        return (obj, PointCollider(obj: obj))
    }

    // MARK: Point vs Point

    func testPointSamePosition() {
        let (obj, collider) = makePointCollider(at: Vec2(5, 3))
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(5, 3)))
    }

    func testPointDifferentPosition() {
        let (obj, collider) = makePointCollider(at: Vec2(5, 3))
        XCTAssertFalse(collider.doesCollideWith(point: Vec2(10, 3)))
    }

    func testPointBothAtOrigin() {
        let (obj, collider) = makePointCollider(at: Vec2(0, 0))
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(0, 0)))
    }

    func testPointNegativeCoordinates() {
        let (obj, collider) = makePointCollider(at: Vec2(-5, -3))
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(-5, -3)))
    }

    // MARK: Point vs Circle

    func testPointAtCircleCenter() {
        let (obj, collider) = makePointCollider(at: Vec2(0, 0))
        let circle = TestCircle(center: Vec2(0, 0), radius: 5)
        XCTAssertTrue(collider.doesCollideWith(circle: circle))
    }

    func testPointInsideCircle() {
        let (obj, collider) = makePointCollider(at: Vec2(1, 1))
        let circle = TestCircle(center: Vec2(0, 0), radius: 5)
        XCTAssertTrue(collider.doesCollideWith(circle: circle))
    }

    func testPointOutsideCircle() {
        let (obj, collider) = makePointCollider(at: Vec2(10, 10))
        let circle = TestCircle(center: Vec2(0, 0), radius: 5)
        XCTAssertFalse(collider.doesCollideWith(circle: circle))
    }

    func testPointOnCircleEdge() {
        let (obj, collider) = makePointCollider(at: Vec2(5, 0))
        let circle = TestCircle(center: Vec2(0, 0), radius: 5)
        XCTAssertTrue(collider.doesCollideWith(circle: circle))
    }

    // MARK: Point vs AABB

    func testPointAtAABBCenter() {
        let (obj, collider) = makePointCollider(at: Vec2(0, 0))
        XCTAssertTrue(collider.doesCollideWith(aabbCenter: Vec2(0, 0), width: 10, height: 10))
    }

    func testPointInsideAABB() {
        let (obj, collider) = makePointCollider(at: Vec2(2, 3))
        XCTAssertTrue(collider.doesCollideWith(aabbCenter: Vec2(0, 0), width: 10, height: 10))
    }

    func testPointOutsideAABBLeft() {
        let (obj, collider) = makePointCollider(at: Vec2(-10, 0))
        XCTAssertFalse(collider.doesCollideWith(aabbCenter: Vec2(0, 0), width: 10, height: 10))
    }

    func testPointOutsideAABBRight() {
        let (obj, collider) = makePointCollider(at: Vec2(10, 0))
        XCTAssertFalse(collider.doesCollideWith(aabbCenter: Vec2(0, 0), width: 10, height: 10))
    }

    func testPointOutsideAABBAbove() {
        let (obj, collider) = makePointCollider(at: Vec2(0, 10))
        XCTAssertFalse(collider.doesCollideWith(aabbCenter: Vec2(0, 0), width: 10, height: 10))
    }

    func testPointOutsideAABBBelow() {
        let (obj, collider) = makePointCollider(at: Vec2(0, -10))
        XCTAssertFalse(collider.doesCollideWith(aabbCenter: Vec2(0, 0), width: 10, height: 10))
    }

    func testPointOnAABBEdge() {
        let (obj, collider) = makePointCollider(at: Vec2(5, 0))
        XCTAssertTrue(collider.doesCollideWith(aabbCenter: Vec2(0, 0), width: 10, height: 10))
    }

    func testPointAABBAtNonOriginCenter() {
        let (obj, collider) = makePointCollider(at: Vec2(15, 15))
        XCTAssertTrue(collider.doesCollideWith(aabbCenter: Vec2(10, 10), width: 20, height: 20))
    }

    // MARK: Double dispatch

    func testPointVsPointColliderDoubleDispatch() {
        let (obj1, collider1) = makePointCollider(at: Vec2(5, 5))
        let (obj2, collider2) = makePointCollider(at: Vec2(5, 5))
        _ = (obj1, obj2)
        XCTAssertTrue(collider1.doesCollideWith(collider: collider2))
    }

    func testPointVsNilCollider() {
        let (obj, collider) = makePointCollider(at: Vec2(5, 5))
        let nil_collider = NilCollider()
        XCTAssertFalse(collider.doesCollideWith(collider: nil_collider))
    }

    // MARK: Object movement

    func testCollisionChangesAfterMove() {
        let (obj, collider) = makePointCollider(at: Vec2(0, 0))
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(0, 0)))

        obj.position.set(100, 100)
        XCTAssertFalse(collider.doesCollideWith(point: Vec2(0, 0)))
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(100, 100)))
    }

    // MARK: Weak reference safety

    func testColliderReturnsFalseAfterObjDeallocated() {
        var obj: GameObj? = GameObj()
        obj!.position.set(5, 5)
        let collider = PointCollider(obj: obj!)

        XCTAssertTrue(collider.doesCollideWith(point: Vec2(5, 5)))

        obj = nil
        XCTAssertFalse(collider.doesCollideWith(point: Vec2(5, 5)),
                       "Should return false when obj is deallocated, not crash")
    }
}

// MARK: - CircleCollider Weak Reference Tests

@MainActor
final class CircleColliderWeakRefTests: XCTestCase {

    private func makeCircleCollider(at position: Vec2, radius: Float) -> (GameObj, CircleCollider) {
        let obj = GameObj()
        obj.position = position
        return (obj, CircleCollider(obj: obj, radius: radius))
    }

    func testCircleVsPointInside() {
        let (obj, collider) = makeCircleCollider(at: Vec2(0, 0), radius: 5)
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(1, 1)))
    }

    func testCircleVsPointOutside() {
        let (obj, collider) = makeCircleCollider(at: Vec2(0, 0), radius: 5)
        XCTAssertFalse(collider.doesCollideWith(point: Vec2(10, 10)))
    }

    func testCircleVsCircleOverlap() {
        let (obj1, c1) = makeCircleCollider(at: Vec2(0, 0), radius: 5)
        let (obj2, c2) = makeCircleCollider(at: Vec2(8, 0), radius: 5)
        XCTAssertTrue(c1.doesCollideWith(collider: c2))
    }

    func testCircleVsCircleNoOverlap() {
        let (obj1, c1) = makeCircleCollider(at: Vec2(0, 0), radius: 5)
        let (obj2, c2) = makeCircleCollider(at: Vec2(20, 0), radius: 5)
        XCTAssertFalse(c1.doesCollideWith(collider: c2))
    }

    func testCircleVsAABBOverlap() {
        let (obj, collider) = makeCircleCollider(at: Vec2(6, 0), radius: 2)
        XCTAssertTrue(collider.doesCollideWith(aabbCenter: Vec2(0, 0), width: 10, height: 10))
    }

    func testCircleVsAABBNoOverlap() {
        let (obj, collider) = makeCircleCollider(at: Vec2(20, 0), radius: 2)
        XCTAssertFalse(collider.doesCollideWith(aabbCenter: Vec2(0, 0), width: 10, height: 10))
    }

    func testWeakRefReturnsFalseAfterDealloc() {
        var obj: GameObj? = GameObj()
        obj!.position.set(0, 0)
        let collider = CircleCollider(obj: obj!, radius: 5)

        XCTAssertTrue(collider.doesCollideWith(point: Vec2(0, 0)))

        obj = nil
        XCTAssertFalse(collider.doesCollideWith(
            aabbCenter: Vec2(0, 0), width: 10, height: 10),
            "Should return false when obj is deallocated, not crash")
    }
}
