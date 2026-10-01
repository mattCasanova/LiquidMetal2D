//
//  SmokeDemo.swift (file: RocketTrailDemo.swift — rename in Xcode if desired)
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 4/19/26.
//

import UIKit
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
    private var ui: DemoSceneUI!
    private var burstButton: UIButton!
    private var colorButton: UIButton!

    // Slider-driven center values. Actual ranges are ±`rangeSpread` around
    // each midpoint so randomness is preserved.
    private let rangeSpread: Float = 0.3
    private var emissionSlider: UISlider!
    private var speedSlider: UISlider!
    private var startScaleSlider: UISlider!
    private var endScaleSlider: UISlider!
    private var lifetimeSlider: UISlider!
    private var spreadSlider: UISlider!
    private var gravitySlider: UISlider!
    private var emissionLabel: UILabel!
    private var speedLabel: UILabel!
    private var startScaleLabel: UILabel!
    private var endScaleLabel: UILabel!
    private var lifetimeLabel: UILabel!
    private var spreadLabel: UILabel!
    private var gravityLabel: UILabel!

    // Color palettes. Each has a primary + variation endpoint so particles
    // roll a random hue along the line between them. Alphas kept < 0.5 so
    // smoke stays readable rather than opaque; end alpha is 0 for smooth
    // pop-out.
    private let grayStart    = Vec4(0.70, 0.70, 0.75, 0.40)
    private let grayStartVar = Vec4(0.85, 0.70, 0.90, 0.40)  // lavender-gray
    private let grayEnd      = Vec4(0.25, 0.25, 0.30, 0.00)
    private let grayEndVar   = Vec4(0.30, 0.20, 0.35, 0.00)

    private let neonStart    = Vec4(0.30, 0.65, 1.00, 0.40)  // blue
    private let neonStartVar = Vec4(0.50, 0.40, 1.00, 0.40)  // blue-violet
    private let neonEnd      = Vec4(0.05, 0.15, 0.55, 0.00)
    private let neonEndVar   = Vec4(0.15, 0.05, 0.50, 0.00)

    private var isNeon: Bool = false

    // "Correlated" switch + label.
    private var correlatedSwitch: UISwitch!
    private var correlatedLabel: UILabel!

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
        setupUI()
    }

    override func resume() { ui.view.isHidden = false }

    override func layoutUI() {
        ui.layout()
        layoutControls()
    }

    override func update(dt: Float) {
        if let touch = input.getWorldTouch(forZ: 0) {
            emitterObj.position.set(touch.x, touch.y)
        }
        emitterObj.get(ParticleEmitterComponent.self)?.update(dt: dt)
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
        ui.removeFromSuperview()
        burstButton.removeFromSuperview()
        colorButton.removeFromSuperview()
        correlatedSwitch?.removeFromSuperview()
        correlatedLabel?.removeFromSuperview()
        [emissionSlider, speedSlider, startScaleSlider, endScaleSlider,
         lifetimeSlider, spreadSlider, gravitySlider,
         emissionLabel, speedLabel, startScaleLabel, endScaleLabel,
         lifetimeLabel, spreadLabel, gravityLabel].forEach { $0?.removeFromSuperview() }
    }

    // MARK: - Emitter

    private func createEmitter() {
        let obj = GameObj()
        obj.position.set(0, -8)

        obj.add(ParticleEmitterComponent(
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
            startColor: grayStart,
            startColorVariation: grayStartVar,
            endColor: grayEnd,
            endColorVariation: grayEndVar,
            correlatedColorVariation: true,
            gravity: Vec2(0, 0.8)
        ))

        objects.append(obj)
        emitterObj = obj
    }

    // MARK: - Actions

    @objc private func onBurst() {
        emitterObj.get(ParticleEmitterComponent.self)?.spawn(count: 40)
    }

    @objc private func onColorToggle() {
        isNeon.toggle()
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        if isNeon {
            emitter.startColor = neonStart
            emitter.startColorVariation = neonStartVar
            emitter.endColor = neonEnd
            emitter.endColorVariation = neonEndVar
        } else {
            emitter.startColor = grayStart
            emitter.startColorVariation = grayStartVar
            emitter.endColor = grayEnd
            emitter.endColorVariation = grayEndVar
        }
        colorButton.setTitle(isNeon ? "Gray" : "Neon", for: .normal)
    }

    @objc private func onCorrelatedChanged() {
        emitterObj.get(ParticleEmitterComponent.self)?.correlatedColorVariation
            = correlatedSwitch.isOn
    }

    // MARK: - Slider handlers

    @objc private func onEmissionChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let v = emissionSlider.value
        emitter.emissionRate = v
        emissionLabel.text = String(format: "Emission: %.0f/s", v)
    }

    @objc private func onSpeedChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let c = speedSlider.value
        emitter.speedRange = (c * (1 - rangeSpread))...(c * (1 + rangeSpread))
        speedLabel.text = String(format: "Speed: %.1f", c)
    }

    @objc private func onStartScaleChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let c = startScaleSlider.value
        emitter.scaleRange = (c * (1 - rangeSpread))...(c * (1 + rangeSpread))
        startScaleLabel.text = String(format: "Start Scale: %.1f", c)
    }

    @objc private func onEndScaleChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let c = endScaleSlider.value
        emitter.endScaleRange = (c * (1 - rangeSpread))...(c * (1 + rangeSpread))
        endScaleLabel.text = String(format: "End Scale: %.1f", c)
    }

    @objc private func onLifetimeChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let c = lifetimeSlider.value
        emitter.lifetimeRange = (c * (1 - rangeSpread))...(c * (1 + rangeSpread))
        lifetimeLabel.text = String(format: "Lifetime: %.2fs", c)
    }

    @objc private func onSpreadChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let halfSpread = spreadSlider.value
        emitter.angleRange = (.pi / 2 - halfSpread)...(.pi / 2 + halfSpread)
        spreadLabel.text = String(format: "Spread: %.2f rad", halfSpread)
    }

    @objc private func onGravityChanged() {
        guard let emitter = emitterObj.get(ParticleEmitterComponent.self) else { return }
        let g = gravitySlider.value
        emitter.gravity = Vec2(0, g)
        gravityLabel.text = String(format: "Gravity Y: %+.1f", g)
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
        colorButton = makeButton(title: "Neon", action: #selector(onColorToggle))
        renderer.view.addSubview(burstButton)
        renderer.view.addSubview(colorButton)

        emissionLabel = makeSliderLabel()
        speedLabel = makeSliderLabel()
        startScaleLabel = makeSliderLabel()
        endScaleLabel = makeSliderLabel()
        lifetimeLabel = makeSliderLabel()
        spreadLabel = makeSliderLabel()
        gravityLabel = makeSliderLabel()

        emissionSlider   = makeSlider(min: 5,    max: 120,  value: 35,
                                      action: #selector(onEmissionChanged))
        speedSlider      = makeSlider(min: 0.5,  max: 8,    value: 2.5,
                                      action: #selector(onSpeedChanged))
        startScaleSlider = makeSlider(min: 0.5,  max: 6,    value: 2.75,
                                      action: #selector(onStartScaleChanged))
        endScaleSlider   = makeSlider(min: 2,    max: 18,   value: 10.5,
                                      action: #selector(onEndScaleChanged))
        lifetimeSlider   = makeSlider(min: 0.5,  max: 6,    value: 2.75,
                                      action: #selector(onLifetimeChanged))
        spreadSlider     = makeSlider(min: 0.01, max: .pi,  value: 0.25,
                                      action: #selector(onSpreadChanged))
        gravitySlider    = makeSlider(min: -10,  max: 10,   value: 0.8,
                                      action: #selector(onGravityChanged))

        [emissionLabel, speedLabel, startScaleLabel, endScaleLabel,
         lifetimeLabel, spreadLabel, gravityLabel,
         emissionSlider, speedSlider, startScaleSlider, endScaleSlider,
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

        onEmissionChanged()
        onSpeedChanged()
        onStartScaleChanged()
        onEndScaleChanged()
        onLifetimeChanged()
        onSpreadChanged()
        onGravityChanged()

        layoutControls()
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

    private func layoutControls() {
        let safeTop = renderer.view.safeAreaInsets.top
        let safeBottom = renderer.view.safeAreaInsets.bottom
        let safeRight = renderer.view.safeAreaInsets.right
        let viewWidth = renderer.view.bounds.width
        let viewHeight = renderer.view.bounds.height

        // Bottom-center button row.
        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 44
        let gap: CGFloat = 12
        let bottomY = viewHeight - safeBottom - buttonHeight - 16
        let totalButtonsWidth = buttonWidth * 2 + gap
        let buttonsLeftX = (viewWidth - totalButtonsWidth) / 2

        burstButton.frame = CGRect(
            x: buttonsLeftX, y: bottomY,
            width: buttonWidth, height: buttonHeight)
        colorButton.frame = CGRect(
            x: buttonsLeftX + buttonWidth + gap, y: bottomY,
            width: buttonWidth, height: buttonHeight)

        // Right-side slider stack (7 rows — compact to fit landscape).
        let sliderColumnWidth: CGFloat = 200
        let rowHeight: CGFloat = 24
        let labelHeight: CGFloat = 15
        let rowSpacing: CGFloat = 5
        let rightEdge = viewWidth - safeRight - 12
        let columnX = rightEdge - sliderColumnWidth
        var cursorY = safeTop + 10

        // "Correlated" switch row (label on left, switch on right).
        let switchRowHeight: CGFloat = 30
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
            (emissionLabel,   emissionSlider),
            (speedLabel,      speedSlider),
            (startScaleLabel, startScaleSlider),
            (endScaleLabel,   endScaleSlider),
            (lifetimeLabel,   lifetimeSlider),
            (spreadLabel,     spreadSlider),
            (gravityLabel,    gravitySlider)
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
