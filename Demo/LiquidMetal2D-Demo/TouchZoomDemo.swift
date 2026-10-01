//
//  TouchZoomDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/9/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
import LiquidMetal2D

/// Touch input and camera zoom demo.
///
/// **What the user sees:** A blue ship at the center and four ships pinned to the corners.
/// All ships rotate to face the touch point. Each tap toggles a smooth camera zoom in/out,
/// and as the camera distance changes, the visible world area grows or shrinks -- but the
/// corner ships stay fixed, illustrating how world bounds relate to camera distance.
///
/// **Engine features demonstrated:**
/// - **Touch input:** `input.getWorldTouch(forZ:)` converts screen-space touch coordinates
///   to world-space at a given z-plane. This is essential for mapping finger position to
///   game object positions.
/// - **Camera zoom:** `renderer.setCamera(point:)` adjusts the camera's z distance each frame.
/// - **Easing functions:** `Easing.easeInOutCubic` smooths the zoom interpolation so it
///   accelerates and decelerates naturally instead of moving at constant speed.
/// - **World bounds:** `renderer.getVisibleBounds(cameraDistance:zOrder:)` calculates the visible
///   world rectangle for a given camera distance. Corner ships are placed at these bounds.
/// - **GameMath.lerp:** Linear interpolation between start and target z, driven by eased t.
///
/// **Scene protocol lifecycle:**
/// `initialize` is called once when the scene loads. `update(dt:)` and `draw()` are called
/// every frame by the engine. `resize()` is called on device rotation. `resume()` is called
/// when a pushed scene (PauseDemo) pops and this scene becomes active again. `shutdown()` is
/// called when the scene is removed from the scene stack.
class TouchZoomDemo: Scene {
    static var sceneType: any SceneType { SceneTypes.touchZoomDemo }

    private var sceneMgr: SceneManager!
    private var renderer: Renderer!
    private var input: InputReader!

    // Camera zoom range and animation state
    /// Closest camera z distance (zoomed in = less world visible)
    private let nearZ: Float = 30
    /// Farthest camera z distance (zoomed out = more world visible)
    private let farZ: Float = 70
    /// The z distance we are animating toward
    private var targetZ: Float = 50
    /// The z distance we started animating from
    private var startZ: Float = 50
    /// Current camera z distance (interpolated between startZ and targetZ)
    private var currentZ: Float = 50
    /// Animation progress from 0 (start) to 1 (complete). Starts at 1 = no animation in progress.
    private var zoomT: Float = 1
    /// How long the zoom animation takes in seconds
    private let zoomDuration: Float = 1.0
    /// Toggle state: true = zoomed in (nearZ), false = zoomed out (farZ)
    private var isZoomedIn = false

    private var centerShip: GameObj!
    private var cornerShips = [GameObj]()

    private var ui: DemoSceneUI!

    /// Scene protocol: called once when the scene is first created.
    /// Set up textures, camera, projection, and create all game objects here.
    func initialize(services: SceneServices) {
        self.sceneMgr = services.sceneMgr
        self.renderer = services.renderer
        self.input = services.input

        // Camera2D.defaultDistance is the engine's suggested starting z for the camera
        currentZ = Camera2D.defaultDistance
        startZ = currentZ
        targetZ = currentZ

        renderer.setCamera(point: Vec3(0, 0, currentZ))
        renderer.setCameraRotation(angle: 0)
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        createObjects()

        ui = DemoSceneUI(
            parentView: renderer.view, target: self,
            menuAction: #selector(onMenu))
    }

    /// Scene protocol: called when this scene becomes active again after a pushed scene pops.
    /// Re-show the menu button that was hidden before pushing PauseDemo.
    func resume() { ui.view.isHidden = false }

    /// Scene protocol: called on device rotation or window resize.
    func resize() {
        ui.layout()
        renderer.setDefaultPerspective()
        // Reposition corners since screen aspect may have changed
        positionCornerShips()
    }

    func update(dt: Float) {
        // getWorldTouch converts the screen touch position to world-space coordinates
        // at the z=0 plane. Returns nil if no touch is active.
        if let touch = input.getWorldTouch(forZ: 0) {
            let touchPos = Vec2(touch.x, touch.y)

            // Orient all ships toward the touch using atan2 to compute the angle
            // from each ship's position to the touch position
            let centerDir = touchPos - centerShip.position
            centerShip.rotation = atan2(centerDir.y, centerDir.x)

            for ship in cornerShips {
                let dir = touchPos - ship.position
                ship.rotation = atan2(dir.y, dir.x)
            }

            // Toggle zoom direction on each new touch (only if previous animation finished).
            // zoomT tracks progress from 0 (start) to 1 (complete).
            if zoomT >= 1.0 {
                isZoomedIn.toggle()
                startZ = currentZ
                targetZ = isZoomedIn ? nearZ : farZ
                zoomT = 0
            }
        }

        // Animate camera zoom using easing for smooth acceleration/deceleration.
        // Easing.easeInOutCubic maps linear t to a curve that starts slow, speeds up, then slows.
        // GameMath.lerp then interpolates between startZ and targetZ using the eased value.
        if zoomT < 1.0 {
            zoomT = min(zoomT + dt / zoomDuration, 1.0)
            let easedT = Easing.easeInOutCubic(zoomT)
            currentZ = GameMath.lerp(a: startZ, b: targetZ, t: easedT)
            renderer.setCamera(point: Vec3(0, 0, currentZ))
        }
    }

    /// Scene protocol: called every frame after update(). Submit draw calls here.
    func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        renderer.submit(objects: [centerShip!] + cornerShips)
        renderer.endPass()
    }

    /// Scene protocol: called when this scene is removed from the scene stack.
    /// Clean up UI overlays and release GPU resources (textures).
    func shutdown() {
        ui.removeFromSuperview()
    }

    private func createObjects() {
        centerShip = GameObj()
        centerShip.position.set(0, 0)
        centerShip.scale.set(5, 5)
        centerShip.add(AlphaBlendComponent(
            parent: centerShip,
            textureID: GameTextures.blue,
            tintColor: TokyoNight.shipTints[0]))

        cornerShips.removeAll()
        for i in 0..<4 {
            let ship = GameObj()
            ship.scale.set(7, 7)
            let texIndex = 1 + (i % 2)
            ship.add(AlphaBlendComponent(
                parent: ship,
                textureID: GameTextures.all[texIndex],
                tintColor: TokyoNight.shipTints[texIndex]))
            cornerShips.append(ship)
        }

        positionCornerShips()
    }

    /// Positions corner ships at the world bounds calculated for the closest camera distance (nearZ).
    /// This means when the camera is zoomed in (at nearZ), the corner ships are at the screen edges.
    /// When zoomed out, they appear inside the screen, demonstrating how world bounds expand with distance.
    private func positionCornerShips() {
        // getVisibleBounds returns the visible world-space rectangle for a given camera distance and z-plane.
        // Using nearZ here means the ships sit at the edges of the closest zoom level.
        let bounds = renderer.getVisibleBounds(cameraDistance: nearZ, zOrder: 0)

        let positions: [(Float, Float)] = [
            (bounds.maxX, bounds.maxY),
            (bounds.minX, bounds.maxY),
            (bounds.minX, bounds.minY),
            (bounds.maxX, bounds.minY)
        ]

        for i in 0..<cornerShips.count {
            cornerShips[i].position.set(positions[i].0, positions[i].1)
        }
    }

    /// Push the pause/menu scene on top of this scene. Hide the menu button first so it
    /// does not appear on top of the pause overlay.
    @objc func onMenu() { ui.view.isHidden = true; sceneMgr.pushScene(type: SceneTypes.pauseDemo) }

    /// Every Scene must provide a static build() method. The SceneFactory uses this
    /// (via TSceneBuilder<T>) to create new instances when transitioning between scenes.
    static func build() -> Scene { return TouchZoomDemo() }
}
