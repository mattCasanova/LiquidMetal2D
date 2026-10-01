//
//  SkeletonDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 9/21/26.
//

import UIKit
import LiquidMetal2D

/// Skeletal animation demo: a white-box stick figure that idles, walks, jumps, slashes
/// and throws its sword.
///
/// **What it shows:**
/// - **`SkeletonComponent`:** one `GameObj` is the root; the rig's boxes are ordinary
///   `GameObj`s in `skeleton.parts`, submitted like anything else.
/// - **Crossfades:** idle, walk and jump blend into each other instead of snapping.
/// - **Override layers:** slash and throw play on layer 1 and key only the near arm,
///   so the legs keep walking underneath.
/// - **Animation events:** every event a clip passes ("step", "jump", "land", "swing",
///   "throw") shows on screen as it fires.
/// - **Attachment visibility:** the "throw" event hides the sword in the hand and spawns
///   a flying one at the hand's exact position; walking over it shows the hand sword again.
/// - **`flipX`:** walking left mirrors the whole figure.
/// - **Two-bone IK:** with Reach on, the near hand follows the touch point and the
///   elbow bends to fit (`IKConstraint` on the upper and lower near arm).
/// - **Rig and clip files:** the figure loads from `Animations/*.json` (`AnimationFiles`),
///   as a game would, instead of being built in code.
///
/// It plays a loop on its own until the first touch. Then: hold the left or right half of
/// the screen to walk, and use Jump, Throw and Slash (they work while walking). Reach
/// stops walking; drag anywhere and the near hand follows. Tap Reach again to walk.
class SkeletonDemo: Scene {
    static var sceneType: any SceneType { SceneTypes.skeletonDemo }

    private var sceneMgr: SceneManager!
    private var renderer: Renderer!
    private var input: InputReader!

    private let figureScale: Float = 2
    private let groundY: Float = -12
    /// World units per second; matches the stride of the walk clip at this scale.
    private let walkSpeed: Float = 16

    private var root: GameObj!
    private var skeleton: SkeletonComponent!
    private var swordIndex = 0
    private var clips: StickFigure.Clips!
    private var ground: GameObj!
    private var flyingSword = FlyingSword()

    private var walkDirection: Float = 0
    private var isAutoplay = true
    private var autoplay = AutoplayScript()
    /// The near arm's IK chain; on the skeleton only while Reach is on.
    private var reach: IKConstraint!
    private var isReaching: Bool { !skeleton.ikConstraints.isEmpty }

    private var ui: DemoSceneUI!
    private var buttons: [UIButton] = []
    private var reachButton: UIButton!
    private var eventFlash: UILabel!
    private var eventLog: UILabel!
    private var recentEvents: [String] = []

    func initialize(services: SceneServices) {
        self.sceneMgr = services.sceneMgr
        self.renderer = services.renderer
        self.input = services.input

        renderer.setCamera()
        renderer.setCameraRotation(angle: 0)
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        createObjects()

        ui = DemoSceneUI(
            parentView: renderer.view, target: self,
            menuAction: #selector(onMenu))
        createEventLabels()
        reachButton = makeButton(title: "Reach", action: #selector(onReach))
        buttons = [
            makeButton(title: "Jump", action: #selector(onJump)),
            makeButton(title: "Throw", action: #selector(onThrow)),
            makeButton(title: "Slash", action: #selector(onSlash)),
            reachButton,
        ]
        layoutUI()
    }

    func resume() { ui.view.isHidden = false }

    func resize() {
        ui.layout()
        layoutUI()
        renderer.setDefaultPerspective()
    }

    func update(dt: Float) {
        if input.getScreenTouch() != nil {
            isAutoplay = false
        }

        if isAutoplay {
            let step = autoplay.advance(dt: dt)
            walkDirection = step.direction
            switch step.event {
            case .jump: startJump()
            case .slash: startSlash()
            case .throwSword: startThrow()
            case nil: break
            }
        } else if isReaching {
            walkDirection = 0
            if let touch = input.getWorldTouch(forZ: root.zOrder) {
                skeleton.ikConstraints[0].target = Vec2(touch.x, touch.y)
            }
        } else {
            walkDirection = touchDirection()
        }

        moveAndPickClip(dt: dt)
        skeleton.update(dt: dt)
        updateFlyingSword(dt: dt)
    }

    func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        renderer.submit(objects: [ground, flyingSword.object] + skeleton.parts)
        renderer.endPass()
    }

    func shutdown() {
        ui.removeFromSuperview()
    }

    // MARK: - Movement and actions

    private var isJumping: Bool {
        skeleton.animator.currentClipName() == clips.jump.name && !skeleton.animator.isFinished()
    }

    private func moveAndPickClip(dt: Float) {
        if walkDirection != 0 {
            skeleton.flipX = walkDirection < 0
            root.position.x += walkDirection * walkSpeed * dt
            root.position.x = wrapped(root.position.x)
        }

        guard !isJumping else { return }
        if walkDirection != 0 {
            skeleton.animator.play(clips.walk, crossfade: 0.15, restart: false)
        } else {
            skeleton.animator.play(clips.idle, crossfade: 0.25, restart: false)
        }
    }

    private func startJump() {
        guard !isJumping else { return }
        skeleton.animator.play(clips.jump, crossfade: 0.08)
    }

    private func startSlash() {
        skeleton.animator.play(clips.slash, layer: 1, crossfade: 0.05, fadeOutWhenFinished: 0.15)
    }

    private func startThrow() {
        // Nothing to throw while the sword is out.
        guard skeleton.isVisible(attachment: swordIndex) else { return }
        skeleton.animator.play(clips.throwSword, layer: 1, crossfade: 0.05, fadeOutWhenFinished: 0.15)
    }

    /// Left half of the screen walks left, right half walks right.
    private func touchDirection() -> Float {
        guard let touch = input.getScreenTouch() else { return 0 }
        return touch.x < Float(renderer.view.bounds.width) / 2 ? -1 : 1
    }

    /// Wraps an x position so things leaving one side come back on the other.
    private func wrapped(_ x: Float) -> Float {
        let bounds = renderer.getVisibleBounds(zOrder: 0)
        let margin = 3 * figureScale
        if x > bounds.maxX + margin { return bounds.minX - margin }
        if x < bounds.minX - margin { return bounds.maxX + margin }
        return x
    }

    // MARK: - Animation events

    private func handle(event name: String) {
        showEvent(name)
        if name == "throw" {
            releaseSword()
        }
    }

    /// Hide the hand sword and launch a free one from exactly where it was.
    private func releaseSword() {
        let forearm = skeleton.worldTransform(ofBone: StickFigure.swordHandBone)
        let facing: Float = skeleton.flipX ? -1 : 1

        skeleton.setVisible(false, attachment: swordIndex)
        flyingSword.launch(
            at: forearm.apply(to: StickFigure.swordOffset * figureScale),
            rotation: forearm.rotation,
            velocity: Vec2(22 * facing, 10),
            spin: -14 * facing)
    }

    private func updateFlyingSword(dt: Float) {
        flyingSword.update(dt: dt, groundY: groundY)
        flyingSword.object.position.x = wrapped(flyingSword.object.position.x)

        let reach: Float = 2.5
        if flyingSword.isStuck, !isJumping,
           abs(flyingSword.object.position.x - root.position.x) < reach {
            flyingSword.pickUp()
            skeleton.setVisible(true, attachment: swordIndex)
        }
    }

    // MARK: - Setup

    private func createObjects() {
        root = GameObj()
        root.position.set(0, groundY + StickFigure.feetBelowHips * figureScale)

        do {
            let (rig, loadedClips) = try StickFigure.load()
            skeleton = try SkeletonComponent(
                parent: root, definition: rig, defaultTextureID: renderer.defaultTextureId,
                textureIDs: [StickFigure.discTexture: GameTextures.disc])
            clips = loadedClips
            swordIndex = try rig.attachmentIndex(named: StickFigure.swordAttachment)
            // Elbow bends down and back, as an arm reaching forward does.
            reach = try IKConstraint(upper: "upperArmNear", lower: "lowerArmNear", in: rig, bendPositive: false)
        } catch {
            fatalError("StickFigure files are missing or invalid: \(error)")
        }
        skeleton.scale = figureScale
        skeleton.animator.onEvent = { [weak self] _, _, name in self?.handle(event: name) }
        root.add(skeleton)

        ground = GameObj()
        ground.position.set(0, groundY - 0.25)
        ground.scale.set(400, 0.5)
        ground.zOrder = -0.01
        ground.add(AlphaBlendComponent(
            parent: ground, textureID: renderer.defaultTextureId, tintColor: TokyoNight.darker))

        flyingSword.object.scale = StickFigure.swordSize * figureScale
        flyingSword.object.zOrder = 0.012
        flyingSword.object.add(AlphaBlendComponent(
            parent: flyingSword.object, textureID: renderer.defaultTextureId, tintColor: TokyoNight.cyan))
    }

    private func createEventLabels() {
        eventFlash = UILabel()
        eventFlash.font = UIFont.monospacedSystemFont(ofSize: 34, weight: .bold)
        eventFlash.textColor = TokyoNight.uiBlue
        eventFlash.textAlignment = .center
        eventFlash.alpha = 0
        ui.view.addSubview(eventFlash)

        eventLog = UILabel()
        eventLog.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        eventLog.textColor = TokyoNight.uiComment
        eventLog.textAlignment = .right
        eventLog.numberOfLines = 0
        ui.view.addSubview(eventLog)
    }

    /// Flashes the newest event big, and keeps the last few in a list, newest first.
    private func showEvent(_ name: String) {
        recentEvents.insert(name, at: 0)
        recentEvents = Array(recentEvents.prefix(8))
        eventLog.text = recentEvents.joined(separator: "\n")

        eventFlash.text = name.uppercased()
        eventFlash.layer.removeAllAnimations()
        eventFlash.alpha = 1
        UIView.animate(withDuration: 0.6, delay: 0.1, options: [.curveEaseOut, .allowUserInteraction]) {
            self.eventFlash.alpha = 0
        }
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(frame: .zero)
        button.backgroundColor = TokyoNight.uiDarker
        button.setTitle(title, for: .normal)
        button.setTitleColor(TokyoNight.uiBlue, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: action, for: .touchUpInside)
        ui.view.addSubview(button)
        return button
    }

    private func layoutUI() {
        let size = ui.view.bounds.size
        let gap: CGFloat = 12
        let width = (size.width - gap * CGFloat(buttons.count + 1)) / CGFloat(buttons.count)
        let height: CGFloat = 48
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(
                x: gap + CGFloat(index) * (width + gap), y: size.height - height - 16,
                width: width, height: height)
        }

        eventFlash.frame = CGRect(x: 0, y: size.height * 0.2, width: size.width, height: 44)
        eventLog.frame = CGRect(x: size.width - 140, y: 8, width: 128, height: 170)
    }

    @objc func onJump() { isAutoplay = false; startJump() }
    @objc func onThrow() { isAutoplay = false; startThrow() }
    @objc func onSlash() { isAutoplay = false; startSlash() }

    /// Starts reaching toward a point in front of the chest; the next touch moves it.
    @objc func onReach() {
        isAutoplay = false
        if isReaching {
            skeleton.ikConstraints = []
        } else {
            let facing: Float = skeleton.flipX ? -1 : 1
            reach.target = root.position + Vec2(5 * facing, 3)
            skeleton.ikConstraints = [reach]
        }
        reachButton.setTitle(isReaching ? "Reach: On" : "Reach", for: .normal)
    }

    @objc func onMenu() { ui.view.isHidden = true; sceneMgr.pushScene(type: SceneTypes.pauseDemo) }

    static func build() -> Scene { return SkeletonDemo() }
}

/// The sword once it has left the hand: an ordinary object with simple ballistics
/// that sticks where it hits the ground.
private struct FlyingSword {
    let object: GameObj
    private var velocity = Vec2()
    private var spin: Float = 0
    private(set) var isStuck = false

    init() {
        object = GameObj()
        object.isActive = false
    }

    private let gravity: Float = -50

    mutating func launch(at position: Vec2, rotation: Float, velocity newVelocity: Vec2, spin newSpin: Float) {
        object.position = position
        object.rotation = rotation
        object.isActive = true
        velocity = newVelocity
        spin = newSpin
        isStuck = false
    }

    mutating func update(dt: Float, groundY: Float) {
        guard object.isActive, !isStuck else { return }
        velocity.y += gravity * dt
        object.position += velocity * dt
        object.rotation += spin * dt

        // Stop with the point buried a little way into the ground.
        let stickHeight = groundY + 0.8
        if object.position.y <= stickHeight {
            object.position.y = stickHeight
            isStuck = true
        }
    }

    mutating func pickUp() {
        object.isActive = false
        isStuck = false
    }
}

/// The loop the demo plays until the first touch: each step sets a walking
/// direction and may fire one event as it starts.
private struct AutoplayScript {
    enum Event { case jump, slash, throwSword }

    private let steps: [(duration: Float, direction: Float, event: Event?)] = [
        (1.5, 0, nil),
        (2.0, 1, nil),
        (1.2, 1, .jump),
        (1.0, 1, .slash),
        (2.2, 1, .throwSword),
        (2.0, -1, nil),
        (1.5, 0, .slash),
        (1.2, 0, .jump),
    ]
    private var index = 0
    private var elapsed: Float = 0
    private var hasFiredEvent = false

    mutating func advance(dt: Float) -> (direction: Float, event: Event?) {
        elapsed += dt
        while elapsed >= steps[index].duration {
            elapsed -= steps[index].duration
            index = (index + 1) % steps.count
            hasFiredEvent = false
        }

        var event: Event?
        if !hasFiredEvent {
            event = steps[index].event
            hasFiredEvent = true
        }
        return (steps[index].direction, event)
    }
}
