import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@testable import LiquidMetal2D

/// The platform rules behind ``AppState``, and the notifications reaching a
/// real engine through its ``AppStateSource``.
@MainActor
final class AppStateSourceTests: XCTestCase {

    #if canImport(UIKit)
    func testEachNotificationMeansItsState() {
        let table = Dictionary(uniqueKeysWithValues: AppStateSource.transitions.map { ($0.name, $0.state) })

        XCTAssertEqual(table[UIApplication.willResignActiveNotification], .inactive)
        XCTAssertEqual(table[UIApplication.didEnterBackgroundNotification], .background)
        XCTAssertEqual(table[UIApplication.willEnterForegroundNotification], .inactive)
        XCTAssertEqual(table[UIApplication.didBecomeActiveNotification], .active)
        XCTAssertEqual(table.count, 4)
    }

    func testNotificationsReachTheEngine() throws {
        let (engine, clock) = try makeEngine(view: UIView())
        engine.run()

        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertEqual(engine.appState, .inactive)
        XCTAssertFalse(clock.isRunning)

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(engine.appState, .active)
        XCTAssertTrue(clock.isRunning)
        engine.shutdown()
    }

    #elseif canImport(AppKit)
    func testActiveAppWithItsWindowKeyIsActive() {
        XCTAssertEqual(state(active: true, hidden: false, key: true, minimised: false), .active)
    }

    func testLosingTheAppOrTheWindowFocusIsInactive() {
        XCTAssertEqual(state(active: true, hidden: false, key: false, minimised: false), .inactive)
        XCTAssertEqual(state(active: false, hidden: false, key: true, minimised: false), .inactive)
        XCTAssertEqual(state(active: false, hidden: false, key: false, minimised: false), .inactive)
    }

    func testHiddenOrMinimisedIsBackgroundWhateverElse() {
        for active in [false, true] {
            for key in [false, true] {
                XCTAssertEqual(state(active: active, hidden: true, key: key, minimised: false), .background)
                XCTAssertEqual(state(active: active, hidden: false, key: key, minimised: true), .background)
            }
        }
    }

    func testNotificationsReachTheEngine() throws {
        // In a test run the app is never active, so any recompute says inactive.
        let view = NSView()
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 64, height: 64),
                              styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = view
        let (engine, clock) = try makeEngine(view: view)
        engine.run()

        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)

        XCTAssertEqual(engine.appState, .inactive)
        XCTAssertFalse(clock.isRunning)
        engine.shutdown()
        window.contentView = nil
    }

    /// Every notification the Mac source listens to makes it recompute. In the
    /// test host the app is never active, so each recompute from a forced
    /// `.active` lands on `.inactive`; a name nobody observes leaves `.active`.
    func testEveryWatchedNotificationRecomputes() throws {
        let view = NSView()
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 64, height: 64),
                              styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = view
        let (engine, _) = try makeEngine(view: view)
        engine.run()
        let appNames: [Notification.Name] = [
            NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
            NSApplication.didHideNotification, NSApplication.didUnhideNotification
        ]
        let windowNames: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
            NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification
        ]

        for (name, object) in appNames.map({ ($0, nil as Any?) }) + windowNames.map({ ($0, window as Any?) }) {
            engine.appStateDidChange(to: .active)
            NotificationCenter.default.post(name: name, object: object)
            XCTAssertEqual(engine.appState, .inactive, "\(name.rawValue) is not watched")
        }
        engine.shutdown()
        window.contentView = nil
    }

    func testAnotherWindowsNotificationsAreIgnored() throws {
        let view = NSView()
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 64, height: 64),
                              styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = view
        let other = NSWindow(contentRect: .init(x: 0, y: 0, width: 64, height: 64),
                             styleMask: [.titled], backing: .buffered, defer: true)
        other.isReleasedWhenClosed = false
        let (engine, _) = try makeEngine(view: view)
        engine.run()

        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: other)
        XCTAssertEqual(engine.appState, .active, "an About window or panel changing is not the game's window")
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
        XCTAssertEqual(engine.appState, .inactive)
        engine.shutdown()
        window.contentView = nil
    }

    func testAViewWithNoWindowReportsNothing() throws {
        let (engine, _) = try makeEngine(view: NSView())
        engine.run()

        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)

        XCTAssertEqual(engine.appState, .active, "at launch the view may not have its window yet")
        engine.shutdown()
    }

    private func state(active: Bool, hidden: Bool, key: Bool, minimised: Bool) -> AppState {
        AppStateSource.state(appActive: active, appHidden: hidden, windowKey: key, windowMinimised: minimised)
    }
    #endif

    func testStopStopsReporting() {
        var reports: [AppState] = []
        #if canImport(UIKit)
        let source = AppStateSource(view: UIView()) { reports.append($0) }
        let name = UIApplication.didEnterBackgroundNotification
        #elseif canImport(AppKit)
        let view = NSView()
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 64, height: 64),
                              styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = view
        let source = AppStateSource(view: view) { reports.append($0) }
        let name = NSApplication.didHideNotification
        #endif

        NotificationCenter.default.post(name: name, object: nil)
        XCTAssertEqual(reports.count, 1, "listening before stop")
        source.stop()
        NotificationCenter.default.post(name: name, object: nil)

        XCTAssertEqual(reports.count, 1)
        #if canImport(AppKit) && !canImport(UIKit)
        window.contentView = nil
        #endif
    }

    /// A real engine on `view`, paced by a fake clock. Skips with no Metal device.
    private func makeEngine(view: PlatformView) throws -> (DefaultEngine, FakeClock) {
        _ = try ShaderTestSupport.makeDevice()
        let factory = SceneFactory()
        factory.addScene(IdleScene.self)
        let clock = FakeClock()
        let engine = DefaultEngine(
            renderer: DefaultRenderer(parentView: view, maxObjects: 1),
            documents: DocumentIO(presentingVC: PlatformViewController()),
            initialSceneType: SourceTestScenes.idle,
            sceneFactory: factory,
            clock: clock)
        return (engine, clock)
    }
}

private enum SourceTestScenes: SceneType {
    case idle
}

/// Draws nothing, so no render pass is needed.
@MainActor
private final class IdleScene: DefaultScene {
    override static var sceneType: any SceneType { SourceTestScenes.idle }
    override func draw() {}
}
