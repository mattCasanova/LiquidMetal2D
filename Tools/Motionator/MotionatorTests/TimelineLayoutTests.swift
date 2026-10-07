import XCTest
@testable import Motionator

final class TimelineLayoutTests: XCTestCase {

    private let layout = TimelineLayout(width: 740, duration: 2)

    func testTimeAndXRoundTrip() {
        for time: Float in [0, 0.5, 1.25, 2] {
            XCTAssertEqual(layout.time(for: layout.x(for: time)), time, accuracy: 1e-4)
        }
        XCTAssertEqual(layout.x(for: 0), TimelineLayout.labelWidth)
        XCTAssertEqual(layout.x(for: 2), 740 - TimelineLayout.rightMargin)
        XCTAssertEqual(layout.time(for: -50), 0, "clamped before the start")
        XCTAssertEqual(layout.time(for: 10_000), 2, "clamped past the end")
    }

    func testHitsFindTheRulerEventsRowsAndHandle() {
        XCTAssertEqual(layout.hit(CGPoint(x: 300, y: 5), rows: 3), .ruler)
        XCTAssertEqual(layout.hit(CGPoint(x: layout.x(for: 2) + 2, y: 5), rows: 3), .durationHandle)
        XCTAssertEqual(layout.hit(CGPoint(x: 300, y: TimelineLayout.rulerHeight + 4), rows: 3), .events)
        XCTAssertEqual(layout.hit(CGPoint(x: 300, y: layout.rowY(1) + 3), rows: 3), .bone(1))
        XCTAssertEqual(layout.hit(CGPoint(x: 300, y: layout.rowY(3) + 3), rows: 3), .none, "past the last row")
        XCTAssertEqual(layout.hit(CGPoint(x: 20, y: layout.rowY(0) + 3), rows: 3), .labels)
    }

    func testTickStepKeepsLabelsAbout60PointsApart() {
        for duration: Float in [0.4, 1, 3, 10] {
            let layout = TimelineLayout(width: 740, duration: duration)
            let spacing = CGFloat(layout.tickStep / duration) * layout.trackWidth
            XCTAssertGreaterThanOrEqual(spacing, 60, "duration \(duration)")
            XCTAssertLessThan(spacing, 60 * 2.6, "duration \(duration): the next step down would fit")
        }
        XCTAssertGreaterThan(TimelineLayout(width: 740, duration: 10).tickStep,
                             TimelineLayout(width: 740, duration: 1).tickStep)
    }
}
