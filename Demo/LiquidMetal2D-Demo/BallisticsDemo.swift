//
//  BallisticsDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 10/22/26.
//

import SwiftUI
import LiquidMetal2D

/// Ballistics demo: aim a ship, see its arc and where it lands, launch it
/// and watch it land exactly there.
///
/// **What it shows:**
/// - **`ArcSweep`:** every frame the scene traces the arc from the ship with
///   the ship's half-size against the room's boxes and draws dots along
///   `samples`; the landing marker sits on `hit.point`, tinted by the face hit
///   (green floor, yellow wall, red ceiling).
/// - **Preview equals outcome:** Launch copies `samples` and the ship steps
///   along them at the sweep's `dt`, so it stops on the marker every time.
/// - **`Ballistics`:** the readout's apex height and flight time, and the
///   "Hit cursor" mode, which asks `launchVelocity(speed:)` for the arc that
///   passes through the cursor at full speed (none when it is out of range).
///
/// Aim with the pointer: hover on the Mac, a finger on iOS (lifting it does
/// not launch). Launch with the button, Space or Return; Reset with the
/// button or R. Until the first touch, click or key it plays by itself:
/// the aim sweeps and the ship launches every few seconds.
class BallisticsDemo: LiquidMetal2D.Scene {
    static var sceneType: any SceneType { SceneTypes.ballisticsDemo }

    /// A rect the renderer draws and the sweep tests.
    private struct Box: AABB {
        var center: Vec2
        var width: Float
        var height: Float
    }

    private enum Flight {
        case aiming
        case flying(elapsed: Float)
        case landed
    }

    private var renderer: Renderer!
    private var input: InputReader!
    private var ui: DemoUI!

    private let floorY: Float = -14
    private let ceilingY: Float = 14
    private let sideX: Float = 29
    private let gravity = Vec2(0, -30)
    private let maxSpeed: Float = 30
    private let aimGain: Float = 1.5
    private let shipHalfSize = Vec2(1, 1)
    private let dotEvery = 3
    private let dotCount = 48

    private var boxes: [Box] = []
    private var room: [GameObj] = []
    private var ship: GameObj!
    private var shipHome = Vec2()
    private var dots: [GameObj] = []
    private var marker: GameObj!

    private var sweep = ArcSweep()
    private var velocity = Vec2(12, 18)
    private var flightPath: [Vec2] = []
    /// The velocity the current flight left with, for its heading along the way.
    private var launchVelocity = Vec2()
    private var flight = Flight.aiming
    private let controls = BallisticsControls()

    /// Plays by itself until the first input.
    private var isAutoplay = true
    private var autoplayTime: Float = 0
    private let autoplayLaunchEvery: Float = 3
    private let autoplayRestFor: Float = 1.2

    func initialize(services: SceneServices) {
        self.renderer = services.renderer
        self.input = services.input
        self.ui = services.demoUI

        renderer.setCamera()
        renderer.setCameraRotation(angle: 0)
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        flightPath.reserveCapacity(256)
        buildRoom()
        buildShip()
        buildPreview()

        controls.onLaunch = { [unowned self] in isAutoplay = false; launch() }
        controls.onReset = { [unowned self] in isAutoplay = false; reset() }
        controls.onMode = { [unowned self] in isAutoplay = false; controls.hitCursor.toggle() }
        showOverlay()
    }

    func resume() { showOverlay() }

    func resize() {
        renderer.setDefaultPerspective()
    }

    func update(dt: Float) {
        if input.isAnyTriggered || input.pointer.location != nil { isAutoplay = false }
        if input.isTriggered(.space) || input.isTriggered(.returnKey) { launch() }
        if input.isTriggered(.r) { reset() }
        if isAutoplay { autoplay(dt: dt) }

        switch flight {
        case .aiming:
            if isAutoplay { sweepAim() } else { aim() }
            ship.rotation = velocity.angle
            preview()
        case .flying(let elapsed):
            fly(elapsed: elapsed + dt)
        case .landed:
            break
        }
    }

    func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        renderer.submit(objects: room + dots + [marker, ship])
        renderer.endPass()
    }

    func shutdown() {
        ui.overlay = nil
    }

    static func build() -> LiquidMetal2D.Scene { BallisticsDemo() }

    // MARK: - Aiming and flying

    /// Launches every few seconds and resets a moment after landing.
    private func autoplay(dt: Float) {
        autoplayTime += dt
        switch flight {
        case .aiming where autoplayTime >= autoplayLaunchEvery:
            launch()
            autoplayTime = 0
        case .landed where autoplayTime >= autoplayRestFor:
            reset()
            autoplayTime = 0
        default:
            break
        }
    }

    /// The autoplay's aim: a slow sweep through angles and speeds.
    private func sweepAim() {
        let phase = autoplayTime / autoplayLaunchEvery
        let angle = GameMath.lerp(a: 0.35, b: 1.1, t: 0.5 + 0.5 * sin(phase * .pi * 2 + 1))
        let speed = GameMath.lerp(a: 20, b: maxSpeed, t: 0.5 + 0.5 * cos(phase * .pi * 2))
        velocity = Vec2(angle: angle) * speed
        controls.outOfRange = false
    }

    /// The launch velocity from the pointer: a pull from the ship, or in
    /// "Hit cursor" mode the full-speed arc through the cursor.
    private func aim() {
        guard let pointer = input.pointerWorld(forZ: 0) else { return }
        let target = Vec2(pointer.x, pointer.y)
        if controls.hitCursor {
            if let through = Ballistics.launchVelocity(
                from: ship.position, to: target, speed: maxSpeed, gravity: gravity) {
                velocity = through
                controls.outOfRange = false
            } else {
                controls.outOfRange = true
            }
        } else {
            var pull = (target - ship.position) * aimGain
            if pull.length > maxSpeed { pull = pull.normalized * maxSpeed }
            velocity = pull
            controls.outOfRange = false
        }
    }

    /// Traces the arc and lays the dots and the marker along it.
    private func preview() {
        let result = sweep.trace(
            from: ship.position, velocity: velocity, gravity: gravity, halfSize: shipHalfSize, boxes: boxes)
        let samples = sweep.samples
        for (index, dot) in dots.enumerated() {
            let sample = index * dotEvery
            dot.isActive = sample < samples.count && !controls.outOfRange
            if dot.isActive { dot.position = samples[sample] }
        }
        let apex = Ballistics.apex(start: ship.position, velocity: velocity, gravity: gravity)
        switch result {
        case .hit(let hit):
            marker.isActive = !controls.outOfRange
            marker.position = hit.point
            marker.get(AlphaBlendComponent.self)?.tintColor = Self.tint(forNormal: hit.normal)
            controls.readout = String(
                format: "apex %.1f  flight %.2fs\n%@  steps %d",
                apex.y - ship.position.y, hit.time, Self.face(of: hit.normal), samples.count)
        case .noHit(let endTime):
            marker.isActive = false
            controls.readout = String(
                format: "apex %.1f  flight %.2fs+\nno hit  steps %d",
                apex.y - ship.position.y, endTime, samples.count)
        }
        if controls.outOfRange {
            controls.readout = "out of range at speed \(Int(maxSpeed))"
        }
    }

    private func launch() {
        guard case .aiming = flight, !controls.outOfRange else { return }
        flightPath.removeAll(keepingCapacity: true)
        flightPath.append(contentsOf: sweep.samples)
        launchVelocity = velocity
        flight = .flying(elapsed: 0)
    }

    /// Steps the ship along the path at the sweep's `dt`, so it lands on the
    /// marker, its nose along the velocity at that moment.
    private func fly(elapsed: Float) {
        let step = min(Int(elapsed / sweep.dt), flightPath.count - 1)
        ship.position = flightPath[step]
        let heading = Ballistics.velocity(launchVelocity, gravity: gravity, at: Float(step) * sweep.dt)
        ship.rotation = heading.angle
        if step == flightPath.count - 1 {
            flight = .landed
        } else {
            flight = .flying(elapsed: elapsed)
        }
    }

    private func reset() {
        ship.position = shipHome
        flight = .aiming
    }

    private static func face(of normal: Vec2) -> String {
        if normal.y > 0.5 { return "floor" }
        if normal.y < -0.5 { return "ceiling" }
        return "wall"
    }

    private static func tint(forNormal normal: Vec2) -> Vec4 {
        if normal.y > 0.5 { return TokyoNight.green }
        if normal.y < -0.5 { return TokyoNight.red }
        return TokyoNight.yellow
    }

    // MARK: - Setup

    private func buildRoom() {
        addBox(center: Vec2(0, floorY - 1), size: Vec2(2 * sideX + 4, 2), tint: TokyoNight.dark)
        addBox(center: Vec2(0, ceilingY + 1), size: Vec2(2 * sideX + 4, 2), tint: TokyoNight.dark)
        addBox(center: Vec2(-sideX - 1, 0), size: Vec2(2, 2 * ceilingY), tint: TokyoNight.dark)
        addBox(center: Vec2(sideX + 1, 0), size: Vec2(2, 2 * ceilingY), tint: TokyoNight.dark)
        addBox(center: Vec2(-6, -11), size: Vec2(6, 6), tint: TokyoNight.darker)
        addBox(center: Vec2(10, -5), size: Vec2(5, 2), tint: TokyoNight.darker)
        addBox(center: Vec2(20, 4), size: Vec2(4, 8), tint: TokyoNight.darker)
    }

    private func addBox(center: Vec2, size: Vec2, tint: Vec4) {
        let box = GameObj()
        box.position = center
        box.scale = size
        box.add(AlphaBlendComponent(parent: box, textureID: renderer.defaultTextureId, tintColor: tint))
        room.append(box)
        boxes.append(Box(center: center, width: size.x, height: size.y))
    }

    private func buildShip() {
        ship = GameObj()
        shipHome = Vec2(-20, floorY + shipHalfSize.y)
        ship.position = shipHome
        ship.scale = shipHalfSize * 2
        ship.zOrder = 0.04
        ship.add(AlphaBlendComponent(parent: ship, textureID: GameTextures.blue))
    }

    private func buildPreview() {
        for _ in 0..<dotCount {
            let dot = GameObj()
            dot.scale = Vec2(0.35, 0.35)
            dot.zOrder = 0.05
            dot.add(AlphaBlendComponent(parent: dot, textureID: GameTextures.disc, tintColor: TokyoNight.fg))
            dots.append(dot)
        }
        marker = GameObj()
        marker.scale = Vec2(1.2, 1.2)
        marker.zOrder = 0.06
        marker.add(AlphaBlendComponent(parent: marker, textureID: GameTextures.disc, tintColor: TokyoNight.green))
    }

    // MARK: - UI

    private func showOverlay() {
        ui.overlay = AnyView(BallisticsPanel(controls: controls))
    }
}

/// What the ballistics panel shows and does.
@MainActor
@Observable
final class BallisticsControls {
    var onLaunch: () -> Void = {}
    var onReset: () -> Void = {}
    var onMode: () -> Void = {}
    var hitCursor = false
    var outOfRange = false
    var readout = ""
}

struct BallisticsPanel: View {
    let controls: BallisticsControls

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(controls.readout)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(TokyoNight.color(TokyoNight.comment))
                .multilineTextAlignment(.trailing)
                .padding(8)

            BottomBar {
                Button("Launch", action: controls.onLaunch)
                Button("Reset", action: controls.onReset)
                Button(controls.hitCursor ? "Mode: Hit cursor" : "Mode: Pull", action: controls.onMode)
            }
        }
    }
}
