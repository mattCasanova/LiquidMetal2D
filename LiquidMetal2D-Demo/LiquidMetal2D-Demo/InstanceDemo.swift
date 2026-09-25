//
//  InstanceDemo.swift
//  LiquidMetal2D-Demo
//
//  Originally SecondScene by Matt Casanova on 3/13/20.
//

import UIKit
import LiquidMetal2D

/// Explosion / radial burst demo with touch-to-rotate.
///
/// **What the user sees:** Ships spawn at the center and fly outward in random
/// directions at varying speeds. Touch the screen to rotate ALL ships toward
/// the touch point. Ships that travel too far from center respawn.
/// The background smoothly cycles between two colors.
///
/// **Engine features demonstrated:**
/// - **DefaultScene subclassing:** Inherits camera setup, projection, draw,
///   resize, and shutdown. Only overrides `initialize` and `update`.
/// - **Mass rendering with velocity:** Position updated via `position += velocity * dt`.
/// - **Touch rotation:** `input.getWorldTouch(forZ:)` + `atan2` rotates all ships.
/// - **Z-order sorting:** Ships sorted by `zOrder` each frame for correct draw order.
class InstanceDemo: DefaultScene {
    override class var sceneType: any SceneType { SceneTypes.instanceDemo }

    var changeTime: Float = 0
    let maxChangeTime: Float = 2
    var distance: Float = 40
    let objectCount = GameConstants.MAX_OBJECTS

    var startColor = Vec3(0.102, 0.106, 0.149)
    var endColor = Vec3(0.337, 0.373, 0.537)

    private var ui: DemoSceneUI!

    override func initialize(services: SceneServices) {
        super.initialize(services: services)

        createObjects()

        ui = DemoSceneUI(
            parentView: renderer.view, target: self,
            menuAction: #selector(onMenu))
    }

    override func resume() { ui.view.isHidden = false }

    override func resize() {
        super.resize()
        ui.layout()
    }

    override func update(dt: Float) {
        changeTime += dt
        let t = changeTime / maxChangeTime
        renderer.setClearColor(color: startColor.lerp(to: endColor, t: t))
        renderer.setCamera(point: Vec3(0, 0, distance))

        let vec = input.getWorldTouch(forZ: 0)

        if changeTime >= maxChangeTime {
            changeTime = 0
            let temp = startColor
            startColor = endColor
            endColor = temp
        }

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
        ui.removeFromSuperview()
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
        obj.zOrder = [-10, 0, 10].randomElement()!
        obj.rotation = Float.random(in: 0...GameMath.twoPi)
        obj.velocity.set(angle: obj.rotation)
        obj.velocity *= Float.random(in: 1...10)
    }

    @objc func onMenu() {
        ui.view.isHidden = true
        sceneMgr.pushScene(type: SceneTypes.pauseDemo)
    }

}
