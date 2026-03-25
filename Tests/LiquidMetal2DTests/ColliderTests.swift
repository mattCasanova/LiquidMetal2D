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
        return (obj, PointCollider(parent: obj))
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
        XCTAssertTrue(collider1.doesCollideWith(collider: collider2))
    }

    // MARK: Object movement

    func testCollisionChangesAfterMove() {
        let (obj, collider) = makePointCollider(at: Vec2(0, 0))
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(0, 0)))

        obj.position.set(100, 100)
        XCTAssertFalse(collider.doesCollideWith(point: Vec2(0, 0)))
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(100, 100)))
    }
}

// MARK: - CircleCollider Component Tests

@MainActor
final class CircleColliderComponentTests: XCTestCase {

    private func makeCircleCollider(at position: Vec2, radius: Float) -> (GameObj, CircleCollider) {
        let obj = GameObj()
        obj.position = position
        return (obj, CircleCollider(parent: obj, radius: radius))
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

    func testCollisionChangesAfterMove() {
        let (obj, collider) = makeCircleCollider(at: Vec2(0, 0), radius: 2)
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(1, 0)))

        obj.position.set(100, 100)
        XCTAssertFalse(collider.doesCollideWith(point: Vec2(1, 0)))
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(100, 100)))
    }
}

// MARK: - AABBCollider Tests

@MainActor
final class AABBColliderTests: XCTestCase {

    private func makeAABBCollider(
        at position: Vec2, width: Float, height: Float
    ) -> (GameObj, AABBCollider) {
        let obj = GameObj()
        obj.position = position
        return (obj, AABBCollider(parent: obj, width: width, height: height))
    }

    // MARK: AABB vs Point

    func testPointAtCenter() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(0, 0)))
    }

    func testPointInside() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(3, 3)))
    }

    func testPointOutside() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        XCTAssertFalse(collider.doesCollideWith(point: Vec2(20, 20)))
    }

    func testPointOnEdge() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(5, 0)))
    }

    // MARK: AABB vs Circle

    func testCircleOverlapping() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        let circle = TestCircle(center: Vec2(7, 0), radius: 3)
        XCTAssertTrue(collider.doesCollideWith(circle: circle))
    }

    func testCircleNotOverlapping() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        let circle = TestCircle(center: Vec2(20, 0), radius: 2)
        XCTAssertFalse(collider.doesCollideWith(circle: circle))
    }

    func testCircleInsideAABB() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        let circle = TestCircle(center: Vec2(0, 0), radius: 1)
        XCTAssertTrue(collider.doesCollideWith(circle: circle))
    }

    // MARK: AABB vs AABB

    func testAABBOverlapping() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        XCTAssertTrue(collider.doesCollideWith(aabbCenter: Vec2(8, 0), width: 10, height: 10))
    }

    func testAABBNotOverlapping() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        XCTAssertFalse(collider.doesCollideWith(aabbCenter: Vec2(20, 0), width: 5, height: 5))
    }

    func testAABBTouching() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        XCTAssertTrue(collider.doesCollideWith(aabbCenter: Vec2(10, 0), width: 10, height: 10))
    }

    func testAABBAtNonOrigin() {
        let (obj, collider) = makeAABBCollider(at: Vec2(10, 10), width: 6, height: 6)
        XCTAssertTrue(collider.doesCollideWith(aabbCenter: Vec2(14, 10), width: 6, height: 6))
    }

    // MARK: Double dispatch

    func testAABBVsCircleColliderDoubleDispatch() {
        let (obj, aabbCollider) = makeAABBCollider(at: Vec2(0, 0), width: 10, height: 10)
        let circleObj = GameObj()
        circleObj.position.set(3, 3)
        let circleCollider = CircleCollider(parent: circleObj, radius: 2)
        XCTAssertTrue(aabbCollider.doesCollideWith(collider: circleCollider))
    }

    // MARK: Object movement

    func testCollisionChangesAfterMove() {
        let (obj, collider) = makeAABBCollider(at: Vec2(0, 0), width: 4, height: 4)
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(1, 1)))

        obj.position.set(100, 100)
        XCTAssertFalse(collider.doesCollideWith(point: Vec2(1, 1)))
        XCTAssertTrue(collider.doesCollideWith(point: Vec2(100, 100)))
    }
}

// MARK: - Component Integration Tests

@MainActor
final class ComponentTests: XCTestCase {

    func testAddAndGetComponent() {
        let obj = GameObj()
        let collider = CircleCollider(parent: obj, radius: 5)
        obj.add(collider)

        let retrieved = obj.get(CircleCollider.self)
        XCTAssertTrue(retrieved === collider)
    }

    func testGetMissingComponentReturnsNil() {
        let obj = GameObj()
        XCTAssertNil(obj.get(CircleCollider.self))
    }

    func testRemoveComponent() {
        let obj = GameObj()
        let collider = CircleCollider(parent: obj, radius: 5)
        obj.add(collider)
        obj.remove(CircleCollider.self)

        XCTAssertNil(obj.get(CircleCollider.self))
    }

    func testMultipleComponentTypes() {
        let obj = GameObj()
        let collider = CircleCollider(parent: obj, radius: 5)
        let aabb = AABBCollider(parent: obj, width: 10, height: 10)
        obj.add(collider)
        obj.add(aabb)

        XCTAssertTrue(obj.get(CircleCollider.self) === collider)
        XCTAssertTrue(obj.get(AABBCollider.self) === aabb)
    }

    func testAddReplacesExistingComponent() {
        let obj = GameObj()
        let first = CircleCollider(parent: obj, radius: 5)
        let second = CircleCollider(parent: obj, radius: 10)
        obj.add(first)
        obj.add(second)

        let retrieved = obj.get(CircleCollider.self)
        XCTAssertTrue(retrieved === second)
        XCTAssertEqual(retrieved?.radius, 10)
    }

    func testComponentParentReference() {
        let obj = GameObj()
        obj.position.set(5, 10)
        let collider = CircleCollider(parent: obj, radius: 3)

        XCTAssertTrue(collider.parent === obj)
        XCTAssertEqual(collider.parent.position.x, 5)
        XCTAssertEqual(collider.parent.position.y, 10)
    }
}
