//
//  LightingDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 10/5/26.
//

import SwiftUI
import LiquidMetal2D

/// Lighting demo: a dark room, lamps that cast shadows, a sweeping guard cone,
/// a neon sign that stays bright, and the stick figure walking through it all.
///
/// **What it shows:**
/// - **`LightMap`:** every frame the scene draws its lights into the map first
///   (`begin` → `ambient` → `add` → `commit`), then draws the room and, inside the
///   pass, `renderer.composite(lightMap)` multiplies the map over it.
/// - **Shadows:** each shadowed light passes a `VisibilityPolygon` outline computed
///   from the room's wall segments (`LineSegment.appendEdges`). Shadows off shows the
///   plain pools and cone for comparison.
/// - **Cones:** the red "guard" light is a cone sweeping back and forth; its edge
///   fades over `edgeSoftness`.
/// - **Emissive:** the cyan sign is submitted after the composite, so the dark never
///   touches it.
/// - **Ambient:** the floor the lights add to; cycle it to see the room in near dark
///   and in dusk.
///
/// The white lamp follows the pointer: hover on the Mac, a finger on iOS.
class LightingDemo: LiquidMetal2D.Scene {
    static var sceneType: any SceneType { SceneTypes.lightingDemo }

    private var renderer: Renderer!
    private var input: InputReader!
    private var ui: DemoUI!

    private let figureScale: Float = 2
    private let floorY: Float = -14
    private let ceilingY: Float = 14
    private let walkSpeed: Float = 14
    private let walkRange: Float = 22
    private static let ambients: [(name: String, value: Vec3)] = [
        ("dark", Vec3(0.02, 0.025, 0.04)),
        ("dim", Vec3(0.06, 0.07, 0.12)),
        ("dusk", Vec3(0.25, 0.26, 0.32))
    ]

    private var lightMap: LightMap!
    private var visibility = VisibilityPolygon()
    private var walls: [LineSegment] = []
    private var room: [GameObj] = []
    private var sign: [GameObj] = []

    private var root: GameObj!
    private var skeleton: SkeletonComponent!
    private var walkDirection: Float = 1

    private var lamps: [Light] = []
    private var pointerLamp = Light(position: Vec2(0, 0), radius: 20, color: Vec3(1, 1, 1))
    private var guardCone = Light(position: Vec2(20, -12), radius: 30, color: Vec3(1, 0.25, 0.2))
    private let guardFacing: Float = .pi - 0.35
    private var time: Float = 0

    private var ambientIndex = 1
    private let controls = LightingControls()

    func initialize(services: SceneServices) {
        self.renderer = services.renderer
        self.input = services.input
        self.ui = services.demoUI

        renderer.setCamera()
        renderer.setCameraRotation(angle: 0)
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        lightMap = renderer.makeLightMap()
        buildRoom()
        buildSign()
        buildFigure()
        buildLights()

        controls.onShadows = { [unowned self] in controls.shadows.toggle() }
        controls.onAmbient = { [unowned self] in
            ambientIndex = (ambientIndex + 1) % Self.ambients.count
            controls.ambientName = Self.ambients[ambientIndex].name
        }
        controls.onComposite = { [unowned self] in controls.composite.toggle() }
        controls.ambientName = Self.ambients[ambientIndex].name
        showOverlay()
    }

    func resume() { showOverlay() }

    func resize() {
        renderer.setDefaultPerspective()
    }

    func update(dt: Float) {
        time += dt
        if let pointer = input.pointerWorld(forZ: 0) {
            pointerLamp.position = Vec2(pointer.x, pointer.y)
        }
        guardCone.direction = guardFacing + 0.6 * sin(time * 2 * .pi / 3)

        root.position.x += walkDirection * walkSpeed * dt
        if abs(root.position.x) > walkRange {
            walkDirection = -walkDirection
            root.position.x = walkDirection * -walkRange
            skeleton.flipX = walkDirection < 0
        }
        skeleton.update(dt: dt)
    }

    func draw() {
        // 1. Lights, into the light map, on their own command buffer.
        guard lightMap.begin() else { return }
        lightMap.ambient = Self.ambients[ambientIndex].value
        for lamp in lamps {
            add(lamp)
        }
        add(pointerLamp)
        add(guardCone)
        lightMap.commit()
        controls.readout = "lights \(lightMap.lightCount)  vertices \(lightMap.vertexCount)"

        // 2. The room, then the light map multiplied over it.
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        renderer.submit(objects: room + skeleton.parts)
        if controls.composite {
            renderer.composite(lightMap)
        }
        // 3. Emissive: after the composite, so it stays bright.
        renderer.submit(objects: sign)
        renderer.endPass()
    }

    func shutdown() {
        ui.overlay = nil
    }

    static func build() -> LiquidMetal2D.Scene { LightingDemo() }

    /// Adds `light` with its visibility outline when shadows are on.
    private func add(_ light: Light) {
        guard controls.shadows else {
            lightMap.add(light)
            return
        }
        visibility.compute(
            from: light.position, radius: light.radius, walls: walls,
            direction: light.direction, halfAngle: light.halfAngle)
        lightMap.add(light, outline: visibility.points)
    }

    // MARK: - Setup

    private func buildRoom() {
        // A back wall behind everything: the lights need a surface to land on,
        // since the composite multiplies and the clear colour is near black.
        let back = GameObj()
        back.position = Vec2(0, 0)
        back.scale = Vec2(60, ceilingY - floorY)
        back.zOrder = -0.05
        back.add(AlphaBlendComponent(
            parent: back, textureID: renderer.defaultTextureId, tintColor: Vec4(0.55, 0.56, 0.62, 1)))
        room.append(back)

        addBox(center: Vec2(0, floorY - 0.5), size: Vec2(60, 1), tint: TokyoNight.dark)
        addBox(center: Vec2(0, ceilingY + 0.5), size: Vec2(60, 1), tint: TokyoNight.dark)
        addBox(center: Vec2(-13, -9), size: Vec2(3, 10), tint: TokyoNight.darker)
        addBox(center: Vec2(7, -10), size: Vec2(2.5, 8), tint: TokyoNight.darker)
        addBox(center: Vec2(-3, 5), size: Vec2(10, 1.5), tint: TokyoNight.darker)
        addBox(center: Vec2(15, 3), size: Vec2(2.5, 7), tint: TokyoNight.darker)
    }

    /// A box the alpha-blend shader draws and the lights see as four walls.
    private func addBox(center: Vec2, size: Vec2, tint: Vec4) {
        let box = GameObj()
        box.position = center
        box.scale = size
        box.add(AlphaBlendComponent(parent: box, textureID: renderer.defaultTextureId, tintColor: tint))
        room.append(box)
        LineSegment.appendEdges(ofCenter: center, width: size.x, height: size.y, to: &walls)
    }

    /// A cyan sign in the top-left corner: three bars that spell nothing.
    private func buildSign() {
        let bars = [(Vec2(-24, 10), Vec2(0.6, 5)), (Vec2(-22, 12), Vec2(3.5, 0.6)), (Vec2(-21, 8.5), Vec2(5, 0.6))]
        for (offset, size) in bars {
            let bar = GameObj()
            bar.position = offset
            bar.scale = size
            bar.zOrder = 0.02
            bar.add(AlphaBlendComponent(parent: bar, textureID: renderer.defaultTextureId, tintColor: TokyoNight.cyan))
            sign.append(bar)
        }
    }

    private func buildFigure() {
        root = GameObj()
        root.position.set(-walkRange, floorY + StickFigure.feetBelowHips * figureScale)
        do {
            let (rig, clips) = try StickFigure.load()
            skeleton = try SkeletonComponent(
                parent: root, definition: rig, defaultTextureID: renderer.defaultTextureId,
                textureIDs: [StickFigure.discTexture: GameTextures.disc])
            skeleton.animator.play(clips.walk)
        } catch {
            fatalError("StickFigure files are missing or invalid: \(error)")
        }
        skeleton.scale = figureScale
        root.add(skeleton)
    }

    private func buildLights() {
        var yellow = Light(position: Vec2(-9, ceilingY - 1), radius: 26, color: Vec3(0.88, 0.69, 0.41))
        yellow.falloff = 1.5
        var orange = Light(position: Vec2(11, ceilingY - 1), radius: 24, color: Vec3(1, 0.62, 0.39))
        orange.falloff = 1.5
        lamps = [yellow, orange]
        pointerLamp.position = Vec2(0, -6)
        pointerLamp.falloff = 1.5
        guardCone.halfAngle = 0.45
        guardCone.falloff = 1
    }

    // MARK: - UI

    private func showOverlay() {
        ui.overlay = AnyView(LightingPanel(controls: controls))
    }
}

/// What the lighting panel shows and does.
@MainActor
@Observable
final class LightingControls {
    var onShadows: () -> Void = {}
    var onAmbient: () -> Void = {}
    var onComposite: () -> Void = {}
    var shadows = true
    var composite = true
    var ambientName = ""
    var readout = ""
}

struct LightingPanel: View {
    let controls: LightingControls

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(controls.readout)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(TokyoNight.color(TokyoNight.comment))
                .padding(8)

            BottomBar {
                Button(controls.shadows ? "Shadows: On" : "Shadows: Off", action: controls.onShadows)
                Button("Ambient: \(controls.ambientName)", action: controls.onAmbient)
                Button(controls.composite ? "Lit" : "Unlit", action: controls.onComposite)
            }
        }
    }
}
