//
//  AsyncLoadDemo.swift
//  LiquidMetal2D-Demo
//
//  Loading screen with a starfield flythrough effect. Stars are
//  procedural 1x1 white textures tinted with Tokyo Night colors —
//  no file loading required. After a brief delay, game textures
//  load asynchronously. On completion, "Ready!" and a Start button
//  appear over the starfield.
//
//  Copyright © 2026 Matt Casanova. All rights reserved.
//

import SwiftUI
import LiquidMetal2D

class AsyncLoadDemo: DefaultScene {
    override class var sceneType: any SceneType { SceneTypes.asyncLoadDemo }

    private let artificialDelay: Float = 5.0

    private var isLoaded = false
    private var hasWaited = false
    private let controls = AsyncLoadControls()
    private var ui: DemoUI!

    // Star movement
    private let baseSpeed: Float = 0.35
    private let distanceSpeedScale: Float = 0.25
    private let globalSpeedMultiplier: Float = 4.5
    private let baseScale: Float = 0.04
    private let distanceScaleMultiplier: Float = 0.03
    private let maxDistance: Float = 60
    private let speedRange: ClosedRange<Float> = 0.2...1.8
    private let respawnDistanceRange: ClosedRange<Float> = 0.5...2
    private let initialJitter: ClosedRange<Float> = -2...2

    override func initialize(services: SceneServices) {
        super.initialize(services: services)

        renderer.setClearColor(color: TokyoNight.clearColor)

        createStars()

        ui = services.demoUI
        // No way out until the textures are requested: a scene picked from the
        // menu before that would draw every ship as the error texture for good.
        ui.isMenuHidden = true
        controls.onStart = { [unowned self] in onStart() }
        showOverlay()

        loadAllTextures()
        scheduler.add(task: ScheduledTask(time: artificialDelay, action: { [weak self] _ in
            self?.hasWaited = true
            self?.showReadyIfDone()
        }, count: 1))
    }

    override func resume() { showOverlay() }

    override func update(dt: Float) {
        scheduler.update(dt: dt)

        for star in objects {
            let dir = star.position.normalized
            let dist = star.position.length
            let starSpeed = star.zOrder

            let speed = (baseSpeed + dist * distanceSpeedScale) * starSpeed
            star.position += dir * speed * dt * globalSpeedMultiplier
            star.rotation += dt * 50 * starSpeed

            let scaleFactor = (baseScale + dist * distanceScaleMultiplier) * starSpeed
            star.scale.set(scaleFactor, scaleFactor)

            if dist > maxDistance {
                respawnStar(star)
            }
        }
    }

    override func shutdown() {
        super.shutdown()
        ui.overlay = nil
        ui.isMenuHidden = false
    }

    // MARK: - Stars

    private func createStars() {
        let starCount = 2000
        for i in 0..<starCount {
            let star = GameObj()
            star.zOrder = Float.random(in: speedRange)

            let angle = Float.random(in: 0...GameMath.twoPi)
            let dist = Float(i) / Float(starCount) * maxDistance + Float.random(in: initialJitter)
            let clampedDist = max(dist, respawnDistanceRange.lowerBound)
            star.position.set(cos(angle) * clampedDist, sin(angle) * clampedDist)

            let scaleFactor = (baseScale + abs(dist) * distanceScaleMultiplier) * star.zOrder
            star.scale.set(scaleFactor, scaleFactor)
            star.add(AlphaBlendComponent(
                parent: star,
                textureID: renderer.defaultTextureId,
                tintColor: TokyoNight.accents.randomElement()!))
            objects.append(star)
        }
    }

    private func respawnStar(_ star: GameObj) {
        let angle = Float.random(in: 0...GameMath.twoPi)
        let dist = Float.random(in: respawnDistanceRange)
        star.position.set(cos(angle) * dist, sin(angle) * dist)
        star.zOrder = Float.random(in: speedRange)
        star.scale.set(baseScale, baseScale)
        star.get(AlphaBlendComponent.self)?.tintColor = TokyoNight.accents.randomElement()!
    }

    // MARK: - UI

    private func showOverlay() {
        ui.overlay = AnyView(AsyncLoadPanel(controls: controls))
    }

    // MARK: - Loading

    private func loadAllTextures() {
        let ids = renderer.loadTextures([
            TextureDescriptor(name: "playerShip1_blue", isMipmapped: true),
            TextureDescriptor(name: "playerShip1_green", isMipmapped: true),
            TextureDescriptor(name: "playerShip1_orange", isMipmapped: true),
            TextureDescriptor(name: "disc", isMipmapped: true)
        ], completion: { [weak self] in
            self?.onLoadComplete()
        })

        GameTextures.blue = ids[0]
        GameTextures.green = ids[1]
        GameTextures.orange = ids[2]
        GameTextures.disc = ids[3]
    }

    private func onLoadComplete() {
        isLoaded = true
        showReadyIfDone()
    }

    /// Ready once the textures are in and the starfield has had its moment.
    private func showReadyIfDone() {
        guard isLoaded, hasWaited else { return }
        controls.status = "Ready!"
        controls.isReady = true
    }

    func onStart() {
        sceneMgr.setScene(type: SceneTypes.massRenderDemo)
    }
}

/// What the loading panel shows and does.
@MainActor
@Observable
final class AsyncLoadControls {
    var status = "Loading..."
    var isReady = false
    var onStart: () -> Void = {}
}

/// The status line and, once the textures are in, the Start button, centred over the stars.
struct AsyncLoadPanel: View {
    let controls: AsyncLoadControls

    var body: some View {
        VStack(spacing: 20) {
            ReadoutText(controls.status, size: 24)
            if controls.isReady {
                Button("Start", action: controls.onStart)
                    .buttonStyle(.demo)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
