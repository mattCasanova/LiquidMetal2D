import XCTest
@testable import LiquidMetal2D

private struct Box: AABB {
    var center: Vec2
    var width: Float
    var height: Float
}

/// A y-up world with gravity (0, −400): a floor at y = 0 (top face), a
/// wall and a ceiling, and a mover of half-size (2, 5) unless a test says otherwise.
final class ArcSweepTests: XCTestCase {
    private let gravity = Vec2(0, -400)
    private let halfSize = Vec2(2, 5)
    /// 200 wide, 20 tall, its top face at y = 0.
    private let floor = Box(center: Vec2(0, -10), width: 200, height: 20)

    private func assertEqual(_ a: Vec2, _ b: Vec2, accuracy: Float = 1e-3, _ message: String = "",
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: accuracy, "x: \(message)", file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: accuracy, "y: \(message)", file: file, line: line)
    }

    private func hit(
        _ result: ArcSweep.Result, file: StaticString = #filePath, line: UInt = #line
    ) throws -> ArcSweep.Hit {
        guard case .hit(let hit) = result else {
            XCTFail("expected a hit, got \(result)", file: file, line: line)
            throw XCTSkip("no hit")
        }
        return hit
    }

    // 12
    func testADropOntoTheFloorStopsHalfTheMoverAboveIt() throws {
        var sweep = ArcSweep()
        let result = sweep.trace(from: Vec2(0, 50), velocity: .zero, gravity: gravity, halfSize: halfSize,
                                 boxes: [floor])
        let hit = try hit(result)
        XCTAssertEqual(hit.point.y, 5, accuracy: 1e-3, "the floor's top plus the mover's half height")
        XCTAssertEqual(hit.point.x, 0, accuracy: 1e-5)
        XCTAssertEqual(hit.normal, Vec2(0, 1))
        XCTAssertEqual(hit.obstacle, .box(0))
        // Free fall from 50 to 5: 45 = ½·400·t² → t = 0.4743.
        XCTAssertEqual(hit.time, (2 * 45 / 400).squareRoot(), accuracy: 1e-3)
        XCTAssertEqual(sweep.hit, hit)
    }

    // 13
    func testAJumpIntoAWallStopsAtItsFace() throws {
        let wall = Box(center: Vec2(60, 50), width: 20, height: 100)  // left face at x = 50
        var sweep = ArcSweep()
        let result = sweep.trace(from: Vec2(0, 5), velocity: Vec2(150, 150), gravity: gravity, halfSize: halfSize,
                                 boxes: [floor, wall])
        let hit = try hit(result)
        XCTAssertEqual(hit.normal, Vec2(-1, 0))
        XCTAssertEqual(hit.point.x, 50 - halfSize.x, accuracy: 1e-3)
        XCTAssertEqual(hit.obstacle, .box(1))
        XCTAssertGreaterThan(hit.point.y, 5, "still in the air when it hit")
    }

    // 14
    func testAJumpUnderALowCeilingHitsItFromBelow() throws {
        let ceiling = Box(center: Vec2(0, 45), width: 200, height: 10)  // underside at y = 40
        var sweep = ArcSweep()
        let result = sweep.trace(from: Vec2(0, 5), velocity: Vec2(20, 300), gravity: gravity, halfSize: halfSize,
                                 boxes: [floor, ceiling])
        let hit = try hit(result)
        XCTAssertEqual(hit.normal, Vec2(0, -1))
        XCTAssertEqual(hit.point.y, 40 - halfSize.y, accuracy: 1e-3)
        XCTAssertEqual(hit.obstacle, .box(1))
    }

    // 15
    func testNoObstaclesRunsToMaxTime() {
        var sweep = ArcSweep()
        let result = sweep.trace(from: .zero, velocity: Vec2(10, 10), gravity: gravity, boxes: [Box](), maxTime: 2)
        guard case .noHit(let endTime) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(endTime, 2, accuracy: 0.02)
        XCTAssertEqual(Float(sweep.samples.count), 2 * 60 + 1, accuracy: 1.5)
        XCTAssertNil(sweep.hit)
        assertEqual(sweep.samples[0], .zero)
    }

    // 16
    func testTheSameInputsGiveTheSamePointsAndTheStepIsTheStructs() throws {
        var first = ArcSweep()
        var second = ArcSweep()
        let wall = Box(center: Vec2(60, 50), width: 20, height: 100)
        let boxes = [floor, wall]
        first.trace(from: Vec2(0, 5), velocity: Vec2(150, 150), gravity: gravity, halfSize: halfSize, boxes: boxes)
        second.trace(from: Vec2(0, 5), velocity: Vec2(150, 150), gravity: gravity, halfSize: halfSize, boxes: boxes)
        XCTAssertEqual(first.samples, second.samples)
        XCTAssertEqual(first.hit, second.hit)

        var coarse = ArcSweep(dt: 1 / 30)
        coarse.trace(from: Vec2(0, 5), velocity: Vec2(150, 150), gravity: gravity, halfSize: halfSize, boxes: boxes)
        XCTAssertEqual(coarse.dt, 1 / 30)
        XCTAssertLessThan(coarse.samples.count, first.samples.count, "half the steps")
        let fineHit = try XCTUnwrap(first.hit)
        let coarseHit = try XCTUnwrap(coarse.hit)
        XCTAssertEqual(coarseHit.point.x, fineHit.point.x, accuracy: 1e-3, "the wall is where it is")
        XCTAssertEqual(coarseHit.time, fineHit.time, accuracy: 1e-3)
    }

    // 17
    func testSteppingAMoverAlongTheSamplesEndsOnTheHit() throws {
        var sweep = ArcSweep()
        let result = sweep.trace(from: Vec2(0, 50), velocity: Vec2(30, 40), gravity: gravity, halfSize: halfSize,
                                 boxes: [floor])
        let hit = try hit(result)
        var mover = Vec2(-999, -999)
        for sample in sweep.samples { mover = sample }
        XCTAssertEqual(mover, hit.point, "the same array, the same last element")
    }

    // 18
    func testAWallSegmentIsHitWhereSegmentSegmentSaysAndABoxWinsATie() throws {
        let diagonal = LineSegment(start: Vec2(20, 0), end: Vec2(60, 40))
        var sweep = ArcSweep()
        let result = sweep.trace(from: Vec2(0, 10), velocity: Vec2(100, 20), gravity: gravity, boxes: [floor],
                                 walls: [diagonal])
        let hit = try hit(result)
        XCTAssertEqual(hit.obstacle, .wall(0))
        // The hit point lies on the wall's line: (x − 20) = (y − 0).
        XCTAssertEqual(hit.point.x - 20, hit.point.y, accuracy: 1e-3)
        XCTAssertEqual(hit.normal.length, 1, accuracy: 1e-5)
        XCTAssertLessThan(hit.normal.x, 0, "faces the arc, which came from the left")
        let before = sweep.samples[sweep.samples.count - 2]
        let stepEnd = Ballistics.position(start: Vec2(0, 10), velocity: Vec2(100, 20), gravity: gravity,
                                          at: Float(sweep.samples.count - 1) * sweep.dt)
        let step = LineSegment(start: before, end: stepEnd)
        let fraction = try XCTUnwrap(Intersect.segmentSegment(step, diagonal))
        assertEqual(hit.point, before + (step.end - before) * fraction)

        // A wall lying along the floor's top face is hit at the same fraction as the floor: the box wins.
        let alongFloor = LineSegment(start: Vec2(-100, 5), end: Vec2(100, 5))
        var tie = ArcSweep()
        let tied = tie.trace(from: Vec2(0, 50), velocity: .zero, gravity: gravity, halfSize: halfSize, boxes: [floor],
                             walls: [alongFloor])
        XCTAssertEqual(try self.hit(tied).obstacle, .box(0))
    }

    // 19
    func testTheNearerOfTwoBoxesWins() throws {
        let near = Box(center: Vec2(40, 10), width: 10, height: 20)
        let far = Box(center: Vec2(80, 10), width: 10, height: 20)
        var sweep = ArcSweep()
        let result = sweep.trace(from: Vec2(0, 10), velocity: Vec2(200, 0), gravity: .zero, boxes: [far, near])
        XCTAssertEqual(try hit(result).obstacle, .box(1))
        XCTAssertEqual(try hit(result).point.x, 35, accuracy: 1e-3)
    }

    // 20
    func testStartingInsideAGrownBoxHitsAtTimeZero() throws {
        var sweep = ArcSweep()
        // 3 above the floor's top with a half height of 5: already overlapping.
        let result = sweep.trace(from: Vec2(0, 3), velocity: Vec2(50, 100), gravity: gravity, halfSize: halfSize,
                                 boxes: [floor])
        let hit = try hit(result)
        XCTAssertEqual(hit.time, 0)
        assertEqual(hit.point, Vec2(0, 3))
        XCTAssertEqual(hit.normal, Vec2(0, 1), "the top is the nearest face")
        XCTAssertEqual(sweep.samples, [Vec2(0, 3), Vec2(0, 3)])
    }

    // 21
    func testSamplesEndAtTheHitPoint() throws {
        var sweep = ArcSweep()
        let result = sweep.trace(from: Vec2(0, 50), velocity: Vec2(30, 40), gravity: gravity, halfSize: halfSize,
                                 boxes: [floor])
        let hit = try hit(result)
        XCTAssertEqual(sweep.samples.last, hit.point)
        let secondToLast = sweep.samples[sweep.samples.count - 2]
        XCTAssertGreaterThan(secondToLast.y, hit.point.y, "the step before was still above the floor")
        XCTAssertLessThan(Float(sweep.samples.count - 1) * sweep.dt, hit.time + sweep.dt)
    }

    // 22
    func testASecondTraceStartsFromAnEmptyBuffer() {
        var sweep = ArcSweep()
        sweep.trace(from: .zero, velocity: Vec2(10, 10), gravity: gravity, boxes: [Box](), maxTime: 3)
        let long = sweep.samples.count
        sweep.trace(from: .zero, velocity: Vec2(10, 10), gravity: gravity, boxes: [Box](), maxTime: 1)
        XCTAssertLessThan(sweep.samples.count, long / 2)
        XCTAssertEqual(Float(sweep.samples.count), 61, accuracy: 1.5)
    }
}
