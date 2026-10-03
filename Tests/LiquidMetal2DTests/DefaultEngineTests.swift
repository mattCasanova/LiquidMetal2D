import QuartzCore
import XCTest
#if canImport(AppKit) && !canImport(UIKit)
import AppKit
#endif
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

    func testShutdownRunsOnce() throws {
        let (engine, _) = try makeEngine()
        engine.run()
        let scene = try XCTUnwrap(RecordingScene.current)

        engine.shutdown()
        engine.shutdown()

        XCTAssertEqual(scene.shutdowns, 1, "the window, SwiftUI and the app quitting can each ask")
    }

    #if canImport(AppKit) && !canImport(UIKit)
    func testAppQuittingShutsTheEngineDown() throws {
        let (engine, clock) = try makeEngine()
        engine.run()
        let scene = try XCTUnwrap(RecordingScene.current)

        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)

        XCTAssertEqual(scene.shutdowns, 1, "every quit path saves through scene shutdown")
        XCTAssertFalse(clock.isRunning)
        engine.shutdown()
        XCTAssertEqual(scene.shutdowns, 1)
    }
    #endif

    func testShutdownStopsTheClockAndTheScene() throws {
        let (engine, clock) = try makeEngine()
        engine.run()
        XCTAssertTrue(clock.isRunning)

        engine.shutdown()

        XCTAssertFalse(clock.isRunning)
        XCTAssertTrue(RecordingScene.current.isShutDown)
    }

    // MARK: - App state

    func testInactiveFreezesTheLoopByDefault() throws {
        let (engine, clock) = try makeEngine()
        engine.run()

        engine.appStateDidChange(to: .inactive)

        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(RecordingScene.current.states, [.inactive])
        XCTAssertEqual(RecordingScene.current.updates, [])
        engine.shutdown()
    }

    func testInactiveKeepsRunningWhenTheGameSaysSo() throws {
        let (engine, clock) = try makeEngine(pausesWhenInactive: false)
        engine.run()

        engine.appStateDidChange(to: .inactive)
        clock.advance(by: 1.0 / 60)

        XCTAssertTrue(clock.isRunning)
        XCTAssertEqual(RecordingScene.current.updates, [1.0 / 60])
        engine.shutdown()
    }

    func testBackgroundAlwaysFreezes() throws {
        let (engine, clock) = try makeEngine(pausesWhenInactive: false)
        engine.run()

        engine.appStateDidChange(to: .background)

        XCTAssertFalse(clock.isRunning, "no GPU work in the background, whatever the game asked")
        engine.shutdown()
    }

    func testFirstFrameBackIsMeasuredFromTheReturn() throws {
        let (engine, clock) = try makeEngine()
        engine.run()
        clock.advance(by: 1.0 / 60)

        engine.appStateDidChange(to: .inactive)
        clock.skip(by: 10)
        engine.appStateDidChange(to: .active)
        clock.advance(by: 1.0 / 60)

        XCTAssertTrue(clock.isRunning)
        XCTAssertEqual(RecordingScene.current.updates, [1.0 / 60, 1.0 / 60], "no jump for the time away")
        engine.shutdown()
    }

    func testFirstFrameBackFromTheBackgroundIsMeasuredFromTheReturn() throws {
        let (engine, clock) = try makeEngine(pausesWhenInactive: false)
        engine.run()

        engine.appStateDidChange(to: .background)
        clock.skip(by: 10)
        engine.appStateDidChange(to: .active)
        clock.advance(by: 1.0 / 60)

        XCTAssertEqual(RecordingScene.current.updates, [1.0 / 60])
        engine.shutdown()
    }

    func testTransitionAskedForOnInactiveHappensAtOnce() throws {
        let (engine, clock) = try makeEngine(initial: .pusher)
        engine.run()
        let pusher = try XCTUnwrap(RecordingScene.current)

        engine.appStateDidChange(to: .inactive)

        XCTAssertFalse(clock.isRunning)
        XCTAssertTrue(RecordingScene.current is SecondScene, "the pause scene is up while the player is away")
        XCTAssertFalse(pusher.isShutDown, "a push keeps the scene below")
        engine.shutdown()
    }

    func testInputQueuedWhileLeavingNeverReachesThePushedScene() throws {
        let (engine, clock) = try makeEngine(initial: .pusher)
        engine.run()
        engine.enqueue(.down(.pointerPrimary))
        engine.appStateDidChange(to: .inactive)
        engine.enqueue(.focusLost)
        engine.appStateDidChange(to: .active)

        clock.advance(by: 1.0 / 60)
        clock.advance(by: 1.0 / 60)

        let pause = try XCTUnwrap(RecordingScene.current as? SecondScene)
        XCTAssertEqual(pause.eventCounts, [], "the release that ended the leave is dropped, as on a transition frame")
        XCTAssertEqual(pause.releasedAtUpdates, [false], "a pause scene resuming on release must not resume at once")
        engine.shutdown()
    }

    func testTheSameStateTwiceIsDeliveredOnce() throws {
        let (engine, _) = try makeEngine()
        engine.run()

        engine.appStateDidChange(to: .inactive)
        engine.appStateDidChange(to: .inactive)
        engine.appStateDidChange(to: .active)
        engine.appStateDidChange(to: .active)

        XCTAssertEqual(RecordingScene.current.states, [.inactive, .active])
        engine.shutdown()
    }

    func testAppObserversHearBeforeTheScene() throws {
        let (engine, _) = try makeEngine()
        engine.run()
        let observer = RecordingObserver()
        var released: RecordingObserver? = RecordingObserver()
        engine.addAppStateObserver(observer)
        engine.addAppStateObserver(try XCTUnwrap(released))
        released = nil

        engine.appStateDidChange(to: .background)

        XCTAssertEqual(AppStateLog.entries, ["observer background", "scene background"])
        engine.shutdown()
    }

    func testRemovedObserverHearsNothing() throws {
        let (engine, _) = try makeEngine()
        let observer = RecordingObserver()
        engine.addAppStateObserver(observer)

        engine.removeAppStateObserver(observer)
        engine.appStateDidChange(to: .inactive)

        XCTAssertEqual(AppStateLog.entries, ["scene inactive"])
        engine.shutdown()
    }

    func testNothingHappensAfterShutdown() throws {
        let (engine, clock) = try makeEngine()
        engine.run()
        engine.appStateDidChange(to: .background)
        let scene = try XCTUnwrap(RecordingScene.current)
        engine.shutdown()

        engine.appStateDidChange(to: .active)

        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(scene.states, [.background])
        XCTAssertEqual(engine.appState, .background, "a shut-down engine stops tracking")
    }

    func testRunWaitsForAStateThatAllowsFrames() throws {
        let (engine, clock) = try makeEngine()

        engine.appStateDidChange(to: .inactive)
        XCTAssertFalse(clock.isRunning, "a change before run() starts nothing")
        engine.run()
        XCTAssertFalse(clock.isRunning, "run() while frozen waits")
        engine.appStateDidChange(to: .active)

        XCTAssertTrue(clock.isRunning)
        engine.shutdown()
    }

    func testDisplayLinkClockReadsNowBeforeItsFirstFrame() {
        let clock = DisplayLinkClock(view: PlatformView())
        clock.start {}

        XCTAssertEqual(clock.timestamp, CACurrentMediaTime(), accuracy: 1,
                       "not 0, or the first frame after a start is clamped")
        clock.stop()
    }

    /// An engine on the real renderer (the shader tests' bare view) and a
    /// fake clock. Skips on a host with no Metal device.
    private func makeEngine(
        initial: TestScenes = .first, pausesWhenInactive: Bool = true
    ) throws -> (DefaultEngine, FakeClock) {
        _ = try ShaderTestSupport.makeDevice()
        AppStateLog.entries = []
        let factory = SceneFactory()
        factory.addScenes([RecordingScene.self, SecondScene.self, PushingScene.self])
        let clock = FakeClock()
        let engine = DefaultEngine(
            renderer: DefaultRenderer(parentView: PlatformView(), maxObjects: 1),
            documents: DocumentIO(presentingVC: PlatformViewController()),
            pausesWhenInactive: pausesWhenInactive,
            initialSceneType: initial,
            sceneFactory: factory,
            clock: clock)
        return (engine, clock)
    }
}

private enum TestScenes: SceneType {
    case first, second, pusher
}

/// Shared by the observer and the scenes so a test sees who heard first.
@MainActor
private enum AppStateLog {
    static var entries: [String] = []
}

@MainActor
private final class RecordingObserver: AppStateObserver {
    func appStateChanged(to state: AppState) {
        AppStateLog.entries.append("observer \(state)")
    }
}

/// Records every `update(dt:)`; draws nothing, so no pass is needed.
@MainActor
private class RecordingScene: DefaultScene {
    /// The most recently built instance, since the factory builds scenes itself.
    static var current: RecordingScene!

    private(set) var updates: [Float] = []
    private(set) var eventCounts: [Int] = []
    private(set) var releasedAtUpdates: [Bool] = []
    private(set) var states: [AppState] = []
    private(set) var draws = 0
    private(set) var isShutDown = false
    private(set) var shutdowns = 0

    override class var sceneType: any SceneType { TestScenes.first }

    required init() {
        super.init()
        RecordingScene.current = self
    }

    override func update(dt: Float) {
        updates.append(dt)
        releasedAtUpdates.append(input.isReleased(.pointerPrimary))
    }

    override func deliverInput(_ events: [InputEvent]) {
        eventCounts.append(events.count)
        super.deliverInput(events)
    }

    override func draw() {
        draws += 1
    }

    override func appStateChanged(to state: AppState) {
        states.append(state)
        AppStateLog.entries.append("scene \(state)")
    }

    override func shutdown() {
        isShutDown = true
        shutdowns += 1
        super.shutdown()
    }
}

@MainActor
private final class SecondScene: RecordingScene {
    override static var sceneType: any SceneType { TestScenes.second }
}

/// Pushes the second scene when the app goes inactive, as a game pushes its
/// pause scene.
@MainActor
private final class PushingScene: RecordingScene {
    override static var sceneType: any SceneType { TestScenes.pusher }

    override func appStateChanged(to state: AppState) {
        super.appStateChanged(to: state)
        if state == .inactive {
            sceneMgr.pushScene(type: TestScenes.second)
        }
    }
}
