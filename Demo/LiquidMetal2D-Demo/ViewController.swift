//
//  ViewController.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/8/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import LiquidMetal2D
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The engine's host, subclassing `LiquidViewController`. `DemoApp` puts it on screen
/// through `LiquidView`; the same class runs on iOS and the Mac.
///
/// **Engine setup pattern:** This is the entry point for a LiquidMetal2D app. The three
/// steps to launch the engine are:
///
/// 1. **Register scenes with a SceneFactory:** Each scene class declares a static
///    `sceneType` property and a `build()` method (inherited automatically if you
///    subclass `DefaultScene`). Pass the scene classes to `addScenes(_:)`.
///
/// 2. **Create a renderer:** `DefaultRenderer` is the engine's Metal-based renderer.
///    It needs the parent view, the maximum number of objects you will draw per frame
///    (`maxObjects`), and the byte size of your per-object uniform struct (`uniformSize`).
///
/// 3. **Create and run the engine:** `DefaultEngine` takes the renderer, the initial scene
///    type, and the scene factory. Calling `gameEngine.run()` starts the game loop.
///
/// **Pausing when the player leaves:** the controller registers as the engine's
/// `AppStateObserver`. When the app loses focus or goes out of sight it pushes `PauseDemo`,
/// the same scene the Pause button shows. The engine only reports the change and freezes its
/// own loop; the pause screen is the app's choice, made in this one place rather than in
/// every scene. Nothing pops on return: the player resumes when ready.
class ViewController: LiquidViewController, AppStateObserver {
    private let ui: DemoUI

    init(ui: DemoUI) {
        self.ui = ui
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ViewController is built in code; see DemoApp")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Step 1: Register all scenes. Each scene declares its own sceneType,
        // so the factory reads the type automatically from the class.
        let sceneFactory = SceneFactory()
        sceneFactory.addScenes([
            MassRenderDemo.self,
            TouchZoomDemo.self,
            InstanceDemo.self,
            SchedulerDemo.self,
            SpawnDemo.self,
            CollisionDemo.self,
            CollisionStressDemo.self,
            BezierDemo.self,
            CameraRotationDemo.self,
            CameraPanDemo.self,
            AsyncLoadDemo.self,
            MultiShaderDemo.self,
            ParticleDemo.self,
            LineParticleDemo.self,
            SmokeDemo.self,
            SmokeLayersDemo.self,
            SkeletonDemo.self,
            InputDemo.self,
            LightingDemo.self,
            PauseDemo.self,
        ])

        // Step 2: Create the Metal renderer.
        let renderer = DefaultRenderer(
            parentView: self.view,
            maxObjects: GameConstants.MAX_OBJECTS)

        // Step 3: Create the user-facing file picker. Bound to this VC for
        // the lifetime of the app; scenes reach it via `services.documents`.
        let documents = DocumentIO(presentingVC: self)

        // Step 4: Create the engine and start the game loop. `buildServices` wraps the
        // engine's services in the demo's own bag, which adds the SwiftUI bridge.
        let ui = self.ui
        let engine = DefaultEngine(
            renderer: renderer,
            documents: documents,
            inputDevices: [.pointer, .keyboard],
            initialSceneType: SceneTypes.asyncLoadDemo,
            sceneFactory: sceneFactory,
            buildServices: { renderer, input, sceneMgr, documents in
                DemoServices(renderer: renderer, input: input, sceneMgr: sceneMgr, documents: documents, ui: ui)
            })
        gameEngine = engine
        ui.sceneMgr = engine.sceneManager
        engine.addAppStateObserver(self)

        engine.run()
    }

    /// Pushes the pause menu on any state other than active (a minimise can skip inactive,
    /// and inactive also arrives on the way back), unless it is already up or the loader is
    /// still running: the loader is the first scene, so a brief inactive at launch must not
    /// open the menu over it, and it has nothing to pause. The push happens at once, so the
    /// SwiftUI menu is on screen while the player is away.
    func appStateChanged(to state: AppState) {
        guard state != .active else { return }
        let sceneMgr = gameEngine.sceneManager
        guard let current = sceneMgr.currentSceneType as? SceneTypes else {
            assertionFailure("the demo registers only SceneTypes, got \(sceneMgr.currentSceneType)")
            return
        }
        guard current != .pauseDemo, current != .asyncLoadDemo else { return }
        sceneMgr.pushScene(type: SceneTypes.pauseDemo)
    }
}
