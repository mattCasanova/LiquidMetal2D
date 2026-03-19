//
//  SceneManager.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

/// Manages the scene lifecycle: building, transitioning, and maintaining
/// a stack for push/pop navigation.
///
/// Scenes call ``setScene(type:)``, ``pushScene(type:)``, or ``popScene()``
/// to request transitions. The actual transition happens at the start of the
/// next frame when the engine calls ``performTransition()``.
///
/// Created and owned by ``DefaultEngine``. Scenes receive a reference
/// during ``Scene/initialize(sceneMgr:renderer:input:)``.
@MainActor
public class SceneManager {
    private let sceneFactory: SceneFactory
    private let renderer: Renderer
    private var input: InputReader!

    /// The type identifier of the currently active scene.
    public private(set) var currentSceneType: any SceneType
    private var nextSceneType: any SceneType

    /// The currently active scene instance.
    public private(set) var currentScene: Scene!

    private var isPushing = false
    private var isPopping = false
    private var sceneStack = [SceneData]()

    /// Creates the scene manager. Call ``start(input:)`` after construction
    /// to build and initialize the first scene.
    ///
    /// - Parameters:
    ///   - initialSceneType: The first scene to display.
    ///   - sceneFactory: Registry mapping scene types to builders.
    ///   - renderer: The renderer passed to scenes during initialization.
    public init(initialSceneType: some SceneType, sceneFactory: SceneFactory, renderer: Renderer) {
        self.sceneFactory = sceneFactory
        self.renderer = renderer
        currentSceneType = initialSceneType
        nextSceneType = initialSceneType
    }

    /// Builds and initializes the first scene. Called by the engine after
    /// construction, once an `InputReader` is available.
    func start(input: InputReader) {
        self.input = input
        currentScene = sceneFactory.get(currentSceneType).build()
        currentScene.initialize(sceneMgr: self, renderer: renderer, input: input)
    }

    // MARK: - Scene Transition API

    /// Replaces the current scene with a new one of the given type.
    /// The transition occurs at the start of the next frame.
    public func setScene(type: some SceneType) {
        nextSceneType = type
    }

    /// Pushes the current scene onto a stack and transitions to a new one.
    /// Use ``popScene()`` to return to the saved scene.
    public func pushScene(type: some SceneType) {
        isPushing = true
        nextSceneType = type
    }

    /// Pops the top scene from the stack and resumes it.
    /// Does nothing if the stack is empty.
    public func popScene() {
        if !sceneStack.isEmpty {
            isPopping = true
        }
    }

    // MARK: - Called by Engine Game Loop

    /// Whether a scene transition is pending for this frame.
    var needsTransition: Bool {
        AnyHashable(currentSceneType) != AnyHashable(nextSceneType) || isPopping
    }

    /// Shuts down the current scene and all stacked scenes. Called by the
    /// engine during shutdown to ensure all scenes clean up their resources.
    func shutdown() {
        currentScene?.shutdown()
        for sceneData in sceneStack {
            sceneData.scene.shutdown()
        }
        sceneStack.removeAll()
        currentScene = nil
    }

    /// Executes the pending scene transition. Handles push, pop, and set.
    func performTransition() {
        if isPushing {
            sceneStack.append(SceneData(scene: currentScene, type: currentSceneType))
            currentSceneType = nextSceneType
            currentScene = sceneFactory.get(currentSceneType).build()
            currentScene.initialize(sceneMgr: self, renderer: renderer, input: input)
        } else if isPopping {
            guard let sceneData = sceneStack.popLast() else { return }
            currentScene.shutdown()
            currentScene = sceneData.scene
            currentSceneType = sceneData.type
            nextSceneType = currentSceneType
            currentScene.resume()
        } else {
            currentSceneType = nextSceneType
            currentScene.shutdown()
            // Shut down any stacked scenes that won't be returned to
            for sceneData in sceneStack {
                sceneData.scene.shutdown()
            }
            sceneStack.removeAll()
            currentScene = sceneFactory.get(currentSceneType).build()
            currentScene.initialize(sceneMgr: self, renderer: renderer, input: input)
        }
        isPushing = false
        isPopping = false
    }
}
