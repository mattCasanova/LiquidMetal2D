import XCTest
@testable import LiquidMetal2D

final class SchedulerTests: XCTestCase {

    // MARK: - Basic Firing

    func testTaskFiresAtInterval() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 1.0, action: { count += 1 })
        scheduler.add(task: task)

        scheduler.update(dt: 0.5)
        XCTAssertEqual(count, 0, "Should not fire before interval")

        scheduler.update(dt: 0.5)
        XCTAssertEqual(count, 1, "Should fire at exactly 1.0s")
    }

    func testTaskFiresMultipleTimesWithLargeDt() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 0.1, action: { count += 1 })
        scheduler.add(task: task)

        scheduler.update(dt: 0.35)
        XCTAssertEqual(count, 3, "Should fire 3 times for dt=0.35 with interval=0.1")
    }

    func testFiniteRepeatCount() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 0.5, action: { count += 1 }, count: 3)
        scheduler.add(task: task)

        scheduler.update(dt: 0.5)
        XCTAssertEqual(count, 1)
        scheduler.update(dt: 0.5)
        XCTAssertEqual(count, 2)
        scheduler.update(dt: 0.5)
        XCTAssertEqual(count, 3)
        scheduler.update(dt: 0.5)
        XCTAssertEqual(count, 3, "Should not fire after repeat count exhausted")
    }

    func testInfiniteRepeat() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 0.1, action: { count += 1 })
        scheduler.add(task: task)

        for _ in 0..<100 {
            scheduler.update(dt: 0.1)
        }
        XCTAssertEqual(count, 100, "Infinite task should keep firing")
    }

    func testZeroRepeatCountNotAdded() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 0.1, action: { count += 1 }, count: 0)
        scheduler.add(task: task)

        scheduler.update(dt: 1.0)
        XCTAssertEqual(count, 0, "Task with 0 repeats should not be added")
    }

    // MARK: - Timer Drift

    func testNoDriftOnExactInterval() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 0.1, action: { count += 1 })
        scheduler.add(task: task)

        // 10 frames at exactly 0.1s
        for _ in 0..<10 {
            scheduler.update(dt: 0.1)
        }
        XCTAssertEqual(count, 10)
    }

    func testOvershootPreserved() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 0.3, action: { count += 1 })
        scheduler.add(task: task)

        // dt=0.35: fires once at 0.3, overshoot of 0.05 preserved
        scheduler.update(dt: 0.35)
        XCTAssertEqual(count, 1)

        // dt=0.26: accumulated = 0.05 + 0.26 = 0.31, should fire again
        scheduler.update(dt: 0.26)
        XCTAssertEqual(count, 2, "Overshoot should carry forward")
    }

    // MARK: - onComplete

    func testOnCompleteCalledWhenDone() {
        let scheduler = Scheduler()
        var completed = false
        let task = ScheduledTask(
            time: 0.1, action: {}, count: 1,
            onComplete: { completed = true })
        scheduler.add(task: task)

        scheduler.update(dt: 0.1)
        XCTAssertTrue(completed)
    }

    func testOnCompleteNotCalledUntilDone() {
        let scheduler = Scheduler()
        var completed = false
        let task = ScheduledTask(
            time: 0.1, action: {}, count: 3,
            onComplete: { completed = true })
        scheduler.add(task: task)

        scheduler.update(dt: 0.1)
        XCTAssertFalse(completed)
        scheduler.update(dt: 0.1)
        XCTAssertFalse(completed)
        scheduler.update(dt: 0.1)
        XCTAssertTrue(completed)
    }

    // MARK: - Pause / Resume (Task)

    func testPauseTask() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 0.1, action: { count += 1 })
        scheduler.add(task: task)

        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 1)

        task.pause()
        scheduler.update(dt: 0.1)
        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 1, "Paused task should not fire")

        task.resume()
        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 2, "Resumed task should fire again")
    }

    func testPausedTaskDoesNotAccumulateTime() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 1.0, action: { count += 1 })
        scheduler.add(task: task)

        scheduler.update(dt: 0.5)
        task.pause()

        // 10 seconds pass while paused
        for _ in 0..<100 {
            scheduler.update(dt: 0.1)
        }
        XCTAssertEqual(count, 0)

        task.resume()
        // Still needs 0.5s more to fire (time didn't accumulate while paused)
        scheduler.update(dt: 0.4)
        XCTAssertEqual(count, 0, "Should still need 0.5s more")
        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 1)
    }

    // MARK: - Pause / Resume (Scheduler)

    func testPauseScheduler() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 0.1, action: { count += 1 })
        scheduler.add(task: task)

        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 1)

        scheduler.isPaused = true
        scheduler.update(dt: 0.1)
        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 1, "Paused scheduler should skip all tasks")

        scheduler.isPaused = false
        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 2)
    }

    // MARK: - Task Chaining

    func testTaskChaining() {
        let scheduler = Scheduler()
        var phase1Count = 0
        var phase2Count = 0

        let task = ScheduledTask(
            time: 0.1, action: { phase1Count += 1 }, count: 2)
        task.then(time: 0.1, action: { phase2Count += 1 }, count: 1)
        scheduler.add(task: task)

        scheduler.update(dt: 0.1)
        XCTAssertEqual(phase1Count, 1)
        XCTAssertEqual(phase2Count, 0)

        scheduler.update(dt: 0.1)
        XCTAssertEqual(phase1Count, 2, "Phase 1 should complete")
        XCTAssertEqual(phase2Count, 0, "Phase 2 not started yet")

        scheduler.update(dt: 0.1)
        XCTAssertEqual(phase2Count, 1, "Phase 2 should fire after phase 1 completes")
    }

    // MARK: - Remove

    func testRemoveTask() {
        let scheduler = Scheduler()
        var count = 0
        let task = ScheduledTask(time: 0.1, action: { count += 1 })
        scheduler.add(task: task)

        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 1)

        scheduler.remove(toRemove: task)
        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 1, "Removed task should not fire")
    }

    func testClear() {
        let scheduler = Scheduler()
        var count = 0
        for _ in 0..<5 {
            scheduler.add(task: ScheduledTask(time: 0.1, action: { count += 1 }))
        }

        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 5)

        scheduler.clear()
        scheduler.update(dt: 0.1)
        XCTAssertEqual(count, 5, "No tasks should fire after clear")
    }

    // MARK: - Mutation Safety

    func testOnCompleteCanAddNewTask() {
        let scheduler = Scheduler()
        var phase2Count = 0

        let task = ScheduledTask(
            time: 0.1, action: {}, count: 1,
            onComplete: {
                scheduler.add(task: ScheduledTask(
                    time: 0.1, action: { phase2Count += 1 }, count: 1))
            })
        scheduler.add(task: task)

        scheduler.update(dt: 0.1)
        XCTAssertEqual(phase2Count, 0, "New task should not fire in the same frame")

        scheduler.update(dt: 0.1)
        XCTAssertEqual(phase2Count, 1, "New task should fire next frame")
    }
}
