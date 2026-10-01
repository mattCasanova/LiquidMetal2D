//
//  ParticleDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 4/19/26.
//

import UIKit
import LiquidMetal2D

/// Showcases `ParticleShader` — a fourth engine shader doing additive-blended,
/// texture-sampled particles with order-independent compositing.
///
/// **What the user sees:** a campfire-like emitter shoots orange/red glowy
/// particles upward. Touch and drag anywhere on the Metal view to move the
/// emitter; particles already in flight continue on their existing path
/// (they don't follow the emitter after birth). Two buttons: `Burst` spawns
/// 60 particles at once, `Pause` toggles continuous emission.
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
    private var ui: DemoSceneUI!
    private var burstButton: UIButton!
    private var pauseButton: UIButton!
    private var colorButton: UIButton!

    // Sliders set the midpoint of the relevant range. Actual min/max is
    // ±`rangeSpread` around it, so randomness is preserved. Tweak the
    // spread fraction to make particles more/less uniform.
    private let rangeSpread: Float = 0.3
    private var emissionSlider: UISlider!
    private var speedSlider: UISlider!
    private var scaleSlider: UISlider!
    private var lifetimeSlider: UISlider!
    private var spreadSlider: UISlider!
    private var gravitySlider: UISlider!
    private var emissionLabel: UILabel!
    private var speedLabel: UILabel!
    private var scaleLabel: UILabel!
    private var lifetimeLabel: UILabel!
    private var spreadLabel: UILabel!
    private var gravityLabel: UILabel!

    // "Correlated color variation" switch at the top of the slider column.
    private var correlatedSwitch: UISwitch!
    private var correlatedLabel: UILabel!

    // Color palette with matched start-color + variation endpoints and
    // end-color + variation endpoints. Each particle picks a random t
    // between the start pair (and, correlated, the end pair), so overlap
    // brightens in a range of warm hues instead of a single color.
    private let fireStartColor = Vec4(1.0, 0.55, 0.15, 0.7)
    private let fireStartVar   = Vec4(1.0, 0.85, 0.20, 0.7)  // warm yellow
    private let fireEndColor   = Vec4(0.9, 0.10, 0.00, 0.0)
    private let fireEndVar     = Vec4(0.5, 0.00, 0.00, 0.0)  // deep red

    private let neonStartColor = Vec4(1.0, 0.30, 0.75, 0.7)  // pink
    private let neonStartVar   = Vec4(0.75, 0.30, 1.0, 0.7)  // purple
    private let neonEndColor   = Vec4(0.5, 0.00, 0.55, 0.0)
    private let neonEndVar     = Vec4(0.3, 0.00, 0.70, 0.0)

    private var isNeon: Bool = false

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
        setupUI()
    }

    override func resume() { ui.view.isHidden = false }

    override func layoutUI() {
        ui.layout()
        layoutButtons()
    }

    override func update(dt: Float) {
        // Drag to reposition the emitter. Taps on the UIButton overlays are
        // handled by UIKit and never reach the input reader, so the buttons
        // don't accidentally teleport the emitter.
        if let touch = input.getWorldTouch(forZ: 0) {
            emitterObj.position.set(touch.x, touch.y)
        }
        emitterObj.get(ParticleEmitterComponent.self)?.update(dt: dt)
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
        ui.removeFromSuperview()
        burstButton.removeFromSuperview()
        pauseButton.removeFromSuperview()
        colorButton.removeFromSuperview()
        correlatedSwitch?.removeFromSuperview()
        correlatedLabel?.removeFromSuperview()
        [emissionSlider, speedSlider, scaleSlider,
         lifetimeSlider, spreadSlider, gravitySlider,
         emissionLabel, speedLabel, scaleLabel,
         lifetimeLabel, spreadLabel, gravityLabel].forEach { $0?.removeFromSuperview() }
    }

    // MARK: - Emitter

    private func createEmitter() {
        let obj = GameObj()
        obj.position.set(0, -6)  // slightly below center so upward particles fill the screen

        obj.add(ParticleEmitterComponent(
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
            startColor: fireStartColor,
            startColorVariation: fireStartVar,
            endColor: fireEndColor,
            endColorVariation: fireEndVar,
            correlatedColorVariation: true,
            gravity: Vec2(0, 1)   // slight buoyancy — particles accelerate upward
        ))

        objects.append(obj)
        emitterObj = obj
    }

    // MARK: - Actions

    @objc private func onBurst() {
        emitterObj.get(ParticleEmitterComponent.self)?.spawn(count: 60)
    }

    @objc private func onPause() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        emitter.isEmitting.toggle()
        pauseButton.setTitle(emitter.isEmitting ? "Pause" : "Resume", for: .normal)
    }

    // MARK: - Slider handlers

    @objc private func onEmissionChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let value = emissionSlider.value
        emitter.emissionRate = value
        emissionLabel.text = String(format: "Emission: %.0f/s", value)
    }

    @objc private func onSpeedChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let center = speedSlider.value
        emitter.speedRange = (center * (1 - rangeSpread))...(center * (1 + rangeSpread))
        speedLabel.text = String(format: "Speed: %.1f", center)
    }

    @objc private func onScaleChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let center = scaleSlider.value
        emitter.scaleRange = (center * (1 - rangeSpread))...(center * (1 + rangeSpread))
        scaleLabel.text = String(format: "Scale: %.1f", center)
    }

    @objc private func onLifetimeChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let center = lifetimeSlider.value
        emitter.lifetimeRange = (center * (1 - rangeSpread))...(center * (1 + rangeSpread))
        lifetimeLabel.text = String(format: "Lifetime: %.2fs", center)
    }

    @objc private func onSpreadChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let halfSpread = spreadSlider.value
        // Emit direction stays pointed up (pi/2); spread widens the cone.
        emitter.angleRange = (.pi / 2 - halfSpread)...(.pi / 2 + halfSpread)
        spreadLabel.text = String(format: "Spread: %.2f rad", halfSpread)
    }

    @objc private func onGravityChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let g = gravitySlider.value
        emitter.gravity = Vec2(0, g)
        gravityLabel.text = String(format: "Gravity Y: %+.1f", g)
    }

    @objc private func onColorToggle() {
        isNeon.toggle()
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        if isNeon {
            emitter.startColor = neonStartColor
            emitter.startColorVariation = neonStartVar
            emitter.endColor = neonEndColor
            emitter.endColorVariation = neonEndVar
        } else {
            emitter.startColor = fireStartColor
            emitter.startColorVariation = fireStartVar
            emitter.endColor = fireEndColor
            emitter.endColorVariation = fireEndVar
        }
        colorButton.setTitle(isNeon ? "Fire" : "Neon", for: .normal)
    }

    @objc private func onCorrelatedChanged() {
        emitterObj.get(ParticleEmitterComponent.self)?.correlatedColorVariation
            = correlatedSwitch.isOn
    }

    @objc func onMenu() {
        ui.view.isHidden = true
        sceneMgr.pushScene(type: SceneTypes.pauseDemo)
    }

    // MARK: - UI

    private func setupUI() {
        ui = DemoSceneUI(
            parentView: renderer.view, target: self,
            menuAction: #selector(onMenu))

        burstButton = makeButton(title: "Burst", action: #selector(onBurst))
        pauseButton = makeButton(title: "Pause", action: #selector(onPause))
        colorButton = makeButton(title: "Neon", action: #selector(onColorToggle))
        renderer.view.addSubview(burstButton)
        renderer.view.addSubview(pauseButton)
        renderer.view.addSubview(colorButton)

        // Slider defaults match the initial emitter config.
        emissionLabel = makeSliderLabel()
        speedLabel = makeSliderLabel()
        scaleLabel = makeSliderLabel()
        lifetimeLabel = makeSliderLabel()
        spreadLabel = makeSliderLabel()
        gravityLabel = makeSliderLabel()

        emissionSlider = makeSlider(min: 10,   max: 400,  value: 140,
                                    action: #selector(onEmissionChanged))
        speedSlider    = makeSlider(min: 2,    max: 24,   value: 10,
                                    action: #selector(onSpeedChanged))
        scaleSlider    = makeSlider(min: 1,    max: 12,   value: 6,
                                    action: #selector(onScaleChanged))
        lifetimeSlider = makeSlider(min: 0.2,  max: 3.0,  value: 1.2,
                                    action: #selector(onLifetimeChanged))
        spreadSlider   = makeSlider(min: 0.01, max: .pi,  value: 0.25,
                                    action: #selector(onSpreadChanged))
        gravitySlider  = makeSlider(min: -20,  max: 20,   value: 1,
                                    action: #selector(onGravityChanged))

        [emissionLabel, speedLabel, scaleLabel,
         lifetimeLabel, spreadLabel, gravityLabel,
         emissionSlider, speedSlider, scaleSlider,
         lifetimeSlider, spreadSlider, gravitySlider].forEach { renderer.view.addSubview($0) }

        // "Correlated" toggle at the top of the slider column.
        correlatedLabel = makeSliderLabel()
        correlatedLabel.text = "Correlated"
        correlatedSwitch = UISwitch(frame: .zero)
        correlatedSwitch.isOn = true
        correlatedSwitch.onTintColor = TokyoNight.uiBlue
        correlatedSwitch.addTarget(
            self, action: #selector(onCorrelatedChanged), for: .valueChanged)
        renderer.view.addSubview(correlatedLabel)
        renderer.view.addSubview(correlatedSwitch)

        // Prime the labels with initial values.
        onEmissionChanged()
        onSpeedChanged()
        onScaleChanged()
        onLifetimeChanged()
        onSpreadChanged()
        onGravityChanged()

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

    private func makeSlider(min: Float, max: Float, value: Float, action: Selector) -> UISlider {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        slider.minimumTrackTintColor = TokyoNight.uiBlue
        slider.addTarget(self, action: action, for: .valueChanged)
        return slider
    }

    private func makeSliderLabel() -> UILabel {
        let label = UILabel(frame: .zero)
        label.textColor = TokyoNight.uiFg
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        return label
    }

    private func layoutButtons() {
        let safeTop = renderer.view.safeAreaInsets.top
        let safeBottom = renderer.view.safeAreaInsets.bottom
        let safeRight = renderer.view.safeAreaInsets.right
        let viewWidth = renderer.view.bounds.width
        let viewHeight = renderer.view.bounds.height

        // Bottom-center button row (3 buttons).
        let buttonWidth: CGFloat = 110
        let buttonHeight: CGFloat = 44
        let gap: CGFloat = 10
        let bottomY = viewHeight - safeBottom - buttonHeight - 16
        let totalWidth = buttonWidth * 3 + gap * 2
        let leftX = (viewWidth - totalWidth) / 2

        burstButton.frame = CGRect(
            x: leftX, y: bottomY, width: buttonWidth, height: buttonHeight)
        pauseButton.frame = CGRect(
            x: leftX + (buttonWidth + gap), y: bottomY,
            width: buttonWidth, height: buttonHeight)
        colorButton.frame = CGRect(
            x: leftX + (buttonWidth + gap) * 2, y: bottomY,
            width: buttonWidth, height: buttonHeight)

        // Right-side slider stack (6 rows, compact to fit landscape).
        let sliderColumnWidth: CGFloat = 200
        let rowHeight: CGFloat = 26
        let labelHeight: CGFloat = 16
        let rowSpacing: CGFloat = 6
        let rightEdge = viewWidth - safeRight - 12
        let columnX = rightEdge - sliderColumnWidth
        var cursorY = safeTop + 12

        // "Correlated" switch row — label on the left, UISwitch on the right.
        let switchRowHeight: CGFloat = 32
        if correlatedSwitch != nil, correlatedLabel != nil {
            correlatedLabel.frame = CGRect(x: columnX, y: cursorY,
                                           width: sliderColumnWidth - 60,
                                           height: switchRowHeight)
            correlatedSwitch.sizeToFit()
            let switchSize = correlatedSwitch.frame.size
            correlatedSwitch.frame = CGRect(
                x: columnX + sliderColumnWidth - switchSize.width,
                y: cursorY + (switchRowHeight - switchSize.height) / 2,
                width: switchSize.width, height: switchSize.height)
            cursorY += switchRowHeight + rowSpacing
        }

        let rows: [(UILabel, UISlider)] = [
            (emissionLabel, emissionSlider),
            (speedLabel,    speedSlider),
            (scaleLabel,    scaleSlider),
            (lifetimeLabel, lifetimeSlider),
            (spreadLabel,   spreadSlider),
            (gravityLabel,  gravitySlider)
        ]
        for (label, slider) in rows {
            label.frame = CGRect(x: columnX, y: cursorY,
                                 width: sliderColumnWidth, height: labelHeight)
            slider.frame = CGRect(x: columnX, y: cursorY + labelHeight,
                                  width: sliderColumnWidth, height: rowHeight)
            cursorY += labelHeight + rowHeight + rowSpacing
        }
    }
}
