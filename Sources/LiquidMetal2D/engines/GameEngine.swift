//
//  GameEngine.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

/// Core protocol for the game loop. Handles timing, rendering, and input.
///
/// `LiquidViewController` stores a `GameEngine` reference and forwards
/// touch events and layout changes to it. The default implementation is
/// ``DefaultEngine``.
@MainActor
public protocol GameEngine: InputWriter {
    /// The display link driving the game loop.
    var timer: CADisplayLink! { get set }

    /// Timestamp of the previous frame, used to compute delta time.
    var lastFrameTime: Double { get set }

    /// The renderer used for all drawing operations.
    var renderer: Renderer { get }

    /// The scene manager that owns the current scene and handles transitions.
    var sceneManager: SceneManager { get }

    /// Starts the game loop by attaching a CADisplayLink to the main run loop.
    func run()

    /// Stops the game loop by invalidating the display link.
    func stop()

    /// Called every frame by the display link. Computes delta time,
    /// checks for scene transitions, then updates and draws the current scene.
    func gameLoop(displayLink: CADisplayLink)
}

public extension GameEngine {
    /// Resizes the renderer and notifies the current scene of the layout change.
    ///
    /// Called by `LiquidViewController` on rotation and layout changes.
    func resize(scale: CGFloat, layerSize: CGSize) {
        renderer.resize(scale: scale, layerSize: layerSize)
        sceneManager.currentScene.resize()
    }
}
