//
//  MassRenderDemo.swift
//  LiquidMetal2D-Demo
//
//  Copyright © 2026 Matt Casanova. All rights reserved.
//

import UIKit
import LiquidMetal2D

/// Mass rendering and visual effects demo showcasing 4,500 ships at varying z-depths.
///
/// **What the user sees:** Thousands of ships scroll right across the screen at different
/// distances (z = 0..60). The camera gently oscillates forward and backward via a sine wave,
/// creating a parallax-like zoom effect. The background color smoothly crossfades between
/// two colors every 2 seconds using a scheduled task.
///
/// **Engine features demonstrated:**
/// - **Mass rendering:** Drawing 4,500 textured quads per frame with the Metal renderer.
/// - **Z-depth sorting:** Objects at different z values appear at different sizes due to
///   perspective projection. Sorting by `zOrder` ensures correct back-to-front draw order.
/// - **Camera movement:** `renderer.setCamera(point:)` moves the camera each frame.
/// - **Scheduler:** `ScheduledTask` fires a repeating callback to swap colors.
/// - **MoveRightBehavior:** A single-state Behavior that moves ships right and wraps them.
class MassRenderDemo: DefaultScene {
    override class var sceneType: any SceneType { SceneTypes.massRenderDemo }

    var backgroundTime: Float = 0
    let maxBackgroundChangeTime: Float = 2

    var cameraTime: Float = 0.0
    var camDistance: Float = 30
    var distance: Float = 40
    let cameraOscillationSpeed: Float = 0.5

    let objectCount = GameConstants.MAX_OBJECTS

    var startColor = Vec3(0.102, 0.106, 0.149)
    var endColor = Vec3(0.255, 0.282, 0.408)

    private var ui: DemoSceneUI!

    override func initialize(services: SceneServices) {
        super.initialize(services: services)

        renderer.setCamera(point: Vec3(0, 0, distance))
        renderer.setCameraRotation(angle: Float.random(in: 0...GameMath.twoPi))

        scheduler.add(task: ScheduledTask(time: maxBackgroundChangeTime, action: { [unowned self] _ in
            self.backgroundTime = 0
            let temp = self.startColor
            self.startColor = self.endColor
            self.endColor = temp
        }))

        createObjects()

        ui = DemoSceneUI(
            parentView: renderer.view, target: self,
            menuAction: #selector(onMenu))
    }

    override func resume() { ui.view.isHidden = false }

    override func layoutUI() {
        ui.layout()
    }

    override func update(dt: Float) {
        scheduler.update(dt: dt)

        cameraTime += dt * cameraOscillationSpeed
        let newDist = -sinf(cameraTime) * camDistance + distance
        renderer.setCamera(point: Vec3(0, 0, newDist))

        backgroundTime += dt
        let t = backgroundTime / maxBackgroundChangeTime
        renderer.setClearColor(color: startColor.lerp(to: endColor, t: t))

        for obj in objects {
            obj.get(MoveRightBehavior.self)?.update(dt: dt)
        }

        objects.sort(by: Self.isFarther)
    }

    /// Draw order: ascending `zOrder`, far to near. A `nonisolated` function,
    /// not a closure: a closure written in this `@MainActor` scene would make
    /// `sort` check the actor on every comparison (1.7 ms a frame at 10,000 ships).
    private nonisolated static func isFarther(_ lhs: GameObj, _ rhs: GameObj) -> Bool {
        lhs.zOrder < rhs.zOrder
    }

    override func shutdown() {
        super.shutdown()
        ui.removeFromSuperview()
    }

    private func createObjects() {
        let getBounds = { [unowned self] (zOrder: Float) -> WorldBounds in
            self.renderer.getVisibleBounds(cameraDistance: self.distance + self.camDistance, zOrder: zOrder)
        }
        for _ in 0..<objectCount {
            let obj = GameObj()
            obj.add(AlphaBlendComponent(parent: obj, textureID: GameTextures.blue))
            let behavior = MoveRightBehavior(parent: obj, getBounds: getBounds)
            obj.add(behavior)
            objects.append(obj)
        }
    }

    @objc func onMenu() {
        ui.view.isHidden = true
        sceneMgr.pushScene(type: SceneTypes.pauseDemo)
    }
}
