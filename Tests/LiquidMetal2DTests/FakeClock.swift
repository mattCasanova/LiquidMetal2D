import XCTest
@testable import LiquidMetal2D

/// Fires the frame callback when a test says so.
@MainActor
final class FakeClock: FrameClock {
    private(set) var timestamp: Double = 100
    private var onFrame: (@MainActor () -> Void)?
    var isRunning: Bool { onFrame != nil }

    func start(onFrame: @escaping @MainActor () -> Void) {
        self.onFrame = onFrame
    }

    func stop() {
        onFrame = nil
    }

    /// Moves time forward and fires one frame.
    func advance(by seconds: Double) {
        timestamp += seconds
        guard let onFrame else {
            XCTFail("FakeClock.advance called before start()")
            return
        }
        onFrame()
    }
}
