import XCTest
@testable import LiquidMetal2D

/// The engine loop, stepped by a fake clock: no display link, no window.
@MainActor
final class DefaultEngineTests: XCTestCase {

    func testFrameUpdatesTheSceneByTheClockDelta() throws {
        let (engine, clock) = try makeEngine()
        engine.run()

        clock.advance(by: 1.0 / 60)
        clock.advance(by: 1.0 / 30)

        XCTAssertEqual(RecordingScene.current.updates, [1.0 / 60, 1.0 / 30])
        XCTAssertEqual(RecordingScene.current.draws, 2, "every updated frame is drawn")
        engine.shutdown()
    }

    func testLongFrameIsClampedToMaxFrameTime() throws {
        let (engine, clock) = try makeEngine()
        engine.run()

        clock.advance(by: 5)

        XCTAssertEqual(RecordingScene.current.updates, [1.0 / 15])
        engine.shutdown()
    }

    func testFrameWithNoElapsedTimeIsSkipped() throws {
        let (engine, clock) = try makeEngine()
        engine.run()

        clock.advance(by: 0)

        XCTAssertEqual(RecordingScene.current.updates, [])
        XCTAssertEqual(RecordingScene.current.draws, 0)
        engine.shutdown()
    }

    func testPendingTransitionTakesTheFrameInsteadOfUpdate() throws {
        let (engine, clock) = try makeEngine()
        engine.run()
        let first = try XCTUnwrap(RecordingScene.current)
        engine.sceneManager.setScene(type: TestScenes.second)

        clock.advance(by: 1.0 / 60)

        XCTAssertEqual(first.updates, [])
        XCTAssertTrue(first.isShutDown)
        XCTAssertTrue(RecordingScene.current !== first)
        XCTAssertEqual(RecordingScene.current.updates, [])
        clock.advance(by: 1.0 / 60)
        XCTAssertEqual(RecordingScene.current.updates, [1.0 / 60])
        engine.shutdown()
    }

    func testShutdownStopsTheClockAndTheScene() throws {
        let (engine, clock) = try makeEngine()
        engine.run()
        XCTAssertTrue(clock.isRunning)

        engine.shutdown()

        XCTAssertFalse(clock.isRunning)
        XCTAssertTrue(RecordingScene.current.isShutDown)
    }

    /// An engine on the real renderer (the shader tests' bare view) and a
    /// fake clock. Skips on a host with no Metal device.
    private func makeEngine() throws -> (DefaultEngine, FakeClock) {
        _ = try ShaderTestSupport.makeDevice()
        let factory = SceneFactory()
        factory.addScenes([RecordingScene.self, SecondScene.self])
        let clock = FakeClock()
        let engine = DefaultEngine(
            renderer: DefaultRenderer(parentView: PlatformView(), maxObjects: 1),
            documents: DocumentIO(presentingVC: PlatformViewController()),
            initialSceneType: TestScenes.first,
            sceneFactory: factory,
            clock: clock)
        return (engine, clock)
    }
}

/// Fires the frame callback when a test says so.
@MainActor
private final class FakeClock: FrameClock {
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

private enum TestScenes: SceneType {
    case first, second
}

/// Records every `update(dt:)`; draws nothing, so no pass is needed.
@MainActor
private class RecordingScene: DefaultScene {
    /// The most recently built instance, since the factory builds scenes itself.
    static var current: RecordingScene!

    private(set) var updates: [Float] = []
    private(set) var draws = 0
    private(set) var isShutDown = false

    override class var sceneType: any SceneType { TestScenes.first }

    required init() {
        super.init()
        RecordingScene.current = self
    }

    override func update(dt: Float) {
        updates.append(dt)
    }

    override func draw() {
        draws += 1
    }

    override func shutdown() {
        isShutDown = true
        super.shutdown()
    }
}

@MainActor
private final class SecondScene: RecordingScene {
    override static var sceneType: any SceneType { TestScenes.second }
}
