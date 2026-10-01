//
//  DefaultEngine.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation

/// Default game engine implementation. Runs the main game loop from a
/// ``FrameClock`` and delegates scene management to a ``SceneManager``.
///
/// Conforms to ``GameEngine`` (loop + rendering) and ``InputReader``
/// (touch input). Create one in your `LiquidViewController` subclass's
/// `viewDidLoad()`:
///
/// ```swift
/// gameEngine = DefaultEngine(
///     renderer: renderer,
///     documents: DocumentIO(presentingVC: self),
///     initialSceneType: MyScenes.menu,
///     sceneFactory: factory)
/// gameEngine.run()
/// ```
@MainActor
public class DefaultEngine: GameEngine, InputReader {
    /// Maximum delta time per frame (~15 FPS). Larger deltas are clamped
    /// to this value to prevent physics explosions after backgrounding.
    private static let maxFrameTime: Float = 1.0 / 15.0

    private var touchLocation: Vec2?

    private let clock: FrameClock
    private var lastFrameTime: Double = 0.0

    public let renderer: Renderer
    public let sceneManager: SceneManager

    /// Creates the engine, builds the initial scene, and prepares for the game loop.
    ///
    /// - Parameters:
    ///   - renderer: The renderer to use for all drawing.
    ///   - documents: User-facing file picker, built by the caller from its
    ///     presenting view controller.
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
        initialSceneType: some SceneType,
        sceneFactory: SceneFactory,
        buildServices: ((Renderer, InputReader, SceneManager, DocumentIO) -> SceneServices)? = nil,
        clock: FrameClock? = nil
    ) {
        self.renderer = renderer
        self.clock = clock ?? DisplayLinkClock(view: renderer.view)
        self.sceneManager = SceneManager(
            initialSceneType: initialSceneType,
            sceneFactory: sceneFactory)

        let services = buildServices?(renderer, self, sceneManager, documents)
            ?? DefaultSceneServices(
                renderer: renderer,
                input: self,
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
    /// performs a pending scene transition, otherwise updates and draws.
    private func frame() {
        let rawDt: Float = Float(clock.timestamp - lastFrameTime)
        lastFrameTime = clock.timestamp

        if rawDt <= 0 { return }
        let dt = min(rawDt, DefaultEngine.maxFrameTime)

        if sceneManager.needsTransition {
            sceneManager.performTransition()
            return
        }

        autoreleasepool {
            sceneManager.currentScene.update(dt: dt)
            sceneManager.currentScene.draw()
        }
    }

    // MARK: - InputReader, InputWriter

    /// Returns the touch location unprojected to world coordinates at the given z depth.
    public func getWorldTouch(forZ z: Float) -> Vec3? {
        guard let touch = touchLocation else { return nil }
        return renderer.unproject(screenWithWorldZ: touch.to3D(z))
    }

    /// Returns the raw screen-space touch location, or nil if no touch is active.
    public func getScreenTouch() -> Vec2? {
        return touchLocation
    }

    /// Sets the current touch location. Pass nil to clear.
    public func setTouch(location: Vec2?) {
        touchLocation = location
    }
}
