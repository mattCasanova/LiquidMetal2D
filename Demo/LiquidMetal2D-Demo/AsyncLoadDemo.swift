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

import Foundation
import LiquidMetal2D
#if canImport(UIKit)
import UIKit
#endif

class AsyncLoadDemo: DefaultScene {
    override class var sceneType: any SceneType { SceneTypes.asyncLoadDemo }

    private let artificialDelay: Float = 5.0

    #if canImport(UIKit)
    private var statusLabel: UILabel!
    private var startButton: UIButton!
    #endif

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
        setupUI()

        scheduler.add(task: ScheduledTask(time: artificialDelay, action: { [weak self] _ in
            self?.loadAllTextures()
        }, count: 1))
    }

    override func layoutUI() {
        #if canImport(UIKit)
        let bounds = renderer.view.bounds
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        statusLabel.frame = CGRect(
            x: 0, y: centerY - 40,
            width: bounds.width, height: 40)
        startButton.frame = CGRect(
            x: centerX - 60, y: centerY + 20,
            width: 120, height: 50)
        #endif
    }

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
        tearDownUI()
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

    #if canImport(UIKit)
    private func setupUI() {
        statusLabel = UILabel()
        statusLabel.textColor = TokyoNight.uiFg
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .bold)
        statusLabel.text = "Loading..."
        renderer.view.addSubview(statusLabel)

        startButton = UIButton(type: .system)
        startButton.setTitle("Start", for: .normal)
        startButton.setTitleColor(TokyoNight.uiBg, for: .normal)
        startButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        startButton.backgroundColor = TokyoNight.uiBlue
        startButton.layer.cornerRadius = 10
        startButton.addTarget(self, action: #selector(onStart), for: .touchUpInside)
        startButton.isHidden = true
        renderer.view.addSubview(startButton)

        layoutUI()
    }

    private func tearDownUI() {
        statusLabel.removeFromSuperview()
        startButton.removeFromSuperview()
    }
    #else
    // Mac scaffolding until the SwiftUI rewrite reaches this scene's controls.
    private func setupUI() {}
    private func tearDownUI() {}
    #endif

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
        #if canImport(UIKit)
        statusLabel.text = "Ready!"
        startButton.isHidden = false
        #else
        // No Start button on the Mac until it is drawn in SwiftUI: go straight on.
        onStart()
        #endif
    }

    @objc func onStart() {
        sceneMgr.setScene(type: SceneTypes.massRenderDemo)
    }
}
