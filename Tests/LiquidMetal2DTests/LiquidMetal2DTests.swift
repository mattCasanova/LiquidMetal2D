import XCTest
@testable import LiquidMetal2D

@MainActor
final class LiquidMetal2DTests: XCTestCase {

    func testGameObjDefaults() {
        let obj = GameObj()
        XCTAssertEqual(obj.position.x, 0)
        XCTAssertEqual(obj.position.y, 0)
        XCTAssertEqual(obj.rotation, 0)
        XCTAssertEqual(obj.zOrder, 0)
        XCTAssertEqual(obj.textureID, 0)
    }

    func testCamera2DDefaults() {
        let camera = Camera2D()
        XCTAssertEqual(camera.eye.x, 0)
        XCTAssertEqual(camera.eye.y, 0)
        XCTAssertEqual(camera.distance, 0)
    }

    func testCamera2DSet() {
        let camera = Camera2D()
        camera.set(x: 5, y: 10, distance: 50)
        XCTAssertEqual(camera.eye.x, 5)
        XCTAssertEqual(camera.eye.y, 10)
        XCTAssertEqual(camera.distance, 50)
    }

    func testWorldBounds() {
        let bounds = WorldBounds(minX: -10, maxX: 10, minY: -5, maxY: 5)
        XCTAssertEqual(bounds.minX, -10)
        XCTAssertEqual(bounds.maxX, 10)
        XCTAssertEqual(bounds.minY, -5)
        XCTAssertEqual(bounds.maxY, 5)
        XCTAssertEqual(bounds.width, 20)
        XCTAssertEqual(bounds.height, 10)
        XCTAssertTrue(bounds.contains(Vec2(0, 0)))
        XCTAssertTrue(bounds.contains(Vec2(10, 5)))
        XCTAssertFalse(bounds.contains(Vec2(11, 0)))
    }

    func testPerspectiveProjectionSet() {
        let proj = PerspectiveProjection()
        proj.set(aspect: 1.5, fov: 1.0, nearZ: 0.1, farZ: 100)
        XCTAssertEqual(proj.aspect, 1.5)
        XCTAssertEqual(proj.fov, 1.0)
        XCTAssertEqual(proj.nearZ, 0.1)
        XCTAssertEqual(proj.farZ, 100)
    }

    func testSchedulerAddAndClear() {
        let scheduler = Scheduler()
        var called = false
        let task = ScheduledTask(time: 1.0, action: { _ in called = true }, count: 1)
        scheduler.add(task: task)
        scheduler.update(dt: 1.1)
        XCTAssertTrue(called)
    }

    func testSchedulerInfiniteScheduledTask() {
        let scheduler = Scheduler()
        var callCount = 0
        let task = ScheduledTask(time: 0.5, action: { _ in callCount += 1 }, count: ScheduledTask.INFINITE)
        scheduler.add(task: task)
        scheduler.update(dt: 0.6)
        scheduler.update(dt: 0.6)
        XCTAssertEqual(callCount, 2)
    }
}
