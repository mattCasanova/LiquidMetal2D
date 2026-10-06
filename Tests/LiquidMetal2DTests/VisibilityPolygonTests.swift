import XCTest
@testable import LiquidMetal2D

/// The lighting math: visibility outlines around a light, cut by walls.
final class VisibilityPolygonTests: XCTestCase {

    private var polygon = VisibilityPolygon()

    /// Angles of the points around `origin`, unwrapped from the first so a
    /// counter-clockwise outline reads as strictly increasing.
    private func unwrappedAngles(around origin: Vec2 = Vec2()) -> [Float] {
        let first = ((polygon.points.first ?? Vec2(1, 0)) - origin).angle
        return polygon.points.map { point in
            var angle = (point - origin).angle - first
            if angle < -1e-6 { angle += 2 * .pi }
            return angle
        }
    }

    private func assertCounterClockwise(
        around origin: Vec2 = Vec2(), file: StaticString = #filePath, line: UInt = #line
    ) {
        let angles = unwrappedAngles(around: origin)
        for pair in zip(angles, angles.dropFirst()) {
            XCTAssertLessThan(pair.0, pair.1, "counter-clockwise, strictly increasing", file: file, line: line)
        }
    }

    /// The area a light map would draw: a fan of triangles from `origin`.
    private func fanArea(around origin: Vec2 = Vec2()) -> Float {
        var twice: Float = 0
        for (a, b) in zip(polygon.points, polygon.points.dropFirst() + [polygon.points[0]]) {
            twice += (a - origin).cross(b - origin)
        }
        return abs(twice) / 2
    }

    /// A 48-gon's area: what `fanArea` gives for an open disc.
    private static func discArea(radius: Float) -> Float { 24 * radius * radius * sin(2 * .pi / 48) }

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
        assertCounterClockwise()
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
        assertCounterClockwise()
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

        XCTAssertFalse(polygon.points.isEmpty)
        for point in polygon.points {
            if point.angle > 1e-3 {
                XCTAssertEqual(point.x, 5, accuracy: 1e-3, "above the axis the wall stops the ray: \(point)")
            } else if point.angle < -1e-3 {
                XCTAssertEqual(point.length, 10, accuracy: 1e-4, "below it the cone is open: \(point)")
            }
        }
    }

    /// The demo's guard cone sweeps across ±π: the sweep's relative angles
    /// must wrap, or the outline comes out in the wrong order.
    func testAConeAcrossThePiSeamStaysInOrder() {
        let wall = LineSegment(start: Vec2(-5, 0), end: Vec2(-5, 8))
        polygon.compute(from: Vec2(), radius: 10, walls: [wall], direction: .pi, halfAngle: 0.7)

        XCTAssertFalse(polygon.points.isEmpty)
        for point in polygon.points {
            if point.angle > 0 && point.angle < .pi - 1e-3 {
                XCTAssertEqual(point.x, -5, accuracy: 1e-3, "above the axis the wall stops the ray: \(point)")
            } else if point.angle < 0 && point.angle > -.pi + 1e-3 {
                XCTAssertEqual(point.length, 10, accuracy: 1e-4, "below it the cone is open: \(point)")
            }
        }
        assertCounterClockwise()
        XCTAssertEqual(try XCTUnwrap(polygon.points.first).angle, .pi - 0.7, accuracy: 1e-5)
        XCTAssertEqual(try XCTUnwrap(polygon.points.last).angle, -.pi + 0.7, accuracy: 1e-5)
    }

    func testAZeroLengthWallIsIgnored() {
        polygon.compute(from: Vec2(), radius: 10, walls: [])
        let open = polygon.points
        polygon.compute(from: Vec2(), radius: 10, walls: [LineSegment(start: Vec2(3, 0), end: Vec2(3, 0))])

        XCTAssertEqual(polygon.points, open)
    }

    /// A lamp on a box's bottom edge lights everything below the edge and
    /// nothing inside the box: a half disc, like a lamp a hair outside.
    func testALampOnABoxEdgeSeesOutwardOnly() throws {
        var box: [LineSegment] = []
        LineSegment.appendEdges(ofCenter: Vec2(0, 5), width: 10, height: 10, to: &box)
        polygon.compute(from: Vec2(), radius: 10, walls: box)

        let down = try XCTUnwrap(polygon.points.first { abs($0.angle + .pi / 2) < 1e-5 })
        XCTAssertEqual(down.length, 10, accuracy: 1e-4, "away from the box, out to the radius")
        XCTAssertTrue(polygon.points.contains { $0.length < 1e-4 }, "into the box, stopped at once")
        for point in polygon.points where point.y > 1e-4 {
            XCTFail("\(point) is inside the box")
        }
        XCTAssertEqual(fanArea(), Self.discArea(radius: 10) / 2, accuracy: 0.5, "a half disc")
    }

    /// A lamp a hair outside the line gets the same half disc through the
    /// ray casts: nothing jumps as a lamp slides onto a wall.
    func testALampAHairOffABoxEdgeSeesTheSameHalfDisc() {
        var box: [LineSegment] = []
        LineSegment.appendEdges(ofCenter: Vec2(0, 5), width: 10, height: 10, to: &box)
        for offset in [Float(2e-3), 1e-2, 0.1] {
            let origin = Vec2(0, -offset)
            polygon.compute(from: origin, radius: 10, walls: box)
            // The sliver between the edge and the lamp, and a sector either
            // side of the edge where the grazing rays land, is all that can differ.
            XCTAssertEqual(fanArea(around: origin), Self.discArea(radius: 10) / 2, accuracy: 8, "offset \(offset)")
        }
    }

    func testALampOnABoxCornerSeesThreeQuarters() throws {
        var box: [LineSegment] = []
        LineSegment.appendEdges(ofCenter: Vec2(5, 5), width: 10, height: 10, to: &box)
        polygon.compute(from: Vec2(), radius: 10, walls: box)

        let intoTheBox = try XCTUnwrap(polygon.points.first { $0.length < 1e-4 })
        XCTAssertEqual(intoTheBox.length, 0, accuracy: 1e-4)
        let away = try XCTUnwrap(polygon.points.first { abs($0.angle + 3 * .pi / 4) < 1e-5 })
        XCTAssertEqual(away.length, 10, accuracy: 1e-4)
        XCTAssertEqual(fanArea(), Self.discArea(radius: 10) * 3 / 4, accuracy: 0.5, "three quarters of the disc")
    }

    func testAGuardWithItsBackToAWallStillSees() {
        var box: [LineSegment] = []
        LineSegment.appendEdges(ofCenter: Vec2(0, 5), width: 10, height: 10, to: &box)
        polygon.compute(from: Vec2(), radius: 10, walls: box, direction: -.pi / 2, halfAngle: 0.45)

        XCTAssertFalse(polygon.points.isEmpty)
        for point in polygon.points {
            XCTAssertEqual(point.length, 10, accuracy: 1e-4, "the whole cone is open: \(point)")
        }
    }

    func testRadiusZeroIsNoOutline() {
        polygon.compute(from: Vec2(), radius: 10, walls: [])
        polygon.compute(from: Vec2(), radius: 0, walls: [])

        XCTAssertTrue(polygon.points.isEmpty)
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
