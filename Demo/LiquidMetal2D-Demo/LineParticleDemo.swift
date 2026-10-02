//
//  LineParticleDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 4/26/26.
//

import SwiftUI
import LiquidMetal2D

/// Mirror of ``ParticleDemo`` that exercises ``EmitterShape/line`` instead
/// of the default point emitter — particles spawn uniformly along a 10-unit
/// horizontal segment, producing a wall-of-fire look.
///
/// All other tunables match ParticleDemo (it shares `FireControls` and
/// `FirePanel`) so this scene is a side-by-side visual check that the shape
/// change is the only thing different.
class LineParticleDemo: DefaultScene {
    override class var sceneType: any SceneType { SceneTypes.lineParticleDemo }

    private let distance: Float = 40

    private var particleShader: ParticleShader!
    private var emitterObj: GameObj!
    private var emitter: ParticleEmitterComponent!
    private let controls = FireControls()
    private var ui: DemoUI!

    private let fire = FirePalette(
        startColor: Vec4(1.0, 0.55, 0.15, 0.7), startVariation: Vec4(1.0, 0.85, 0.20, 0.7),
        endColor: Vec4(0.9, 0.10, 0.00, 0.0), endVariation: Vec4(0.5, 0.00, 0.00, 0.0))
    private let neon = FirePalette(
        startColor: Vec4(1.0, 0.30, 0.75, 0.7), startVariation: Vec4(0.75, 0.30, 1.0, 0.7),
        endColor: Vec4(0.5, 0.00, 0.55, 0.0), endVariation: Vec4(0.3, 0.00, 0.70, 0.0))

    override func initialize(services: SceneServices) {
        super.initialize(services: services)

        renderer.setCamera(point: Vec3(0, 0, distance))
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: Vec3(0.02, 0.02, 0.05))

        guard let defaultRenderer = renderer as? DefaultRenderer else {
            fatalError("LineParticleDemo requires DefaultRenderer")
        }
        particleShader = ParticleShader(
            renderCore: defaultRenderer.renderCore,
            maxObjects: 500)
        renderer.register(shader: particleShader)

        createEmitter()

        ui = services.demoUI
        controls.onBurst = { [unowned self] in emitter.spawn(count: 60) }
        controls.altPaletteName = "Neon"
        showOverlay()
    }

    override func resume() { showOverlay() }

    override func update(dt: Float) {
        if let touch = input.getWorldTouch(forZ: 0) {
            emitterObj.position.set(touch.x, touch.y)
        }
        controls.apply(to: emitter, palette: controls.isAltPalette ? neon : fire)
        emitter.update(dt: dt)
    }

    override func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()

        renderer.useShader(particleShader)
        renderer.submit(objects: objects)

        renderer.endPass()
    }

    override func shutdown() {
        super.shutdown()
        renderer.unregister(shader: particleShader)
        ui.overlay = nil
    }

    // MARK: - Emitter

    private func createEmitter() {
        let obj = GameObj()
        obj.position.set(0, -6)

        emitter = ParticleEmitterComponent(
            parent: obj,
            maxParticles: 400,
            textureID: renderer.defaultParticleTextureId,
            emissionRate: 140,
            localOffset: Vec2(),
            // Only differs from ParticleDemo: spawns spread across a
            // 20-unit horizontal segment instead of a single point.
            shape: .line(from: Vec2(-10, 0), to: Vec2(10, 0)),
            lifetimeRange: 0.8...1.6,
            speedRange: 6...14,
            angleRange: (.pi / 2 - 0.25)...(.pi / 2 + 0.25),
            scaleRange: 4...8,
            angularVelocityRange: -1...1,
            startColor: fire.startColor,
            startColorVariation: fire.startVariation,
            endColor: fire.endColor,
            endColorVariation: fire.endVariation,
            correlatedColorVariation: true,
            gravity: Vec2(0, 1))
        obj.add(emitter)

        objects.append(obj)
        emitterObj = obj
    }

    // MARK: - UI

    private func showOverlay() {
        ui.overlay = AnyView(FirePanel(controls: controls))
    }
}
