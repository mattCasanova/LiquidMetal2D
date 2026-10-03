//
//  Scene.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

/// A single screen or state in the game (menu, gameplay, pause, etc.).
///
/// Managed by ``SceneManager``. The lifecycle is:
/// `build()` → `initialize` → `update`/`draw` loop → `shutdown`.
/// Pushed scenes may also receive `resume()` after a pop.
///
/// Each scene declares its ``sceneType`` so the ``SceneFactory`` can
/// register and look it up automatically.
@MainActor
public protocol Scene {
    /// The scene type identifier used for registration and transitions.
    static var sceneType: any SceneType { get }

    /// Called once after building to inject engine + app services.
    func initialize(services: SceneServices)

    /// Called when this scene is restored from the stack after a pop.
    func resume()

    /// Called when the screen size or orientation changes.
    func resize()

    /// Called when the app's ``AppState`` changes: the player switched away,
    /// hid the game, or came back. Only the current scene hears it, after
    /// app-level ``AppStateObserver``s. Any transition pending afterwards
    /// (one requested here, by an observer, or earlier in the frame) happens
    /// at once, so a pushed pause scene is current while the player is away;
    /// nothing is drawn until the loop runs again, so a SwiftUI overlay shows
    /// at once and Metal-drawn content on the first frame back. React to any
    /// state other than `.active` (see ``AppState``). The default does nothing.
    func appStateChanged(to state: AppState)

    /// Called before `update` on frames that had input events, with the
    /// frame's events in order. Only the current scene hears them; a frame
    /// that performs a transition drops its events. The default does nothing.
    func deliverInput(_ events: [InputEvent])

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

public extension Scene {
    func deliverInput(_ events: [InputEvent]) {}
    func appStateChanged(to state: AppState) {}
}

/// Base scene class with default implementations and standard setup.
///
/// Subclass this for scenes that use the standard 2D perspective camera
/// and render a list of ``GameObj`` instances. Override `update(dt:)` for
/// game logic and optionally `draw()` for custom rendering.
open class DefaultScene: Scene {
    /// The full services bag. Cast to an app-specific protocol to reach
    /// app-level services beyond what the engine ships.
    public var services: SceneServices!

    /// The scene manager for triggering transitions.
    public var sceneMgr: SceneManager!

    /// The renderer for drawing.
    public var renderer: Renderer!

    /// The input reader for touch input.
    public var input: InputReader!

    /// User-facing file picker for save/load dialogs.
    public var documents: DocumentIO!

    /// The list of game objects to draw each frame.
    public var objects: [GameObj]

    /// Optional scheduler for timed tasks. Automatically cleared on shutdown.
    public let scheduler = Scheduler()

    /// Who hears this scene's input events. Add `self` (or a helper) in
    /// `initialize`; cleared on shutdown.
    public let inputObservers = InputObservers()

    /// Subclasses must override to return their scene type.
    open class var sceneType: any SceneType {
        fatalError("Subclasses of DefaultScene must override sceneType")
    }

    public required init() {
        objects = [GameObj]()
    }

    open func initialize(services: SceneServices) {
        self.services = services
        self.sceneMgr = services.sceneMgr
        self.renderer = services.renderer
        self.input = services.input
        self.documents = services.documents

        renderer.setCamera()
        renderer.setCameraRotation(angle: 0)
        renderer.setDefaultPerspective()
    }

    /// Draws all objects in the ``objects`` array. The active shader filters
    /// by its render component, builds uniforms, and batches for instanced
    /// drawing.
    open func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        renderer.submit(objects: objects)
        renderer.endPass()
    }

    open func resize() {
        renderer.setDefaultPerspective()
        layoutUI()
    }

    /// Called by ``resize()`` after the projection is reconfigured.
    /// Override to reposition UI elements after rotation or layout changes.
    open func layoutUI() {}

    /// Forwards the frame's events to ``inputObservers``.
    open func deliverInput(_ events: [InputEvent]) {
        inputObservers.deliver(events, from: input)
    }

    /// Does nothing. Override to pause, save or mute when the player leaves.
    open func appStateChanged(to state: AppState) {}

    open func update(dt: Float) {}

    /// Clears objects, scheduler and input observers. Override to add custom
    /// cleanup (unload textures, remove UI, etc.) — call super.shutdown().
    open func shutdown() {
        objects.removeAll()
        scheduler.clear()
        inputObservers.removeAll()
    }

    open func resume() {}

    /// Subclasses inherit this automatically — no need to override.
    /// Uses `Self()` so it returns the correct subclass type.
    open class func build() -> Scene { return Self() }
}
