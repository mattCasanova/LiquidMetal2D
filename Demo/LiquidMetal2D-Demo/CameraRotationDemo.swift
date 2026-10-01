//
//  CameraRotationDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/17/26.
//

import UIKit
import LiquidMetal2D

/// Camera rotation & scheduler demo. Ships form a tunnel that oscillates
/// smoothly via a per-frame sine wave. Press the Spawn button to schedule
/// three chained waves of ships that fly across the screen.
///
/// **Engine features demonstrated:**
/// - `renderer.setCameraRotation(angle:)` — rotates the entire view
/// - `Scheduler` — timed repeat events and task chaining (3 waves)
/// - `GameObj.isActive` — deactivating objects that leave world bounds
class CameraRotationDemo: Scene {
    static var sceneType: any SceneType { SceneTypes.cameraRotationDemo }

    private var sceneMgr: SceneManager!
    private var renderer: Renderer!
    private var input: InputReader!

    private var objects = [GameObj]()

    // Oscillation
    private var elapsedTime: Float = 0
    private let oscillationSpeed: Float = 1.5
    private let maxSwing: Float = GameMath.degreeToRadian(30)

    // Scheduler for spawn waves
    private let scheduler = Scheduler()

    // Tunnel layout (pushed back behind the spawn layer)
    private let shipsPerRow = 20
    private let trackSpacing: Float = 8
    private let zSpacing: Float = 4
    private let startZ: Float = -40

    // Spawn config
    private let spawnSpeed: Float = 30
    private let spawnZ: Float = 0

    private var rotationLabel: UILabel!
    private var ui: DemoSceneUI!
    private var spawnButton: UIButton!

    func initialize(services: SceneServices) {
        self.sceneMgr = services.sceneMgr
        self.renderer = services.renderer
        self.input = services.input

        renderer.setCamera(point: Vec3(0, 0, 60))
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        createTunnelObjects()
        setupUI()
    }

    func resume() { ui.view.isHidden = false }

    func resize() {
        ui.layout()
        renderer.setDefaultPerspective()
        layoutUI()
    }

    func update(dt: Float) {
        scheduler.update(dt: dt)
        updateSpawnedShips(dt: dt)

        let rotation = computeOscillation(dt: dt)
        renderer.setCameraRotation(angle: rotation)
        updateLabel(rotation)
    }

    func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        renderer.submit(objects: objects)
        renderer.endPass()
    }

    func shutdown() {
        objects.removeAll()
        scheduler.clear()
        renderer.setCameraRotation(angle: 0)
        rotationLabel.removeFromSuperview()
        spawnButton.removeFromSuperview()
        ui.removeFromSuperview()
    }

    // MARK: - Oscillation

    /// Advances the sine-wave oscillation and returns the current angle.
    private func computeOscillation(dt: Float) -> Float {
        elapsedTime += dt
        return sin(elapsedTime * oscillationSpeed) * maxSwing
    }

    // MARK: - Spawning

    /// Moves ships that have velocity and deactivates any that exit
    /// the far side of the world bounds. Tunnel ships (zero velocity) are skipped.
    /// Only checks the edge the ship is moving toward so off-screen spawns
    /// aren't immediately deactivated.
    private func updateSpawnedShips(dt: Float) {
        let bounds = renderer.getVisibleBounds(zOrder: spawnZ)

        for ship in objects where ship.isActive && ship.velocity != Vec2() {
            ship.position += ship.velocity * dt

            let exited = (ship.velocity.x > 0 && ship.position.x > bounds.maxX)
                || (ship.velocity.x < 0 && ship.position.x < bounds.minX)
                || (ship.velocity.y > 0 && ship.position.y > bounds.maxY)
                || (ship.velocity.y < 0 && ship.position.y < bounds.minY)

            if exited {
                ship.isActive = false
            }
        }
    }

    /// Schedules three chained waves of ships:
    /// - Wave 1 (blue): left-to-right
    /// - Wave 2 (red): top-to-bottom, 2x scale
    /// - Wave 3 (green): left-to-right
    private func scheduleSpawnWaves() {
        let bounds = renderer.getVisibleBounds(zOrder: spawnZ)
        let speed = spawnSpeed
        let down = GameMath.degreeToRadian(270)

        // Wave 1 (blue): left-to-right, centered vertically
        let wave1 = ScheduledTask(time: 0.5, action: { [weak self] _ in
            guard let self else { return }
            self.spawnShip(
                position: Vec2(bounds.minX - 2, 0),
                velocity: Vec2(speed, 0),
                rotation: 0,
                scale: 4,
                textureIndex: 0)
        }, count: 4)

        // Wave 2 (red): top-to-bottom, centered horizontally
        let wave2 = wave1.then(time: 0.5, action: { [weak self] _ in
            guard let self else { return }
            self.spawnShip(
                position: Vec2(0, bounds.maxY + 2),
                velocity: Vec2(0, -speed),
                rotation: down,
                scale: 4,
                textureIndex: 2)
        }, count: 4)

        // Wave 3 (green): right-to-left, centered vertically
        let left = GameMath.degreeToRadian(180)
        wave2.then(time: 0.5, action: { [weak self] _ in
            guard let self else { return }
            self.spawnShip(
                position: Vec2(bounds.maxX + 2, 0),
                velocity: Vec2(-speed, 0),
                rotation: left,
                scale: 4,
                textureIndex: 1)
        }, count: 4)

        scheduler.add(task: wave1)
    }

    /// Creates a single ship and adds it to the objects array.
    private func spawnShip(
        position: Vec2, velocity: Vec2, rotation: Float,
        scale: Float, textureIndex: Int
    ) {
        let ship = GameObj()
        ship.position = position
        ship.velocity = velocity
        ship.rotation = rotation
        ship.scale.set(scale, scale)
        ship.zOrder = spawnZ
        ship.add(AlphaBlendComponent(
            parent: ship,
            textureID: GameTextures.all[textureIndex],
            tintColor: TokyoNight.shipTints[textureIndex]))
        objects.append(ship)
    }

    // MARK: - UI

    private func setupUI() {
        ui = DemoSceneUI(
            parentView: renderer.view, target: self,
            menuAction: #selector(onMenu))

        rotationLabel = UILabel()
        rotationLabel.textColor = TokyoNight.uiFg
        rotationLabel.textAlignment = .center
        rotationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        renderer.view.addSubview(rotationLabel)

        spawnButton = createButton(title: "Schedule Wave", action: #selector(onSpawn))
        renderer.view.addSubview(spawnButton)

        updateLabel(0)
        layoutUI()
    }

    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(frame: .zero)
        button.backgroundColor = TokyoNight.uiDarker
        button.setTitle(title, for: .normal)
        button.setTitleColor(TokyoNight.uiBlue, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 6
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func layoutUI() {
        let safeTop = renderer.view.safeAreaInsets.top
        let safeBottom = renderer.view.safeAreaInsets.bottom
        let viewWidth = renderer.view.bounds.width
        let viewHeight = renderer.view.bounds.height

        rotationLabel.frame = CGRect(
            x: 0, y: safeTop + 8,
            width: viewWidth, height: 30)

        let buttonWidth: CGFloat = 140
        let buttonHeight: CGFloat = 44
        let bottomY = viewHeight - safeBottom - buttonHeight - 16

        spawnButton.frame = CGRect(
            x: (viewWidth - buttonWidth) / 2,
            y: bottomY, width: buttonWidth, height: buttonHeight)
    }

    private func updateLabel(_ rotation: Float) {
        let degrees = GameMath.radianToDegree(rotation)
        rotationLabel.text = String(format: "Camera Rotation: %.1f°", degrees)
    }

    @objc private func onSpawn() {
        scheduleSpawnWaves()
    }

    // MARK: - Tunnel

    /// Creates four rows of ships forming a rectangular tunnel into the distance.
    private func createTunnelObjects() {
        objects.removeAll()

        let positions: [(Float, Float, Int)] = [
            (-trackSpacing, 0, 0),
            (trackSpacing, 0, 1),
            (0, trackSpacing, 2),
            (0, -trackSpacing, 0)
        ]

        for (xPos, yPos, textureIndex) in positions {
            for i in 0..<shipsPerRow {
                let obj = GameObj()
                obj.position.set(xPos, yPos)
                obj.zOrder = startZ + Float(i) * zSpacing
                obj.scale.set(2, 2)
                obj.rotation = 0
                obj.add(AlphaBlendComponent(
                    parent: obj,
                    textureID: GameTextures.all[textureIndex],
                    tintColor: TokyoNight.shipTints[textureIndex]))
                objects.append(obj)
            }
        }
    }

    @objc func onMenu() {
        ui.view.isHidden = true
        sceneMgr.pushScene(type: SceneTypes.pauseDemo)
    }

    static func build() -> Scene { return CameraRotationDemo() }
}
