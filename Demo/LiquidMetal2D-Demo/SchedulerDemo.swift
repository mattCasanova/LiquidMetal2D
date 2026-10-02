//
//  SchedulerDemo.swift
//  LiquidMetal2D-Demo
//
//  Originally ThirdScene by Matt Casanova on 3/18/20.
//

import Foundation
import LiquidMetal2D

/// Scheduler demo showcasing task chaining, finite repeats, and completion callbacks.
///
/// **What the user sees:** 100 ships explode outward from center. The demo cycles through
/// three phases in a continuous loop:
/// 1. Background color crossfades back and forth 4 times (6 seconds)
/// 2. Camera rotates a full 360° (6 seconds)
/// 3. Camera zooms in close then back out (6 seconds), ships respawn, and the cycle restarts
///
/// Touch rotates all ships toward the touch point at any time.
///
/// **Engine features demonstrated:**
/// - **Task chaining:** `task.then(time:action:count:onComplete:)` sequences tasks.
/// - **Finite repeat count:** Phase 1 uses `count: 4` to fire exactly 4 times.
/// - **onComplete callbacks:** Each phase's completion triggers the next phase.
/// - **Infinite looping via chaining:** The final onComplete rebuilds the chain.
/// - **Camera rotation and zoom** via `setCameraRotation` and `setCamera`.
class SchedulerDemo: DefaultScene {
    override class var sceneType: any SceneType { SceneTypes.schedulerDemo }

    // Phase 1: Color crossfade
    var shouldChange = true
    var changeTime: Float = 0
    let maxChangeTime: Float = 1.5
    var startColor = Vec3(0.102, 0.106, 0.149)
    var endColor = Vec3(0.255, 0.282, 0.408)

    // Phase 2: Camera rotation
    var isRotating = false
    var cameraAngle: Float = 0
    let rotationDuration: Float = 6

    // Phase 3: Camera zoom
    var isZooming = false
    var zoomTime: Float = 0
    let zoomDuration: Float = 6

    let baseDistance: Float = 40
    var distance: Float = 40
    let objectCount = 100

    private var ui: DemoSceneUI!

    override func initialize(services: SceneServices) {
        super.initialize(services: services)

        createObjects()

        ui = DemoSceneUI(
            parentView: renderer.view, target: self,
            menuAction: #selector(onMenu))

        buildDemoChain()
    }

    override func resume() { ui.view.isHidden = false }

    override func resize() {
        super.resize()
        ui.layout()
    }

    override func update(dt: Float) {
        scheduler.update(dt: dt)

        // Phase 1: Smooth color crossfade between swaps
        if shouldChange {
            changeTime += dt
            let t = min(changeTime / maxChangeTime, 1)
            renderer.setClearColor(color: startColor.lerp(to: endColor, t: t))
        } else {
            renderer.setClearColor(color: startColor)
        }

        // Phase 2: Smooth 360° camera rotation
        if isRotating {
            cameraAngle += (GameMath.twoPi / rotationDuration) * dt
            renderer.setCameraRotation(angle: cameraAngle)
        }

        // Phase 3: Zoom in then back out (sine curve)
        if isZooming {
            zoomTime += dt
            let t = min(zoomTime / zoomDuration, 1)
            distance = baseDistance + 50 * sin(t * .pi)
        }

        renderer.setCamera(point: Vec3(0, 0, distance))
        let vec = input.getWorldTouch(forZ: 0)

        for obj in objects {
            obj.position += obj.velocity * dt
            if let v = vec { obj.rotation = atan2(v.y, v.x) }
            if obj.position.lengthSquared >= 3600 { randomize(obj: obj) }
        }

        objects.sort(by: Self.isFarther)
    }

    /// Draw order: ascending `zOrder`, far to near.
    /// A `nonisolated` function, not a closure: a closure written in this
    /// `@MainActor` scene would make `sort` check the actor on every comparison.
    private nonisolated static func isFarther(_ lhs: GameObj, _ rhs: GameObj) -> Bool {
        lhs.zOrder < rhs.zOrder
    }

    override func shutdown() {
        super.shutdown()
        renderer.setCameraRotation(angle: 0)
        ui.removeFromSuperview()
    }

    /// Builds the three-phase task chain and adds it to the scheduler.
    private func buildDemoChain() {
        shouldChange = true
        changeTime = 0
        isRotating = false
        cameraAngle = 0
        isZooming = false
        zoomTime = 0
        distance = baseDistance
        startColor = Vec3(0.102, 0.106, 0.149)
        endColor = Vec3(0.255, 0.282, 0.408)
        renderer.setCameraRotation(angle: 0)

        // Phase 1: Swap background color 4 times with smooth crossfades
        let colorSwap = ScheduledTask(time: maxChangeTime, action: { [weak self] _ in
            guard let self else { return }
            self.changeTime = 0
            let temp = self.startColor
            self.startColor = self.endColor
            self.endColor = temp
        }, count: 4, onComplete: { [weak self] _ in
            guard let self else { return }
            self.shouldChange = false
            self.isRotating = true
            self.cameraAngle = 0
        })

        // Phase 2: Camera rotates 360°
        let rotation = colorSwap.then(time: rotationDuration, action: { [weak self] _ in
            guard let self else { return }
            self.isRotating = false
            self.cameraAngle = 0
            self.renderer.setCameraRotation(angle: 0)
        }, count: 1, onComplete: { [weak self] _ in
            guard let self else { return }
            self.isZooming = true
            self.zoomTime = 0
        })

        // Phase 3: Zoom in then back out
        rotation.then(time: zoomDuration, action: { [weak self] _ in
            guard let self else { return }
            self.isZooming = false
            self.distance = self.baseDistance
        }, count: 1, onComplete: { [weak self] _ in
            guard let self else { return }
            self.createObjects()
            self.buildDemoChain()
        })

        scheduler.add(task: colorSwap)
    }

    private func createObjects() {
        objects.removeAll()
        for _ in 0..<objectCount {
            let obj = GameObj()
            obj.add(AlphaBlendComponent(parent: obj, textureID: GameTextures.blue))
            randomize(obj: obj)
            objects.append(obj)
        }
    }

    private func randomize(obj: GameObj) {
        obj.position.set(0, 0)
        let scale = Float.random(in: 0.25...5)
        obj.scale.set(scale, scale)
        let texIndex = Int.random(in: 0...2)
        if let comp = obj.get(AlphaBlendComponent.self) {
            comp.textureID = GameTextures.all[texIndex]
            comp.tintColor = TokyoNight.shipTints[texIndex]
        }
        obj.rotation = Float.random(in: 0...GameMath.twoPi)
        obj.velocity.set(angle: obj.rotation)
        obj.velocity *= Float.random(in: 1...10)
    }

    @objc func onMenu() {
        ui.view.isHidden = true
        sceneMgr.pushScene(type: SceneTypes.pauseDemo)
    }

}
