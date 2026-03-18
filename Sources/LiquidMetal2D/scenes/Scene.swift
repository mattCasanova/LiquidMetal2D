//
//  Scene.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

/// A single screen or state in the game (menu, gameplay, pause, etc.).
///
/// Scenes are created by a ``SceneBuilder`` and managed by ``SceneManager``.
/// The lifecycle is: `build()` → `initialize` → `update`/`draw` loop →
/// `shutdown`. Pushed scenes may also receive `resume()` after a pop.
@MainActor
public protocol Scene {
    /// Called once after building to inject dependencies.
    func initialize(sceneMgr: SceneManager, renderer: Renderer, input: InputReader)

    /// Called when this scene is restored from the stack after a pop.
    func resume()

    /// Called when the screen size or orientation changes.
    func resize()

    /// Called every frame to advance game logic.
    /// - Parameter dt: Delta time in seconds since the last frame.
    func update(dt: Float)

    /// Called every frame after update to render the scene.
    func draw()

    /// Called when the scene is being replaced or popped. Clean up resources here.
    func shutdown()

    /// Factory method. Return a new instance of this scene.
    static func build() -> Scene
}

/// Base scene class with default implementations and standard setup.
///
/// Subclass this for scenes that use the standard 2D perspective camera
/// and render a list of ``GameObj`` instances. Override `update(dt:)` for
/// game logic and optionally `draw()` for custom rendering.
open class DefaultScene: Scene {
    /// The scene manager for triggering transitions.
    public var sceneMgr: SceneManager!

    /// The renderer for drawing.
    public var renderer: Renderer!

    /// The input reader for touch input.
    public var input: InputReader!

    /// The list of game objects to draw each frame.
    public var objects: [GameObj]

    /// Optional scheduler for timed tasks. Automatically cleared on shutdown.
    public let scheduler = Scheduler()

    public init() {
        objects = [GameObj]()
    }

    public func initialize(sceneMgr: SceneManager, renderer: Renderer, input: InputReader) {
        self.sceneMgr = sceneMgr
        self.renderer = renderer
        self.input = input

        renderer.setCamera(point: Vec3(0, 0, Camera2D.defaultDistance))
        renderer.setPerspective(fov: GameMath.degreeToRadian(getFOV()),
                                aspect: renderer.screenAspect,
                                nearZ: PerspectiveProjection.defaultNearZ,
                                farZ: PerspectiveProjection.defaultFarZ)
    }

    func getFOV() -> Float {
        if renderer.screenWidth <= renderer.screenHeight { return PerspectiveProjection.defaultFOV }
        return PerspectiveProjection.defaultFOV / (renderer.screenWidth / renderer.screenHeight)
    }

    /// Draws all objects in the ``objects`` array. The renderer handles
    /// transforms, sorting by (zOrder, textureID), and instanced batching.
    public func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        renderer.submit(objects: objects)
        renderer.endPass()
    }

    public func resize() {
        renderer.setPerspective(
            fov: GameMath.degreeToRadian(getFOV()),
            aspect: renderer.screenAspect,
            nearZ: PerspectiveProjection.defaultNearZ,
            farZ: PerspectiveProjection.defaultFarZ)
    }

    public func update(dt: Float) {}
    /// Clears objects and scheduler. Override to add custom cleanup
    /// (unload textures, remove UI, etc.) — call super.shutdown().
    public func shutdown() {
        objects.removeAll()
        scheduler.clear()
    }
    public func resume() {}
    public static func build() -> Scene { return DefaultScene() }
}
