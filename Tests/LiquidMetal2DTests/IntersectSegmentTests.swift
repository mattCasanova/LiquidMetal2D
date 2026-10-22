import XCTest
@testable import LiquidMetal2D

/// The segment tests `ArcSweep` is built on (ballistics, 2026-10-22). In
/// their own file: `MathTests.swift` is past the lint file limit already.
final class IntersectSegmentTests: XCTestCase {

    // MARK: Segment vs AABB

    /// A 4 × 2 box centred on the origin: faces at x = ±2, y = ±1.
    private func segmentBox(from start: Vec2, to end: Vec2) -> (t: Float, normal: Vec2)? {
        Intersect.segmentAABB(start: start, end: end, center: Vec2(0, 0), width: 4, height: 2)
    }

    func testSegmentEnteringTheLeftFace() throws {
        let hit = try XCTUnwrap(segmentBox(from: Vec2(-6, 0), to: Vec2(2, 0)))
        XCTAssertEqual(hit.t, 0.5, accuracy: 1e-6, "x = −2 is halfway along")
        XCTAssertEqual(hit.normal, Vec2(-1, 0))
    }

    func testSegmentEnteringTheOtherFaces() throws {
        let top = try XCTUnwrap(segmentBox(from: Vec2(1, 5), to: Vec2(1, -3)))
        XCTAssertEqual(top.t, 0.5, accuracy: 1e-6)
        XCTAssertEqual(top.normal, Vec2(0, 1))
        let right = try XCTUnwrap(segmentBox(from: Vec2(6, 0.5), to: Vec2(0, 0.5)))
        XCTAssertEqual(right.normal, Vec2(1, 0))
        let bottom = try XCTUnwrap(segmentBox(from: Vec2(0, -3), to: Vec2(0, 0)))
        XCTAssertEqual(bottom.normal, Vec2(0, -1))
        // Diagonal in through the left face: the x slab is entered last.
        let diagonal = try XCTUnwrap(segmentBox(from: Vec2(-4, -0.5), to: Vec2(0, 0.5)))
        XCTAssertEqual(diagonal.t, 0.5, accuracy: 1e-6)
        XCTAssertEqual(diagonal.normal, Vec2(-1, 0))
    }

    func testSegmentMissingTheBox() {
        XCTAssertNil(segmentBox(from: Vec2(-6, 3), to: Vec2(6, 3)), "passes above")
        XCTAssertNil(segmentBox(from: Vec2(-6, 0), to: Vec2(-3, 0)), "stops short")
        XCTAssertNil(segmentBox(from: Vec2(3, 0), to: Vec2(6, 0)), "starts past it, heading away")
        XCTAssertNil(segmentBox(from: Vec2(-6, 5), to: Vec2(6, 5)), "parallel to the top, outside")
        XCTAssertNil(segmentBox(from: Vec2(-6, 3), to: Vec2(-3, 0)), "diagonal past the corner")
    }

    func testSegmentStartingInsideReportsTheNearestFace() throws {
        let nearRight = try XCTUnwrap(segmentBox(from: Vec2(1.5, 0), to: Vec2(10, 0)))
        XCTAssertEqual(nearRight.t, 0)
        XCTAssertEqual(nearRight.normal, Vec2(1, 0))
        let nearTop = try XCTUnwrap(segmentBox(from: Vec2(0, 0.8), to: Vec2(0, -10)))
        XCTAssertEqual(nearTop.t, 0)
        XCTAssertEqual(nearTop.normal, Vec2(0, 1))
        let nearBottom = try XCTUnwrap(segmentBox(from: Vec2(0, -0.9), to: Vec2(0, 0)))
        XCTAssertEqual(nearBottom.normal, Vec2(0, -1))
    }

    func testSegmentStartingOnAFaceIsOutside() throws {
        XCTAssertNil(segmentBox(from: Vec2(-2, 0), to: Vec2(-10, 0)), "heading away: a thing resting on the box leaves")
        XCTAssertNil(segmentBox(from: Vec2(0, 1), to: Vec2(3, 1)), "sliding along the top face, off the end")
        let heading = try XCTUnwrap(segmentBox(from: Vec2(-2, 0), to: Vec2(10, 0)), "heading in")
        XCTAssertEqual(heading.t, 0)
        XCTAssertEqual(heading.normal, Vec2(-1, 0))
        let down = try XCTUnwrap(segmentBox(from: Vec2(0.5, 1), to: Vec2(0.5, -5)))
        XCTAssertEqual(down.t, 0)
        XCTAssertEqual(down.normal, Vec2(0, 1))
    }

    func testSegmentEndingOnTheFaceCounts() throws {
        let hit = try XCTUnwrap(segmentBox(from: Vec2(-6, 0), to: Vec2(-2, 0)))
        XCTAssertEqual(hit.t, 1, accuracy: 1e-6)
        XCTAssertEqual(hit.normal, Vec2(-1, 0))
        let corner = try XCTUnwrap(segmentBox(from: Vec2(-4, 3), to: Vec2(0, -1)), "through the top-left corner")
        XCTAssertEqual(corner.t, 0.5, accuracy: 1e-6)
    }

    // MARK: Segment vs Segment

    func testSegmentsCrossing() throws {
        let first = LineSegment(start: Vec2(0, 0), end: Vec2(4, 4))
        let second = LineSegment(start: Vec2(0, 2), end: Vec2(4, 2))
        XCTAssertEqual(try XCTUnwrap(Intersect.segmentSegment(first, second)), 0.5, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(Intersect.segmentSegment(second, first)), 0.5, accuracy: 1e-6)
        XCTAssertNil(Intersect.segmentSegment(first, LineSegment(start: Vec2(0, 5), end: Vec2(4, 5))), "beyond the end")
        XCTAssertNil(Intersect.segmentSegment(first, LineSegment(start: Vec2(3, 2), end: Vec2(4, 2))), "too short")
    }

    func testParallelAndCollinearSegmentsDoNotCross() {
        let first = LineSegment(start: Vec2(0, 0), end: Vec2(4, 0))
        XCTAssertNil(Intersect.segmentSegment(first, LineSegment(start: Vec2(0, 1), end: Vec2(4, 1))))
        XCTAssertNil(Intersect.segmentSegment(first, LineSegment(start: Vec2(2, 0), end: Vec2(6, 0))),
                     "collinear overlap has no single crossing")
    }

    func testSegmentsTouchingAtAnEndpointCount() throws {
        let first = LineSegment(start: Vec2(0, 0), end: Vec2(4, 0))
        let atEnd = try XCTUnwrap(Intersect.segmentSegment(first, LineSegment(start: Vec2(4, -1), end: Vec2(4, 1))))
        XCTAssertEqual(atEnd, 1)
        let atTip = try XCTUnwrap(Intersect.segmentSegment(first, LineSegment(start: Vec2(2, 0), end: Vec2(2, 3))))
        XCTAssertEqual(atTip, 0.5)
    }
}
