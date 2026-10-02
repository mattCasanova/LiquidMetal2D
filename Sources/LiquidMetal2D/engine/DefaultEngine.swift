//
//  DefaultEngine.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation

/// Default game engine implementation. Runs the main game loop from a
/// ``FrameClock``, owns the ``InputSystem`` and delegates scene management
/// to a ``SceneManager``.
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

    public let renderer: Renderer
    public let sceneManager: SceneManager
    /// The input state scenes poll; the platform layer feeds it through
    /// this engine's ``InputWriter`` methods.
    public let input: InputSystem

    /// Creates the engine, builds the initial scene, and prepares for the game loop.
    ///
    /// - Parameters:
    ///   - renderer: The renderer to use for all drawing.
    ///   - documents: User-facing file picker, built by the caller from its
    ///     presenting view controller.
    ///   - inputDevices: The devices to accept and allow queries on. The
    ///     default, `[.pointer]`, is the one-touch behaviour the engine
    ///     always had.
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
        initialSceneType: some SceneType,
        sceneFactory: SceneFactory,
        buildServices: ((Renderer, InputReader, SceneManager, DocumentIO) -> SceneServices)? = nil,
        clock: FrameClock? = nil
    ) {
        self.renderer = renderer
        self.clock = clock ?? DisplayLinkClock(view: renderer.view)
        self.input = InputSystem(
            devices: inputDevices,
            unproject: { [unowned renderer] in renderer.unproject(screenWithWorldZ: $0) })
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
    }

    /// Shuts down the engine: stops the game loop, shuts down all scenes,
    /// and releases renderer resources.
    public func shutdown() {
        clock.stop()
        sceneManager.shutdown()
        renderer.shutdown()
    }

    /// Starts the game loop: the clock calls ``frame()`` every refresh.
    public func run() {
        // The clock holds the closure, and the engine holds the clock, so
        // the closure must not retain the engine (a cycle until `stop()`).
        // An engine dropped without `shutdown()` traps on its next frame
        // instead of running on unseen.
        clock.start { [unowned self] in self.frame() }
        lastFrameTime = clock.timestamp
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
