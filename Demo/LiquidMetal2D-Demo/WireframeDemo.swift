//
//  MultiShaderDemo.swift (file: WireframeDemo.swift)
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 4/19/26.
//

import Foundation
import LiquidMetal2D
#if canImport(UIKit)
import UIKit
#endif

/// Shows three shaders cooperating in one scene: `AlphaBlendShader` for the
/// sprite, `WireframeShader` for the collider outline overlay, and
/// `RippleShader` as a swappable distortion for the sprite pass.
///
/// **What the user sees:** the Spawn button launches pairs of ships. The
/// left ship uses an `AABBCollider` (square outline); the right uses a
/// `CircleCollider` (circle outline). Outlines are red while clear and
/// green while overlapping. Wireframe and Ripple toggle buttons flip the
/// two overlays independently.
///
/// **Engine features demonstrated:**
/// - Three `Shader` classes coexisting in one `beginPass`/`endPass` cycle.
/// - Each shader filters the same `[GameObj]` by its own component
///   (`AlphaBlendComponent` / `WireframeComponent` / `RippleComponent`).
///   One object list, multiple render paths.
/// - Shader-swap toggle: the sprite pass renders via AlphaBlend or Ripple,
///   decided at `draw` time by which shader we bind.
/// - `register`/`unregister` for custom shaders so the renderer runs their
///   per-frame `beginFrame` + completion lifecycle alongside the built-in
///   alpha-blend shader.
class MultiShaderDemo: DefaultScene {
    override class var sceneType: any SceneType { SceneTypes.multiShaderDemo }

    private let distance: Float = 40
    private let speed: Float = 10
    private let size: Float = 4
    private let colorIdle = Vec4(1, 0.2, 0.2, 1)       // red
    private let colorHit = Vec4(0.4, 1, 0.4, 1)        // green
    private let wireThickness: Float = 0.04

    private var wireframe: WireframeShader!
    private var ripple: RippleShader!
    private var grid: SpatialGrid!
    private var ui: DemoSceneUI!
    #if canImport(UIKit)
    private var spawnButton: UIButton!
    private var wireToggle: UIButton!
    private var rippleToggle: UIButton!
    #endif
    private var showWireframes: Bool = true
    private var rippleOn: Bool = false

    override func initialize(services: SceneServices) {
        super.initialize(services: services)

        renderer.setCamera(point: Vec3(0, 0, distance))
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        guard let defaultRenderer = renderer as? DefaultRenderer else {
            fatalError("MultiShaderDemo requires DefaultRenderer")
        }
        wireframe = WireframeShader(
            renderCore: defaultRenderer.renderCore, maxObjects: 64)
        ripple = RippleShader(
            renderCore: defaultRenderer.renderCore, maxObjects: 64)
        renderer.register(shader: wireframe)
        renderer.register(shader: ripple)

        let bounds = renderer.getVisibleBounds(zOrder: 0)
        grid = SpatialGrid(bounds: bounds, cellWidth: 4, cellHeight: 4)

        setupUI()
        spawnPair()
    }

    override func resume() { ui.view.isHidden = false }

    override func layoutUI() {
        ui.layout()
        layoutButtons()
    }

    override func update(dt: Float) {
        let bounds = renderer.getVisibleBounds(zOrder: 0)

        for obj in objects {
            obj.position += obj.velocity * dt
            obj.get(RippleComponent.self)?.time += dt
        }

        // Remove any ship that has fully crossed to the far side. `@Sendable`
        // keeps the closure off the main actor; a `@MainActor` closure would
        // make `removeAll` check the actor on every call.
        let minX = bounds.minX - size
        let maxX = bounds.maxX + size
        objects.removeAll { @Sendable obj in
            obj.position.x < minX || obj.position.x > maxX
        }

        // Reset all wireframes to idle (red), then mark colliding pairs (green).
        // Uses the engine's SpatialGrid broadphase for consistency with the
        // other collision demos — even at this object count the naive loop
        // would be fine, but reusing the engine primitive keeps the demos
        // teaching the same pattern.
        for obj in objects {
            obj.get(WireframeComponent.self)?.color = colorIdle
        }
        grid.clear()
        grid.insert(contentsOf: objects)
        grid.forEachPotentialPair { [self] a, b in
            guard let colliderA = anyCollider(a),
                  let colliderB = anyCollider(b) else { return }
            if colliderA.doesCollideWith(collider: colliderB) {
                a.get(WireframeComponent.self)?.color = colorHit
                b.get(WireframeComponent.self)?.color = colorHit
            }
        }
    }

    override func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()

        // Pass 1: sprite pass — flip between AlphaBlend and Ripple shaders.
        if rippleOn {
            renderer.useShader(ripple)
        }
        renderer.submit(objects: objects)

        // Pass 2: wireframe overlay, optional.
        if showWireframes {
            renderer.useShader(wireframe)
            renderer.submit(objects: objects)
        }

        renderer.endPass()
    }

    override func shutdown() {
        super.shutdown()
        renderer.unregister(shader: wireframe)
        renderer.unregister(shader: ripple)
        ui.removeFromSuperview()
        tearDownUI()
    }

    // MARK: - Spawn + toggles

    #if canImport(UIKit)
    @objc private func onSpawn() {
        spawnPair()
    }

    @objc private func onToggleWireframe() {
        showWireframes.toggle()
        wireToggle.setTitle(showWireframes ? "Wire: On" : "Wire: Off", for: .normal)
    }

    @objc private func onToggleRipple() {
        rippleOn.toggle()
        rippleToggle.setTitle(rippleOn ? "Ripple: On" : "Ripple: Off", for: .normal)
    }
    #endif

    private func spawnPair() {
        let bounds = renderer.getVisibleBounds(zOrder: 0)
        let y = Float.random(in: bounds.minY * 0.5...bounds.maxY * 0.5)

        // Left ship: AABB collider, blue sprite.
        let left = GameObj()
        left.position.set(bounds.minX - size * 0.5, y)
        left.velocity.set(speed, 0)
        left.scale.set(size, size)
        attachSpriteComponents(to: left, textureID: GameTextures.blue, tintIndex: 0)
        left.add(AABBCollider(parent: left, width: size, height: size))
        left.add(WireframeComponent(
            parent: left, color: colorIdle, thickness: wireThickness))
        objects.append(left)

        // Right ship: Circle collider, orange sprite. Rotated 180° so the
        // sprite faces its direction of travel.
        let right = GameObj()
        right.position.set(bounds.maxX + size * 0.5, y)
        right.velocity.set(-speed, 0)
        right.scale.set(size, size)
        right.rotation = .pi
        attachSpriteComponents(to: right, textureID: GameTextures.orange, tintIndex: 2)
        right.add(CircleCollider(parent: right, radius: size * 0.5))
        right.add(WireframeComponent(
            parent: right, color: colorIdle, thickness: wireThickness))
        objects.append(right)
    }

    /// Attach both sprite components so the Ripple toggle can swap shaders
    /// without mutating the object list.
    private func attachSpriteComponents(to obj: GameObj, textureID: Int, tintIndex: Int) {
        let tint = TokyoNight.shipTints[tintIndex]
        obj.add(AlphaBlendComponent(
            parent: obj, textureID: textureID, tintColor: tint))
        obj.add(RippleComponent(
            parent: obj, textureID: textureID, tintColor: tint,
            amplitude: 0.05, frequency: 14, speed: 4))
    }

    /// Collider types share a slot, so `obj.get(Collider.self)` isn't available
    /// via the generic API. Try each concrete type.
    private func anyCollider(_ obj: GameObj) -> Collider? {
        return obj.get(CircleCollider.self) ?? obj.get(AABBCollider.self)
    }

    @objc func onMenu() {
        ui.view.isHidden = true
        sceneMgr.pushScene(type: SceneTypes.pauseDemo)
    }

    // MARK: - UI

    #if canImport(UIKit)
    private func setupUI() {
        ui = DemoSceneUI(
            parentView: renderer.view, target: self,
            menuAction: #selector(onMenu))

        spawnButton = makeButton(title: "Spawn", action: #selector(onSpawn))
        wireToggle = makeButton(title: "Wire: On", action: #selector(onToggleWireframe))
        rippleToggle = makeButton(title: "Ripple: Off", action: #selector(onToggleRipple))
        renderer.view.addSubview(spawnButton)
        renderer.view.addSubview(wireToggle)
        renderer.view.addSubview(rippleToggle)

        layoutButtons()
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(frame: .zero)
        button.backgroundColor = TokyoNight.uiDarker
        button.setTitle(title, for: .normal)
        button.setTitleColor(TokyoNight.uiBlue, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        button.layer.cornerRadius = 6
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func layoutButtons() {
        let safeBottom = renderer.view.safeAreaInsets.bottom
        let viewWidth = renderer.view.bounds.width
        let viewHeight = renderer.view.bounds.height

        let buttonWidth: CGFloat = 110
        let buttonHeight: CGFloat = 44
        let gap: CGFloat = 10
        let bottomY = viewHeight - safeBottom - buttonHeight - 16
        let totalWidth = buttonWidth * 3 + gap * 2
        let leftX = (viewWidth - totalWidth) / 2

        spawnButton.frame = CGRect(
            x: leftX, y: bottomY, width: buttonWidth, height: buttonHeight)
        wireToggle.frame = CGRect(
            x: leftX + (buttonWidth + gap), y: bottomY,
            width: buttonWidth, height: buttonHeight)
        rippleToggle.frame = CGRect(
            x: leftX + (buttonWidth + gap) * 2, y: bottomY,
            width: buttonWidth, height: buttonHeight)
    }

    private func tearDownUI() {
        spawnButton.removeFromSuperview()
        wireToggle.removeFromSuperview()
        rippleToggle.removeFromSuperview()
    }
    #else
    // Mac scaffolding until the SwiftUI rewrite reaches this scene's controls.
    private func setupUI() {
        ui = DemoSceneUI(parentView: renderer.view, target: self, menuAction: #selector(onMenu))
    }
    private func layoutButtons() {}
    private func tearDownUI() {}
    #endif
}
