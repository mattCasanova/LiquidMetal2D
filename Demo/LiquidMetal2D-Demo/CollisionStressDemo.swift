import SwiftUI
import LiquidMetal2D

/// Collision stress test comparing brute force vs SpatialGrid broadphase.
///
/// 2000 ships bounce around the screen with CircleColliders. A toggle
/// switches between O(n²) brute force and SpatialGrid broadphase.
/// Stats show object count, pairs checked, and frame time so you can
/// see the performance difference directly.
class CollisionStressDemo: LiquidMetal2D.Scene {
    static var sceneType: any SceneType { SceneTypes.collisionStressDemo }

    private var sceneMgr: SceneManager!
    private var renderer: Renderer!
    private var input: InputReader!
    private var ui: DemoUI!

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

    private let controls = CollisionStressControls()

    func initialize(services: SceneServices) {
        self.sceneMgr = services.sceneMgr
        self.renderer = services.renderer
        self.input = services.input
        self.ui = services.demoUI

        renderer.setCamera()
        renderer.setCameraRotation(angle: 0)
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        let bounds = renderer.getVisibleBounds(zOrder: 0)
        grid = SpatialGrid(bounds: bounds, cellWidth: 3, cellHeight: 3)

        createObjects(bounds: bounds)

        controls.onToggle = { [unowned self] in useBroadphase.toggle() }
        showOverlay()
    }

    func resume() { showOverlay() }

    func resize() {
        renderer.setDefaultPerspective()
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
        ui.overlay = nil
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

    private func showOverlay() {
        ui.overlay = AnyView(CollisionStressPanel(controls: controls))
    }

    private func updateStats() {
        let fps = Int(smoothedFPS)
        let mode = useBroadphase ? "Spatial Grid" : "Brute Force"
        let bruteForceCount = objectCount * (objectCount - 1) / 2
        controls.stats = """
        \(mode) | \(objectCount) objects | \(fps) FPS
        Pairs: \(pairsChecked.formatted()) (\(collisionsFound) hits) | Brute force: \(bruteForceCount.formatted())
        """
    }

    static func build() -> LiquidMetal2D.Scene { return CollisionStressDemo() }
}

/// The stats readout and the mode switch.
@MainActor
@Observable
final class CollisionStressControls {
    var stats = ""
    var onToggle: () -> Void = {}
}

struct CollisionStressPanel: View {
    let controls: CollisionStressControls

    var body: some View {
        ZStack(alignment: .top) {
            ReadoutText(controls.stats, size: 14)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(TokyoNight.color(TokyoNight.bg).opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                .padding(.top, 8)
            BottomBar {
                Button("Switch Mode", action: controls.onToggle)
            }
        }
    }
}
