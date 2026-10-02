//
//  SmokeDemo.swift (file: RocketTrailDemo.swift — rename in Xcode if desired)
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 4/19/26.
//

import SwiftUI
import LiquidMetal2D

/// Demonstrates the alpha-blended variant of `ParticleShader` (new in 0.10.0)
/// plus scale-over-lifetime (also new). Particles start small and tight,
/// billow outward as they age, and fade to transparent — the classic smoke
/// look. Alpha blending composites them correctly over each other (back-
/// to-front sorted by the shader each frame).
///
/// Sliders on the right tune emission rate, speed, start/end scale,
/// lifetime, angle spread, and gravity live. The Neon button toggles
/// between gray and blue-"magical"-smoke palettes.
class SmokeDemo: DefaultScene {
    override class var sceneType: any SceneType { SceneTypes.smokeDemo }

    private let distance: Float = 40

    private var smokeShader: ParticleShader!
    private var emitterObj: GameObj!
    private var emitter: ParticleEmitterComponent!
    private let controls = SmokeControls()
    private var ui: DemoUI!

    // Color palettes. Each has a primary + variation endpoint so particles
    // roll a random hue along the line between them. Alphas kept < 0.5 so
    // smoke stays readable rather than opaque; end alpha is 0 for smooth
    // pop-out.
    private let gray = FirePalette(
        startColor: Vec4(0.70, 0.70, 0.75, 0.40), startVariation: Vec4(0.85, 0.70, 0.90, 0.40),  // lavender-gray
        endColor: Vec4(0.25, 0.25, 0.30, 0.00), endVariation: Vec4(0.30, 0.20, 0.35, 0.00))
    private let neon = FirePalette(
        startColor: Vec4(0.30, 0.65, 1.00, 0.40), startVariation: Vec4(0.50, 0.40, 1.00, 0.40),  // blue → blue-violet
        endColor: Vec4(0.05, 0.15, 0.55, 0.00), endVariation: Vec4(0.15, 0.05, 0.50, 0.00))

    override func initialize(services: SceneServices) {
        super.initialize(services: services)

        renderer.setCamera(point: Vec3(0, 0, distance))
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: Vec3(0.08, 0.09, 0.14))

        guard let defaultRenderer = renderer as? DefaultRenderer else {
            fatalError("SmokeDemo requires DefaultRenderer")
        }
        smokeShader = ParticleShader(
            renderCore: defaultRenderer.renderCore,
            maxObjects: 500,
            blendMode: .alpha)
        renderer.register(shader: smokeShader)

        createEmitter()

        ui = services.demoUI
        controls.onBurst = { [unowned self] in emitter.spawn(count: 40) }
        showOverlay()
    }

    override func resume() { showOverlay() }

    override func update(dt: Float) {
        if let touch = input.getWorldTouch(forZ: 0) {
            emitterObj.position.set(touch.x, touch.y)
        }
        controls.apply(to: emitter, palette: controls.isNeon ? neon : gray)
        emitter.update(dt: dt)
    }

    override func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()

        renderer.useShader(smokeShader)
        renderer.submit(objects: objects)

        renderer.endPass()
    }

    override func shutdown() {
        super.shutdown()
        renderer.unregister(shader: smokeShader)
        ui.overlay = nil
    }

    // MARK: - Emitter

    private func createEmitter() {
        let obj = GameObj()
        obj.position.set(0, -8)

        emitter = ParticleEmitterComponent(
            parent: obj,
            maxParticles: 250,
            textureID: renderer.defaultParticleTextureId,
            emissionRate: 35,
            localOffset: Vec2(),
            lifetimeRange: 2.0...3.5,
            speedRange: 1.5...3.5,
            angleRange: (.pi / 2 - 0.25)...(.pi / 2 + 0.25),
            scaleRange: 2.0...3.5,
            endScaleRange: 8.0...13.0,
            angularVelocityRange: -0.5...0.5,
            startColor: gray.startColor,
            startColorVariation: gray.startVariation,
            endColor: gray.endColor,
            endColorVariation: gray.endVariation,
            correlatedColorVariation: true,
            gravity: Vec2(0, 0.8)
        )
        obj.add(emitter)

        objects.append(obj)
        emitterObj = obj
    }

    // MARK: - UI

    private func showOverlay() {
        ui.overlay = AnyView(SmokePanel(controls: controls))
    }
}

/// The smoke emitter's tunables: like `FireControls` but with a start and an end scale
/// (scale over lifetime) and no pause.
@MainActor
@Observable
final class SmokeControls {
    var emission: Float = 35
    var speed: Float = 2.5
    var startScale: Float = 2.75
    var endScale: Float = 10.5
    var lifetime: Float = 2.75
    var spread: Float = 0.25
    var gravity: Float = 0.8
    var isCorrelated = true
    var isNeon = false
    var onBurst: () -> Void = {}

    /// Actual ranges are ±`rangeSpread` around each midpoint so randomness is preserved.
    private let rangeSpread: Float = 0.3

    func apply(to emitter: ParticleEmitterComponent, palette: FirePalette) {
        emitter.emissionRate = emission
        emitter.speedRange = around(speed)
        emitter.scaleRange = around(startScale)
        emitter.endScaleRange = around(endScale)
        emitter.lifetimeRange = around(lifetime)
        emitter.angleRange = (.pi / 2 - spread)...(.pi / 2 + spread)
        emitter.gravity = Vec2(0, gravity)
        emitter.correlatedColorVariation = isCorrelated
        emitter.startColor = palette.startColor
        emitter.startColorVariation = palette.startVariation
        emitter.endColor = palette.endColor
        emitter.endColorVariation = palette.endVariation
    }

    private func around(_ center: Float) -> ClosedRange<Float> {
        (center * (1 - rangeSpread))...(center * (1 + rangeSpread))
    }
}

struct SmokePanel: View {
    @Bindable var controls: SmokeControls

    var body: some View {
        ZStack {
            ControlColumn {
                Toggle("Correlated", isOn: $controls.isCorrelated)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(TokyoNight.color(TokyoNight.fg))
                    .tint(TokyoNight.color(TokyoNight.blue))
                LabeledSlider(title: "Emission", value: $controls.emission, range: 5...120, format: "%.0f/s")
                LabeledSlider(title: "Speed", value: $controls.speed, range: 0.5...8)
                LabeledSlider(title: "Start Scale", value: $controls.startScale, range: 0.5...6)
                LabeledSlider(title: "End Scale", value: $controls.endScale, range: 2...18)
                LabeledSlider(title: "Lifetime", value: $controls.lifetime, range: 0.5...6, format: "%.2fs")
                LabeledSlider(title: "Spread", value: $controls.spread, range: 0.01...(.pi), format: "%.2f rad")
                LabeledSlider(title: "Gravity Y", value: $controls.gravity, range: -10...10, format: "%+.1f")
            }
            BottomBar {
                Button("Burst", action: controls.onBurst)
                Button(controls.isNeon ? "Gray" : "Neon") { controls.isNeon.toggle() }
            }
        }
    }
}
