//
//  DefaultEngine.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation
#if canImport(AppKit) && !canImport(UIKit)
import AppKit
#endif

/// Default game engine implementation. Runs the main game loop from a
/// ``FrameClock``, owns the ``InputSystem`` and delegates scene management
/// to a ``SceneManager``.
///
/// It also tracks the app's ``AppState``. When the player switches away or
/// hides the game it tells app-level ``AppStateObserver``s and the current
/// scene, then freezes the loop: always in the background, and while
/// inactive unless `pausesWhenInactive` is false. Coming back restarts the
/// loop with a normal first frame. Pausing, pause menus and saving are the
/// game's: push a pause scene from ``Scene/appStateChanged(to:)``, save on
/// ``AppState/background``.
///
/// Conforms to ``GameEngine`` (loop, rendering, and ``InputWriter`` for the
/// platform layer's events). Create one in your `LiquidViewController`
/// subclass's `viewDidLoad()`:
///
/// ```swift
/// gameEngine = DefaultEngine(
///     renderer: renderer,
///     documents: DocumentIO(presentingVC: self),
///     inputDevices: [.pointer, .keyboard],
///     initialSceneType: MyScenes.menu,
///     sceneFactory: factory)
/// gameEngine.run()
/// ```
@MainActor
public class DefaultEngine: GameEngine {
    /// Maximum delta time per frame (~15 FPS). Larger deltas are clamped
    /// to this value to prevent physics explosions after backgrounding.
    private static let maxFrameTime: Float = 1.0 / 15.0

    private let clock: FrameClock
    private var lastFrameTime: Double = 0.0
    /// `run()` was called: the loop should go whenever the app state allows.
    private var isStarted = false
    /// The clock is started right now (`run()` started it and no state change
    /// stopped it).
    private var isClockRunning = false

    /// Whether the loop stops while the app is ``AppState/inactive``. It
    /// always stops in the background.
    public let pausesWhenInactive: Bool
    /// The app's state as of the latest platform notification. Starts at
    /// ``AppState/active``.
    public private(set) var appState: AppState = .active
    private var appStateObservers: [WeakBox<AppStateObserver>] = []
    /// A transition ran outside `frame()` (on a state change). The next frame
    /// drains the input queue and drops its events, as a transition frame
    /// does: the release that ended the player's leave must not reach the
    /// scene that was pushed meanwhile.
    private var dropsNextFrameInput = false
    /// Set at the end of `init`: it reports into `self`.
    private var appStateSource: AppStateSource?

    public let renderer: Renderer
    public let sceneManager: SceneManager
    /// The input state scenes poll; the platform layer feeds it through
    /// this engine's ``InputWriter`` methods.
    public let input: InputSystem

    public var inputDevices: InputDevices { input.devices }

    private let keyboardSource: KeyboardSource?
    private let focusSource: FocusSource
    private var isShutDown = false
    #if canImport(AppKit) && !canImport(UIKit)
    /// Shuts the engine down when the app quits, by any path.
    private var terminationObserver: NSObjectProtocol?
    #endif

    /// Creates the engine, builds the initial scene, and prepares for the game loop.
    ///
    /// - Parameters:
    ///   - renderer: The renderer to use for all drawing.
    ///   - documents: User-facing file picker, built by the caller from its
    ///     presenting view controller.
    ///   - inputDevices: The devices to accept and allow queries on. The
    ///     default, `[.pointer]`, is the one-touch behaviour the engine
    ///     always had.
    ///   - pausesWhenInactive: Stop the loop while the app is visible but
    ///     without focus. On by default; turn it off for a game that must keep
    ///     running behind another app. The loop always stops in the background.
    ///   - initialSceneType: The first scene to display.
    ///   - sceneFactory: Registry mapping scene types to builders.
    ///   - buildServices: Optional closure that wraps the engine-built
    ///     primitives in a custom ``SceneServices`` (typically an app-defined
    ///     `GameServices` carrying typed stores). Defaults to
    ///     ``DefaultSceneServices``.
    ///   - clock: What paces the loop. Defaults to the display link of the
    ///     renderer's view; tests pass a fake and step frames by hand.
    public init(
        renderer: Renderer,
        documents: DocumentIO,
        inputDevices: InputDevices = [.pointer],
        pausesWhenInactive: Bool = true,
        initialSceneType: some SceneType,
        sceneFactory: SceneFactory,
        buildServices: ((Renderer, InputReader, SceneManager, DocumentIO) -> SceneServices)? = nil,
        clock: FrameClock? = nil
    ) {
        self.renderer = renderer
        self.pausesWhenInactive = pausesWhenInactive
        self.clock = clock ?? DisplayLinkClock(view: renderer.view)
        let input = InputSystem(
            devices: inputDevices,
            unproject: { [unowned renderer] in renderer.unproject(screenWithWorldZ: $0) })
        self.input = input
        // The sources hold the input system unowned: the engine owns both and
        // stops the sources in shutdown().
        keyboardSource = inputDevices.contains(.keyboard)
            ? KeyboardSource(enqueue: { [unowned input] in input.enqueue($0) })
            : nil
        focusSource = FocusSource(view: renderer.view, enqueue: { [unowned input] in input.enqueue($0) })
        self.sceneManager = SceneManager(
            initialSceneType: initialSceneType,
            sceneFactory: sceneFactory)

        let services = buildServices?(renderer, input, sceneManager, documents)
            ?? DefaultSceneServices(
                renderer: renderer,
                input: input,
                sceneMgr: sceneManager,
                documents: documents)

        sceneManager.start(services: services)

        // Weak: a notification can arrive at any time, even after an engine
        // dropped without `shutdown()` is gone.
        appStateSource = AppStateSource(view: renderer.view) { [weak self] state in
            self?.appStateDidChange(to: state)
        }

        #if canImport(AppKit) && !canImport(UIKit)
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.shutdown() }
        }
        #endif
    }

    /// Shuts down the engine: stops the game loop, shuts down all scenes,
    /// and releases renderer resources. Runs once; later calls do nothing
    /// (closing the window, SwiftUI dismantling the view and the app quitting
    /// can each ask). On the Mac it also runs when the app quits, by any path.
    public func shutdown() {
        guard !isShutDown else { return }
        isShutDown = true
        #if canImport(AppKit) && !canImport(UIKit)
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        #endif
        clock.stop()
        isClockRunning = false
        appStateObservers.removeAll()
        appStateSource?.stop()
        keyboardSource?.stop()
        focusSource.stop()
        sceneManager.shutdown()
        renderer.shutdown()
    }

    /// Starts the game loop: the clock calls ``frame()`` every refresh. If
    /// the app state already says frozen, the loop starts when it allows.
    public func run() {
        isStarted = true
        updateClock()
    }

    // MARK: - App state

    /// Registers app-level code to hear every ``AppState`` change, before the
    /// current scene. Held weakly; a released observer is dropped.
    public func addAppStateObserver(_ observer: AppStateObserver) {
        appStateObservers.append(WeakBox(observer))
    }

    public func removeAppStateObserver(_ observer: AppStateObserver) {
        appStateObservers.removeAll { $0.value == nil || $0.value === observer }
    }

    /// The platform source's entry point (and the tests'). Tells observers,
    /// then the current scene; performs a transition the scene asked for at
    /// once (the frozen loop would not run it until the player is back); then
    /// stops or restarts the clock.
    func appStateDidChange(to state: AppState) {
        guard !isShutDown, state != appState else { return }
        appState = state

        appStateObservers.removeAll { $0.value == nil }
        for box in appStateObservers {
            // An observer may shut the engine down (a quit on background);
            // the rest, and the scene, then hear nothing: the scene is gone.
            guard !isShutDown else { return }
            box.value?.appStateChanged(to: state)
        }
        // An observer that spun the run loop (a modal alert) may have let a
        // newer state through already; the scene heard that one, not this.
        guard !isShutDown, appState == state else { return }
        sceneManager.currentScene.appStateChanged(to: state)
        if sceneManager.needsTransition {
            sceneManager.performTransition()
            dropsNextFrameInput = true
        }
        updateClock()
    }

    /// Whether the loop should run in `state`.
    private func allowsFrames(in state: AppState) -> Bool {
        switch state {
        case .active: true
        case .inactive: !pausesWhenInactive
        case .background: false
        }
    }

    /// Starts or stops the clock to match `run()`, shutdown and the app state.
    private func updateClock() {
        let shouldRun = isStarted && !isShutDown && allowsFrames(in: appState)
        if shouldRun && !isClockRunning {
            // The clock holds the closure, and the engine holds the clock, so
            // the closure must not retain the engine (a cycle until `stop()`).
            // An engine dropped without `shutdown()` traps on its next frame
            // instead of running on unseen.
            clock.start { [unowned self] in self.frame() }
            isClockRunning = true
            // Measure the first frame from now, not from before a freeze.
            lastFrameTime = clock.timestamp
        } else if !shouldRun && isClockRunning {
            clock.stop()
            isClockRunning = false
        }
    }

    /// One frame. Skips frames with no elapsed time, clamps long ones,
    /// drains the input queue, performs a pending scene transition (that
    /// frame's input events are dropped on purpose: the click that opens a
    /// menu must not also press a button in it), otherwise updates and draws.
    private func frame() {
        let rawDt: Float = Float(clock.timestamp - lastFrameTime)
        lastFrameTime = clock.timestamp

        if rawDt <= 0 { return }
        let dt = min(rawDt, DefaultEngine.maxFrameTime)

        let events = input.beginFrame()

        if sceneManager.needsTransition {
            sceneManager.performTransition()
            return
        }
        if dropsNextFrameInput {
            dropsNextFrameInput = false
            return
        }

        if !events.isEmpty {
            sceneManager.currentScene.deliverInput(events)
        }

        autoreleasepool {
            sceneManager.currentScene.update(dt: dt)
            sceneManager.currentScene.draw()
        }
    }

    // MARK: - InputWriter

    public func enqueue(_ event: RawInputEvent) {
        input.enqueue(event)
    }

    public func setTouch(location: Vec2?) {
        input.setTouch(location: location)
    }
}
