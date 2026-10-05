import XCTest
@testable import LiquidMetal2D

/// The lighting math: visibility outlines around a light, cut by walls.
final class VisibilityPolygonTests: XCTestCase {

    private var polygon = VisibilityPolygon()

    /// Angles of the points around `origin`, unwrapped from the first so a
    /// counter-clockwise outline reads as strictly increasing.
    private func unwrappedAngles(around origin: Vec2 = Vec2()) -> [Float] {
        let first = (polygon.points.first ?? Vec2(1, 0) - origin).angle
        return polygon.points.map { point in
            var angle = (point - origin).angle - first
            if angle < -1e-6 { angle += 2 * .pi }
            return angle
        }
    }

    func testNoWallsIsACircleOf48Points() {
        polygon.compute(from: Vec2(), radius: 10, walls: [])

        XCTAssertEqual(polygon.points.count, 48)
        for point in polygon.points {
            XCTAssertEqual(point.length, 10, accuracy: 1e-4)
        }
        let angles = unwrappedAngles()
        XCTAssertEqual(angles.count, 48)
        for pair in zip(angles, angles.dropFirst()) {
            XCTAssertLessThan(pair.0, pair.1, "counter-clockwise, strictly increasing")
        }
    }

    func testAWallStopsTheRayAndTheOppositeSideStaysOpen() throws {
        let wall = LineSegment(start: Vec2(5, -2), end: Vec2(5, 2))
        polygon.compute(from: Vec2(), radius: 10, walls: [wall])

        let alongX = try XCTUnwrap(polygon.points.first { abs($0.angle) < 1e-5 })
        XCTAssertEqual(alongX.x, 5, accuracy: 1e-4)
        XCTAssertEqual(alongX.y, 0, accuracy: 1e-4)
        let behind = try XCTUnwrap(polygon.points.first { abs(abs($0.angle) - .pi) < 1e-5 })
        XCTAssertEqual(behind.length, 10, accuracy: 1e-4)
    }

    func testCornersGiveASharpShadowEdge() throws {
        let wall = LineSegment(start: Vec2(5, -2), end: Vec2(5, 2))
        polygon.compute(from: Vec2(), radius: 10, walls: [wall])
        let cornerAngle = Vec2(5, 2).angle

        let justBefore = try XCTUnwrap(polygon.points.first { abs($0.angle - (cornerAngle - 1e-4)) < 1e-6 })
        let justAfter = try XCTUnwrap(polygon.points.first { abs($0.angle - (cornerAngle + 1e-4)) < 1e-6 })
        XCTAssertEqual(justBefore.x, 5, accuracy: 1e-3, "still on the wall")
        XCTAssertEqual(justAfter.length, 10, accuracy: 1e-4, "past the corner, out to the radius")
    }

    func testWallsOutOfRangeChangeNothing() {
        var room: [LineSegment] = []
        LineSegment.appendEdges(ofCenter: Vec2(), width: 100, height: 100, to: &room)
        polygon.compute(from: Vec2(), radius: 10, walls: room)
        let withRoom = polygon.points
        polygon.compute(from: Vec2(), radius: 10, walls: [])

        XCTAssertEqual(withRoom, polygon.points)
    }

    func testASmallRoomClipsEveryPointToItsEdges() {
        var room: [LineSegment] = []
        LineSegment.appendEdges(ofCenter: Vec2(), width: 8, height: 6, to: &room)
        polygon.compute(from: Vec2(), radius: 10, walls: room)

        XCTAssertFalse(polygon.points.isEmpty)
        for point in polygon.points {
            let onVertical = abs(abs(point.x) - 4) < 1e-4 && abs(point.y) <= 3 + 1e-4
            let onHorizontal = abs(abs(point.y) - 3) < 1e-4 && abs(point.x) <= 4 + 1e-4
            XCTAssertTrue(onVertical || onHorizontal, "\(point) is not on the room's edge")
        }
    }

    func testInsideASquareTheOutlineHasItsCorners() {
        var room: [LineSegment] = []
        LineSegment.appendEdges(ofCenter: Vec2(1, 1), width: 6, height: 6, to: &room)
        polygon.compute(from: Vec2(1, 1), radius: 20, walls: room)

        for corner in [Vec2(-2, -2), Vec2(4, -2), Vec2(4, 4), Vec2(-2, 4)] {
            XCTAssertTrue(polygon.points.contains { ($0 - corner).length < 1e-3 }, "corner \(corner) missing")
        }
    }

    /// 0.7 rad is not a multiple of the spoke spacing (2π/48), so the edges
    /// must come from the cone itself, not from a spoke that happens to land there.
    func testAConeCoversOnlyItsArc() throws {
        polygon.compute(from: Vec2(), radius: 10, walls: [], direction: 0, halfAngle: 0.7)

        let angles = polygon.points.map { $0.angle }
        XCTAssertEqual(try XCTUnwrap(angles.first), -0.7, accuracy: 1e-5)
        XCTAssertEqual(try XCTUnwrap(angles.last), 0.7, accuracy: 1e-5)
        for angle in angles {
            XCTAssertLessThanOrEqual(abs(angle), 0.7 + 1e-5)
        }
        for pair in zip(angles, angles.dropFirst()) {
            XCTAssertLessThan(pair.0, pair.1)
        }
    }

    func testAWallHalfInsideAConeBlocksOnlyThatHalf() {
        let wall = LineSegment(start: Vec2(5, 0), end: Vec2(5, 8))
        polygon.compute(from: Vec2(), radius: 10, walls: [wall], direction: 0, halfAngle: 0.7)

        for point in polygon.points {
            if point.angle > 1e-3 {
                XCTAssertEqual(point.x, 5, accuracy: 1e-3, "above the axis the wall stops the ray: \(point)")
            } else if point.angle < -1e-3 {
                XCTAssertEqual(point.length, 10, accuracy: 1e-4, "below it the cone is open: \(point)")
            }
        }
    }

    func testAZeroLengthWallIsIgnored() {
        polygon.compute(from: Vec2(), radius: 10, walls: [])
        let open = polygon.points
        polygon.compute(from: Vec2(), radius: 10, walls: [LineSegment(start: Vec2(3, 0), end: Vec2(3, 0))])

        XCTAssertEqual(polygon.points, open)
    }

    func testAWallTouchingTheOriginIsFinite() {
        let wall = LineSegment(start: Vec2(), end: Vec2(5, 0))
        polygon.compute(from: Vec2(), radius: 10, walls: [wall])

        XCTAssertFalse(polygon.points.isEmpty)
        for point in polygon.points {
            XCTAssertTrue(point.x.isFinite && point.y.isFinite, "\(point)")
            XCTAssertLessThanOrEqual(point.length, 10 + 1e-4)
        }
    }

    func testRecomputeKeepsOnlyTheNewResult() {
        let wall = LineSegment(start: Vec2(5, -2), end: Vec2(5, 2))
        polygon.compute(from: Vec2(), radius: 10, walls: [wall])
        XCTAssertEqual(polygon.points.count, 54, "48 spokes + 3 per corner")

        polygon.compute(from: Vec2(100, 100), radius: 10, walls: [wall])

        XCTAssertEqual(polygon.points.count, 48)
        for point in polygon.points {
            XCTAssertEqual((point - Vec2(100, 100)).length, 10, accuracy: 1e-4)
        }
    }
}

final class RaySegmentTests: XCTestCase {

    func testHitsACrossingSegmentAtItsDistance() {
        let t = Intersect.raySegment(origin: Vec2(), direction: Vec2(1, 0), start: Vec2(5, -2), end: Vec2(5, 2))
        XCTAssertEqual(try XCTUnwrap(t), 5, accuracy: 1e-6)
    }

    func testMissesBeyondAnEnd() {
        XCTAssertNil(Intersect.raySegment(origin: Vec2(), direction: Vec2(1, 0), start: Vec2(5, 1), end: Vec2(5, 2)))
    }

    func testParallelIsNil() {
        XCTAssertNil(Intersect.raySegment(origin: Vec2(), direction: Vec2(1, 0), start: Vec2(0, 1), end: Vec2(5, 1)))
        XCTAssertNil(Intersect.raySegment(origin: Vec2(), direction: Vec2(1, 0), start: Vec2(3, 0), end: Vec2(3, 0)),
                     "a zero-length segment blocks nothing")
    }

    func testBehindTheOriginIsNil() {
        XCTAssertNil(Intersect.raySegment(origin: Vec2(), direction: Vec2(1, 0), start: Vec2(-5, -2), end: Vec2(-5, 2)))
    }

    func testAnEndpointCounts() {
        let t = Intersect.raySegment(origin: Vec2(), direction: Vec2(1, 0), start: Vec2(5, 0), end: Vec2(5, 2))
        XCTAssertEqual(try XCTUnwrap(t), 5, accuracy: 1e-6)
    }
}
