//
//  DefaultEngine.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

/// Default game engine implementation. Runs the main game loop via
/// CADisplayLink and delegates scene management to a ``SceneManager``.
///
/// Conforms to ``GameEngine`` (loop + rendering) and ``InputReader``
/// (touch input). Create one in your `UIViewController.viewDidLoad()`:
///
/// ```swift
/// gameEngine = DefaultEngine(
///     renderer: renderer,
///     initialSceneType: MyScenes.menu,
///     sceneFactory: factory)
/// gameEngine.run()
/// ```
public class DefaultEngine: GameEngine, InputReader {
    /// Frames with a delta time above this threshold are skipped.
    /// Prevents physics explosions after backgrounding or debugger pauses.
    private static let maxFrameTime: Float = 5

    private var touchLocation: Vec2?

    public var timer: CADisplayLink!
    public var lastFrameTime: Double = 0.0

    public let renderer: Renderer
    public let sceneManager: SceneManager

    /// Creates the engine, builds the initial scene, and prepares for the game loop.
    ///
    /// - Parameters:
    ///   - renderer: The renderer to use for all drawing.
    ///   - initialSceneType: The first scene to display.
    ///   - sceneFactory: Registry mapping scene types to builders.
    public init(renderer: Renderer, initialSceneType: some SceneType, sceneFactory: SceneFactory) {
        self.renderer = renderer
        self.sceneManager = SceneManager(
            initialSceneType: initialSceneType,
            sceneFactory: sceneFactory,
            renderer: renderer)

        sceneManager.start(input: self)
    }

    /// Starts the game loop by attaching a CADisplayLink to the main run loop.
    public func run() {
        timer = CADisplayLink(target: self, selector: #selector(gameLoop(displayLink:)))
        lastFrameTime = timer.timestamp
        timer.add(to: RunLoop.main, forMode: .default)
    }

    /// Called every frame by the display link. Skips frames with excessive
    /// delta time, performs pending scene transitions, then updates and draws.
    @objc public func gameLoop(displayLink: CADisplayLink) {
        let dt: Float = Float(displayLink.timestamp - lastFrameTime)
        lastFrameTime = displayLink.timestamp

        if dt > DefaultEngine.maxFrameTime { return }

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
