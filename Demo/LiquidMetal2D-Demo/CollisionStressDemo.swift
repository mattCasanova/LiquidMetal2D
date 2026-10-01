import UIKit
import LiquidMetal2D

/// Collision stress test comparing brute force vs SpatialGrid broadphase.
///
/// 2000 ships bounce around the screen with CircleColliders. A toggle
/// switches between O(n²) brute force and SpatialGrid broadphase.
/// Stats show object count, pairs checked, and frame time so you can
/// see the performance difference directly.
class CollisionStressDemo: Scene {
    static var sceneType: any SceneType { SceneTypes.collisionStressDemo }

    private var sceneMgr: SceneManager!
    private var renderer: Renderer!
    private var input: InputReader!

    private let objectCount = 7000
    private var objects = [GameObj]()
    private var colliders = [CircleCollider]()
    private var colliderMap = [ObjectIdentifier: CircleCollider]()

    private var grid: SpatialGrid!
    private var useBroadphase = true

    // Stats
    private var pairsChecked = 0
    private var collisionsFound = 0
    private var smoothedFPS: Float = 60
    private let fpsSmoothing: Float = 0.05

    // UI
    private var ui: DemoSceneUI!
    private var statsLabel: UILabel!
    private var toggleButton: UIButton!

    func initialize(services: SceneServices) {
        self.sceneMgr = services.sceneMgr
        self.renderer = services.renderer
        self.input = services.input

        renderer.setCamera()
        renderer.setCameraRotation(angle: 0)
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        let bounds = renderer.getVisibleBounds(zOrder: 0)
        grid = SpatialGrid(bounds: bounds, cellWidth: 3, cellHeight: 3)

        createObjects(bounds: bounds)
        setupUI()
    }

    func resume() { ui.view.isHidden = false }

    func resize() {
        renderer.setDefaultPerspective()
        ui.layout()
        layoutUI()
    }

    func update(dt: Float) {
        // Exponential moving average for stable FPS display
        if dt > 0 {
            let currentFPS = 1.0 / dt
            smoothedFPS = smoothedFPS + fpsSmoothing * (currentFPS - smoothedFPS)
        }
        let bounds = renderer.getVisibleBounds(zOrder: 0)

        // Move objects and wrap at bounds
        for obj in objects {
            obj.position += obj.velocity * dt
            obj.position.x = GameMath.wrap(value: obj.position.x, low: bounds.minX, high: bounds.maxX)
            obj.position.y = GameMath.wrap(value: obj.position.y, low: bounds.minY, high: bounds.maxY)
        }

        if useBroadphase {
            checkCollisionBroadphase()
        } else {
            checkCollisionBruteForce()
        }

        updateStats()
    }

    func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        renderer.submit(objects: objects)
        renderer.endPass()
    }

    func shutdown() {
        objects.removeAll()
        colliders.removeAll()
        colliderMap.removeAll()
        statsLabel.removeFromSuperview()
        toggleButton.removeFromSuperview()
        ui.removeFromSuperview()
    }

    // MARK: - Collision

    private func checkCollisionBroadphase() {
        grid.clear()
        grid.insert(contentsOf: objects)
        pairsChecked = 0
        collisionsFound = 0

        grid.forEachPotentialPair { [self] a, b in
            pairsChecked += 1
            guard let cA = colliderMap[ObjectIdentifier(a)],
                  let cB = colliderMap[ObjectIdentifier(b)] else { return }
            if cA.doesCollideWith(collider: cB) {
                collisionsFound += 1
                bounce(a, b)
            }
        }
    }

    private func checkCollisionBruteForce() {
        pairsChecked = 0
        collisionsFound = 0

        for i in 0..<objects.count {
            for j in (i + 1)..<objects.count {
                pairsChecked += 1
                if colliders[i].doesCollideWith(collider: colliders[j]) {
                    collisionsFound += 1
                    bounce(objects[i], objects[j])
                }
            }
        }
    }

    /// Simple elastic-ish bounce: swap velocities
    private func bounce(_ a: GameObj, _ b: GameObj) {
        let temp = a.velocity
        a.velocity = b.velocity
        b.velocity = temp
    }

    // MARK: - Setup

    private func createObjects(bounds: WorldBounds) {
        objects.removeAll()
        colliders.removeAll()

        for _ in 0..<objectCount {
            let obj = GameObj()
            obj.position = Vec2(
                Float.random(in: bounds.minX...bounds.maxX),
                Float.random(in: bounds.minY...bounds.maxY))
            obj.scale.set(1, 1)

            let angle = Float.random(in: 0...GameMath.twoPi)
            let speed = Float.random(in: 3...12)
            obj.velocity.set(angle: angle)
            obj.velocity *= speed
            obj.rotation = angle

            let texIndex = Int.random(in: 0...2)
            obj.add(AlphaBlendComponent(
                parent: obj,
                textureID: GameTextures.all[texIndex],
                tintColor: TokyoNight.accents.randomElement()!))

            let collider = CircleCollider(parent: obj, radius: 0.5)
            objects.append(obj)
            colliders.append(collider)
            colliderMap[ObjectIdentifier(obj)] = collider
        }
    }

    // MARK: - UI

    private func setupUI() {
        ui = DemoSceneUI(
            parentView: renderer.view, target: self,
            menuAction: #selector(onMenu))

        statsLabel = UILabel()
        statsLabel.textColor = TokyoNight.uiFg
        statsLabel.backgroundColor = TokyoNight.uiBg.withAlphaComponent(0.85)
        statsLabel.textAlignment = .center
        statsLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        statsLabel.numberOfLines = 0
        statsLabel.layer.cornerRadius = 6
        statsLabel.clipsToBounds = true
        renderer.view.addSubview(statsLabel)

        toggleButton = UIButton(frame: .zero)
        toggleButton.backgroundColor = TokyoNight.uiDarker
        toggleButton.setTitleColor(TokyoNight.uiBlue, for: .normal)
        toggleButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        toggleButton.layer.cornerRadius = 6
        toggleButton.addTarget(self, action: #selector(onToggle), for: .touchUpInside)
        renderer.view.addSubview(toggleButton)

        updateToggleLabel()
        layoutUI()
    }

    private func layoutUI() {
        let safeTop = renderer.view.safeAreaInsets.top
        let safeBottom = renderer.view.safeAreaInsets.bottom
        let viewWidth = renderer.view.bounds.width
        let viewHeight = renderer.view.bounds.height

        statsLabel.frame = CGRect(
            x: 0, y: safeTop + 8,
            width: viewWidth, height: 50)

        let buttonWidth: CGFloat = 180
        let buttonHeight: CGFloat = 44
        toggleButton.frame = CGRect(
            x: (viewWidth - buttonWidth) / 2,
            y: viewHeight - safeBottom - buttonHeight - 16,
            width: buttonWidth, height: buttonHeight)
    }

    private func updateStats() {
        let fps = Int(smoothedFPS)
        let mode = useBroadphase ? "Spatial Grid" : "Brute Force"
        let bruteForceCount = objectCount * (objectCount - 1) / 2
        statsLabel.text = """
        \(mode) | \(objectCount) objects | \(fps) FPS
        Pairs: \(pairsChecked.formatted()) (\(collisionsFound) hits) | Brute force: \(bruteForceCount.formatted())
        """
    }

    private func updateToggleLabel() {
        toggleButton.setTitle("Switch Mode", for: .normal)
    }

    @objc private func onToggle() {
        useBroadphase.toggle()
        updateToggleLabel()
    }

    @objc func onMenu() {
        ui.view.isHidden = true
        sceneMgr.pushScene(type: SceneTypes.pauseDemo)
    }

    static func build() -> Scene { return CollisionStressDemo() }
}
