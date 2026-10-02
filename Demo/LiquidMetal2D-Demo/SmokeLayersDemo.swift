//
//  SmokeLayersDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 9/25/26.
//

import SwiftUI
import LiquidMetal2D

/// Two alpha-blended smoke plumes rising side by side at different depths, overlapping in the middle. Shows that
/// `ParticleShader` in `.alpha` mode draws emitters far to near (new in 0.15.0; before, it
/// drew them near to far).
///
/// **What to look for:**
/// - **The bigger plume is on top where they overlap.** Perspective draws the nearer emitter
///   larger, and "over" blending must draw it last, so it covers the far one in the middle.
///   If the order were backwards, the small far plume would paint over the big near one.
/// - **Swap** exchanges the two emitters' `zOrder`. The other colour becomes the big one and
///   moves on top at once — the shader re-sorts emitters every frame.
/// - Larger `zOrder` is closer to the camera (it sits at `z = distance` looking down −z).
class SmokeLayersDemo: DefaultScene {
    override class var sceneType: any SceneType { SceneTypes.smokeLayersDemo }

    private let distance: Float = 40
    private let nearZ: Float = 12
    private let farZ: Float = -12
    /// Sideways distance of each plume from the centre: far enough that both show, close
    /// enough that they overlap in the middle.
    private let plumeOffset: Float = 1.5

    private var smokeShader: ParticleShader!
    private var warmPlume: GameObj!
    private var coolPlume: GameObj!
    private let controls = SmokeLayersControls()
    private var ui: DemoUI!

    // Fairly opaque so "which one is on top" is obvious, fading out at the end.
    private let warmStart = Vec4(1.00, 0.62, 0.39, 0.65)   // Tokyo Night orange
    private let warmEnd   = Vec4(0.97, 0.46, 0.56, 0.00)   // → red
    private let coolStart = Vec4(0.17, 0.77, 0.87, 0.65)   // cyan
    private let coolEnd   = Vec4(0.48, 0.64, 0.97, 0.00)   // → blue

    override func initialize(services: SceneServices) {
        super.initialize(services: services)

        renderer.setCamera(point: Vec3(0, 0, distance))
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        guard let defaultRenderer = renderer as? DefaultRenderer else {
            fatalError("SmokeLayersDemo requires DefaultRenderer")
        }
        smokeShader = ParticleShader(
            renderCore: defaultRenderer.renderCore,
            maxObjects: 600,
            blendMode: .alpha)
        renderer.register(shader: smokeShader)

        warmPlume = makePlume(x: -plumeOffset, startColor: warmStart, endColor: warmEnd, zOrder: nearZ)
        coolPlume = makePlume(x: plumeOffset, startColor: coolStart, endColor: coolEnd, zOrder: farZ)

        ui = services.demoUI
        controls.onSwap = { [unowned self] in swapPlumes() }
        updateStatus()
        showOverlay()
    }

    override func resume() { showOverlay() }

    override func update(dt: Float) {
        warmPlume.get(ParticleEmitterComponent.self)?.update(dt: dt)
        coolPlume.get(ParticleEmitterComponent.self)?.update(dt: dt)
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

    // MARK: - Emitters

    /// Where the plumes overlap, only draw order decides which colour covers the other.
    private func makePlume(x: Float, startColor: Vec4, endColor: Vec4, zOrder: Float) -> GameObj {
        let obj = GameObj()
        obj.position.set(x, -10)
        obj.zOrder = zOrder
        obj.add(ParticleEmitterComponent(
            parent: obj,
            maxParticles: 280,
            textureID: renderer.defaultParticleTextureId,
            emissionRate: 45,
            shape: .circle(radius: 1.5),
            lifetimeRange: 2.5...3.5,
            speedRange: 2.5...4.0,
            angleRange: (.pi / 2 - 0.3)...(.pi / 2 + 0.3),
            scaleRange: 2.5...3.5,
            endScaleRange: 9.0...12.0,
            angularVelocityRange: -0.5...0.5,
            startColor: startColor,
            endColor: endColor,
            gravity: Vec2(0, 0.6)))
        objects.append(obj)
        return obj
    }

    // MARK: - Actions

    private func swapPlumes() {
        swap(&warmPlume.zOrder, &coolPlume.zOrder)
        updateStatus()
    }

    private func updateStatus() {
        let nearName = warmPlume.zOrder > coolPlume.zOrder ? "Orange" : "Cyan"
        controls.status = "\(nearName) is near — it should be bigger and on top in the middle"
    }

    // MARK: - UI

    private func showOverlay() {
        ui.overlay = AnyView(SmokeLayersPanel(controls: controls))
    }
}

/// The status line and the Swap button.
@MainActor
@Observable
final class SmokeLayersControls {
    var status = ""
    var onSwap: () -> Void = {}
}

struct SmokeLayersPanel: View {
    let controls: SmokeLayersControls

    var body: some View {
        ZStack(alignment: .top) {
            Text(controls.status)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(TokyoNight.color(TokyoNight.blue))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 56)
            BottomBar {
                Button("Swap", action: controls.onSwap)
            }
        }
    }
}
