//
//  ParticleDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 4/19/26.
//

import SwiftUI
import LiquidMetal2D

/// Showcases `ParticleShader` — a fourth engine shader doing additive-blended,
/// texture-sampled particles with order-independent compositing.
///
/// **What the user sees:** a campfire-like emitter shoots orange/red glowy
/// particles upward. Touch and drag anywhere on the Metal view to move the
/// emitter; particles already in flight continue on their existing path
/// (they don't follow the emitter after birth). Buttons: `Burst` spawns
/// 60 particles at once, `Pause` toggles continuous emission, `Neon` swaps
/// the palette. Sliders on the right tune the emitter live.
///
/// **Engine features demonstrated:**
/// - `ParticleEmitterComponent` — pre-allocated particle pool, per-frame
///   `update(dt:)` advances live particles and spawns new ones.
/// - `ParticleShader` with additive blending — overlapping particles
///   brighten into hotspots; no z-sort needed.
/// - `renderer.defaultParticleTextureId` — the engine's built-in 64×64
///   soft-circle glow texture, no asset files required.
class ParticleDemo: DefaultScene {
    override class var sceneType: any SceneType { SceneTypes.particleDemo }

    private let distance: Float = 40

    private var particleShader: ParticleShader!
    private var emitterObj: GameObj!
    private var emitter: ParticleEmitterComponent!
    private let controls = FireControls()
    private var ui: DemoUI!

    // Color palette with matched start-color + variation endpoints and
    // end-color + variation endpoints. Each particle picks a random t
    // between the start pair (and, correlated, the end pair), so overlap
    // brightens in a range of warm hues instead of a single color.
    private let fire = FirePalette(
        startColor: Vec4(1.0, 0.55, 0.15, 0.7), startVariation: Vec4(1.0, 0.85, 0.20, 0.7),   // warm yellow
        endColor: Vec4(0.9, 0.10, 0.00, 0.0), endVariation: Vec4(0.5, 0.00, 0.00, 0.0))        // deep red
    private let neon = FirePalette(
        startColor: Vec4(1.0, 0.30, 0.75, 0.7), startVariation: Vec4(0.75, 0.30, 1.0, 0.7),   // pink → purple
        endColor: Vec4(0.5, 0.00, 0.55, 0.0), endVariation: Vec4(0.3, 0.00, 0.70, 0.0))

    override func initialize(services: SceneServices) {
        super.initialize(services: services)

        renderer.setCamera(point: Vec3(0, 0, distance))
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: Vec3(0.02, 0.02, 0.05))  // near-black to let glow pop

        guard let defaultRenderer = renderer as? DefaultRenderer else {
            fatalError("ParticleDemo requires DefaultRenderer")
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
        // Drag to reposition the emitter. Touches on the SwiftUI controls are
        // eaten by SwiftUI and never reach the input reader, so the panel
        // doesn't accidentally teleport the emitter.
        if let touch = input.getWorldTouch(forZ: 0) {
            emitterObj.position.set(touch.x, touch.y)
        }
        controls.apply(to: emitter, palette: controls.isAltPalette ? neon : fire)
        emitter.update(dt: dt)
    }

    override func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()

        // No alpha-blend pass — the emitter anchor has no AlphaBlendComponent.
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
        obj.position.set(0, -6)  // slightly below center so upward particles fill the screen

        emitter = ParticleEmitterComponent(
            parent: obj,
            maxParticles: 400,
            textureID: renderer.defaultParticleTextureId,
            emissionRate: 140,
            localOffset: Vec2(),
            lifetimeRange: 0.8...1.6,
            speedRange: 6...14,
            // Upward cone. rotation=0 emits rightward (+X), so shift by pi/2 for +Y.
            angleRange: (.pi / 2 - 0.25)...(.pi / 2 + 0.25),
            scaleRange: 4...8,
            angularVelocityRange: -1...1,
            // Warm palette — each particle picks a random lerp between the
            // orange/yellow endpoints and dies somewhere between red/dark-red.
            startColor: fire.startColor,
            startColorVariation: fire.startVariation,
            endColor: fire.endColor,
            endColorVariation: fire.endVariation,
            correlatedColorVariation: true,
            gravity: Vec2(0, 1)   // slight buoyancy — particles accelerate upward
        )
        obj.add(emitter)

        objects.append(obj)
        emitterObj = obj
    }

    // MARK: - UI

    private func showOverlay() {
        ui.overlay = AnyView(FirePanel(controls: controls))
    }
}

/// A particle colour scheme: start and end colours with their variation endpoints.
struct FirePalette {
    let startColor: Vec4
    let startVariation: Vec4
    let endColor: Vec4
    let endVariation: Vec4
}

/// The tunables of a point or line fire emitter. Sliders set the midpoint of each range;
/// the scene applies them to the emitter every frame (`apply(to:palette:)`).
@MainActor
@Observable
final class FireControls {
    var emission: Float = 140
    var speed: Float = 10
    var scale: Float = 6
    var lifetime: Float = 1.2
    var spread: Float = 0.25
    var gravity: Float = 1
    var isCorrelated = true
    var isEmitting = true
    var isAltPalette = false
    var altPaletteName = "Neon"
    var onBurst: () -> Void = {}

    /// Actual min/max is ±`rangeSpread` around each slider's midpoint, so randomness is
    /// preserved. Tweak the spread fraction to make particles more/less uniform.
    private let rangeSpread: Float = 0.3

    func apply(to emitter: ParticleEmitterComponent, palette: FirePalette) {
        emitter.emissionRate = emission
        emitter.speedRange = around(speed)
        emitter.scaleRange = around(scale)
        emitter.lifetimeRange = around(lifetime)
        // Emit direction stays pointed up (pi/2); spread widens the cone.
        emitter.angleRange = (.pi / 2 - spread)...(.pi / 2 + spread)
        emitter.gravity = Vec2(0, gravity)
        emitter.correlatedColorVariation = isCorrelated
        emitter.isEmitting = isEmitting
        emitter.startColor = palette.startColor
        emitter.startColorVariation = palette.startVariation
        emitter.endColor = palette.endColor
        emitter.endColorVariation = palette.endVariation
    }

    private func around(_ center: Float) -> ClosedRange<Float> {
        (center * (1 - rangeSpread))...(center * (1 + rangeSpread))
    }
}

/// The fire emitter's slider column and button row.
struct FirePanel: View {
    @Bindable var controls: FireControls

    var body: some View {
        ZStack {
            ControlColumn {
                Toggle("Correlated", isOn: $controls.isCorrelated)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(TokyoNight.color(TokyoNight.fg))
                    .tint(TokyoNight.color(TokyoNight.blue))
                LabeledSlider(title: "Emission", value: $controls.emission, range: 10...400, format: "%.0f/s")
                LabeledSlider(title: "Speed", value: $controls.speed, range: 2...24)
                LabeledSlider(title: "Scale", value: $controls.scale, range: 1...12)
                LabeledSlider(title: "Lifetime", value: $controls.lifetime, range: 0.2...3.0, format: "%.2fs")
                LabeledSlider(title: "Spread", value: $controls.spread, range: 0.01...(.pi), format: "%.2f rad")
                LabeledSlider(title: "Gravity Y", value: $controls.gravity, range: -20...20, format: "%+.1f")
            }
            BottomBar {
                Button("Burst", action: controls.onBurst)
                Button(controls.isEmitting ? "Pause" : "Resume") { controls.isEmitting.toggle() }
                Button(controls.isAltPalette ? "Fire" : controls.altPaletteName) { controls.isAltPalette.toggle() }
            }
        }
    }
}
