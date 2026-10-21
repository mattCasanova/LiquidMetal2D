import XCTest
@testable import LiquidMetal2D

/// The closed-form formulas: a y-up world with gravity (0, −400) unless a test says otherwise.
final class BallisticsTests: XCTestCase {
    private let gravity = Vec2(0, -400)
    private let start = Vec2(10, 20)

    private func assertEqual(_ a: Vec2, _ b: Vec2, accuracy: Float = 1e-3, _ message: String = "",
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: accuracy, "x: \(message)", file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: accuracy, "y: \(message)", file: file, line: line)
    }

    // 1
    func testPositionAndVelocityAtZeroAreTheLaunchValues() {
        let velocity = Vec2(120, 300)
        assertEqual(Ballistics.position(start: start, velocity: velocity, gravity: gravity, at: 0), start)
        assertEqual(Ballistics.velocity(velocity, gravity: gravity, at: 0), velocity)
        // One second on: p = p0 + v + ½g, v = v0 + g.
        assertEqual(Ballistics.position(start: start, velocity: velocity, gravity: gravity, at: 1), Vec2(130, 120))
        assertEqual(Ballistics.velocity(velocity, gravity: gravity, at: 1), Vec2(120, -100))
    }

    // 2
    func testApexTimeAndHeight() {
        let velocity = Vec2(50, 200)
        XCTAssertEqual(Ballistics.apexTime(velocity: velocity, gravity: gravity), 0.5, accuracy: 1e-6)
        let apex = Ballistics.apex(start: start, velocity: velocity, gravity: gravity)
        XCTAssertEqual(apex.y, start.y + 200 * 200 / (2 * 400), accuracy: 1e-3)
        XCTAssertEqual(apex.x, start.x + 50 * 0.5, accuracy: 1e-3)

        XCTAssertEqual(Ballistics.apexTime(velocity: Vec2(50, -200), gravity: gravity), 0, "already falling")
        assertEqual(Ballistics.apex(start: start, velocity: Vec2(50, -200), gravity: gravity), start)
        XCTAssertEqual(Ballistics.apexTime(velocity: Vec2(0, 0), gravity: gravity), 0)
    }

    // 3
    func testTimesAtAHeight() throws {
        let velocity = Vec2(50, 200)
        let atStart = Ballistics.times(atHeight: start.y, start: start, velocity: velocity, gravity: gravity)
        XCTAssertEqual(atStart.0, 0)
        XCTAssertEqual(try XCTUnwrap(atStart.1), 2 * 0.5, accuracy: 1e-6)

        let apexY = Ballistics.apex(start: start, velocity: velocity, gravity: gravity).y
        let above = Ballistics.times(atHeight: apexY + 1, start: start, velocity: velocity, gravity: gravity)
        XCTAssertNil(above.0)
        XCTAssertNil(above.1)

        let below = Ballistics.times(atHeight: start.y - 30, start: start, velocity: velocity, gravity: gravity)
        let landing = try XCTUnwrap(below.0)
        XCTAssertNil(below.1, "the other crossing is before the launch")
        XCTAssertEqual(Ballistics.position(start: start, velocity: velocity, gravity: gravity, at: landing).y,
                       start.y - 30, accuracy: 1e-3)

        let halfway = Ballistics.times(atHeight: start.y + 25, start: start, velocity: velocity, gravity: gravity)
        let up = try XCTUnwrap(halfway.0)
        let down = try XCTUnwrap(halfway.1)
        XCTAssertLessThan(up, down)
        XCTAssertEqual(up + down, 1, accuracy: 1e-5, "symmetric about the apex")

        let falling = Ballistics.times(atHeight: start.y - 10, start: start, velocity: Vec2(0, -5), gravity: gravity)
        XCTAssertNotNil(falling.0)
        XCTAssertNil(falling.1)
    }

    // 4
    func testTimeAtAnX() throws {
        let ahead = try XCTUnwrap(Ballistics.time(atX: 60, start: start, velocity: Vec2(25, 100)))
        XCTAssertEqual(ahead, 2, accuracy: 1e-6)
        XCTAssertNil(Ballistics.time(atX: 60, start: start, velocity: Vec2(0, 100)), "no sideways motion")
        XCTAssertNil(Ballistics.time(atX: 0, start: start, velocity: Vec2(25, 100)), "behind the start")
        XCTAssertEqual(Ballistics.time(atX: 0, start: start, velocity: Vec2(-25, 100)), 0.4)
        XCTAssertEqual(Ballistics.time(atX: start.x, start: start, velocity: Vec2(25, 100)), 0)
    }

    // 5
    func testLaunchVelocityAtASpeedPassesThroughTheTargetOnBothArcs() throws {
        // Within reach: at speed 200 and gravity 400 the flat range is v²/g = 100.
        let target = Vec2(70, 30)
        for (highArc, flipped) in [(false, false), (true, false), (false, true), (true, true)] {
            let gravity = flipped ? Vec2(0, 400) : self.gravity
            let target = flipped ? Vec2(target.x, -target.y) : target
            let start = flipped ? Vec2(self.start.x, -self.start.y) : self.start
            let velocity = try XCTUnwrap(
                Ballistics.launchVelocity(from: start, to: target, speed: 200, gravity: gravity, highArc: highArc),
                "high \(highArc) flipped \(flipped)")
            XCTAssertEqual(velocity.length, 200, accuracy: 1e-3)
            let t = try XCTUnwrap(Ballistics.time(atX: target.x, start: start, velocity: velocity))
            assertEqual(Ballistics.position(start: start, velocity: velocity, gravity: gravity, at: t), target,
                        "high \(highArc) flipped \(flipped)")
            if highArc {
                XCTAssertGreaterThan(velocity.y * (flipped ? -1 : 1), 0, "the lob goes up first")
            }
        }
        let low = try XCTUnwrap(Ballistics.launchVelocity(from: start, to: target, speed: 200, gravity: gravity))
        let high = try XCTUnwrap(Ballistics.launchVelocity(from: start, to: target, speed: 200, gravity: gravity,
                                                            highArc: true))
        XCTAssertGreaterThan(high.y, low.y)

        // Behind the start: the velocity points left.
        let back = try XCTUnwrap(
            Ballistics.launchVelocity(from: start, to: Vec2(-50, 30), speed: 200, gravity: gravity))
        XCTAssertLessThan(back.x, 0)
        let tBack = try XCTUnwrap(Ballistics.time(atX: -50, start: start, velocity: back))
        assertEqual(Ballistics.position(start: start, velocity: back, gravity: gravity, at: tBack), Vec2(-50, 30))

        // Straight up: reachable while the apex is high enough.
        let up = try XCTUnwrap(Ballistics.launchVelocity(from: start, to: Vec2(start.x, start.y + 40), speed: 200,
                                                          gravity: gravity))
        assertEqual(up, Vec2(0, 200))
        XCTAssertNil(
            Ballistics.launchVelocity(from: start, to: Vec2(start.x, start.y + 51), speed: 200, gravity: gravity))
    }

    // 6
    func testLaunchVelocityAtASpeedIsNilOutOfRange() {
        XCTAssertNil(Ballistics.launchVelocity(from: start, to: Vec2(1000, 20), speed: 200, gravity: gravity))
        XCTAssertNotNil(Ballistics.launchVelocity(from: start, to: Vec2(109, 20), speed: 200, gravity: gravity),
                        "just inside the range v²/g = 100")
        XCTAssertNil(Ballistics.launchVelocity(from: start, to: Vec2(111, 20), speed: 200, gravity: gravity),
                     "just past it")
    }

    // 7
    func testLaunchVelocityWithAnApexHeightPassesThroughTheTarget() throws {
        let target = Vec2(90, 40)
        let velocity = try XCTUnwrap(
            Ballistics.launchVelocity(from: start, to: target, apexHeight: 30, gravity: gravity))
        let apex = Ballistics.apex(start: start, velocity: velocity, gravity: gravity)
        XCTAssertEqual(apex.y, start.y + 30, accuracy: 1e-3)
        let t = try XCTUnwrap(Ballistics.time(atX: target.x, start: start, velocity: velocity))
        assertEqual(Ballistics.position(start: start, velocity: velocity, gravity: gravity, at: t), target)

        XCTAssertNil(
            Ballistics.launchVelocity(from: start, to: Vec2(90, start.y + 31), apexHeight: 30, gravity: gravity),
            "the target is above the apex")
        let atApex = try XCTUnwrap(Ballistics.launchVelocity(from: start, to: Vec2(90, start.y + 30), apexHeight: 30,
                                                              gravity: gravity))
        assertEqual(Ballistics.apex(start: start, velocity: atApex, gravity: gravity), Vec2(90, start.y + 30))

        // Upside down: the apex is 30 below the start, against gravity.
        let flipped = try XCTUnwrap(Ballistics.launchVelocity(from: start, to: Vec2(90, 0), apexHeight: 30,
                                                               gravity: Vec2(0, 400)))
        XCTAssertLessThan(flipped.y, 0)
        let tFlipped = try XCTUnwrap(Ballistics.time(atX: 90, start: start, velocity: flipped))
        assertEqual(Ballistics.position(start: start, velocity: flipped, gravity: Vec2(0, 400), at: tFlipped),
                    Vec2(90, 0))
    }

    // 8
    func testLaunchVelocityInATimeLandsOnTheTarget() {
        let target = Vec2(-30, 95)
        let velocity = Ballistics.launchVelocity(from: start, to: target, time: 0.75, gravity: gravity)
        assertEqual(Ballistics.position(start: start, velocity: velocity, gravity: gravity, at: 0.75), target)
        let sideways = Ballistics.launchVelocity(from: start, to: target, time: 2, gravity: Vec2(-50, 30))
        assertEqual(Ballistics.position(start: start, velocity: sideways, gravity: Vec2(-50, 30), at: 2), target)
    }

    // 9
    func testSidewaysGravityKeepsTheVectorFormulas() {
        let gravity = Vec2(-300, 0)
        let velocity = Vec2(100, 40)
        assertEqual(Ballistics.position(start: start, velocity: velocity, gravity: gravity, at: 2),
                    start + velocity * 2 + gravity * 2)
        assertEqual(Ballistics.velocity(velocity, gravity: gravity, at: 2), Vec2(-500, 40))
    }
}
