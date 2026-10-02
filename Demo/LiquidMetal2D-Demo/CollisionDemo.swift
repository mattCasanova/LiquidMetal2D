//
//  CollisionDemo.swift
//  LiquidMetal2D-Demo
//
//  Originally CollisionScene by Matt Casanova on 3/24/20.
//

import Foundation
import LiquidMetal2D

/// Collision detection and AI state machine demo.
///
/// **What the user sees:** Ships spawn one per second (up to 200), wandering autonomously.
/// Each ship picks a random target point, rotates to face it, moves to it, then repeats.
/// Most ships are blue, but there is a 1% chance of spawning orange. When an orange ship
/// collides with a blue ship, the blue ship turns orange -- creating a spreading "infection."
///
/// **Engine features demonstrated:**
/// - **SpatialGrid broadphase:** `SpatialGrid(bounds:cellWidth:cellHeight:)` partitions the
///   world into cells. Each frame: `clear()`, `insert(contentsOf:)`, `potentialPairs()` returns
///   only nearby candidate pairs instead of O(n^2) brute force.
/// - **CircleCollider narrowphase:** `doesCollideWith(collider:)` performs circle-circle
///   intersection on the candidate pairs returned by the grid.
/// - **FindAndGoBehavior (3-state AI):** A multi-state Behavior with three states:
///   - **FindState:** Picks a random target position within world bounds.
///   - **RotateState:** Rotates the ship toward the target using cross product for turn direction.
///   - **GoState:** Moves forward until reaching the target, then loops back to FindState.
/// - **Scheduler for spawning:** A repeating ScheduledTask spawns one ship per second by
///   finding the first inactive object in the pool and activating it.
/// - **Object pooling (isActive flag):** All 200 GameObjs are pre-allocated. The `isActive`
///   flag controls which ones update and draw. Active objects are sorted to the front so the
///   draw loop can `break` early when it hits an inactive object.
/// - **Component system:** Each object uses `GameObj.add/get` to attach Behavior, Collider,
///   and ZombieDemoComponent instead of subclass properties.
class CollisionDemo: Scene {
    static var sceneType: any SceneType { SceneTypes.collisionDemo }

    private var sceneMgr: SceneManager!
    private var renderer: Renderer!
    private var input: InputReader!

    private let objectCount = 200
    private var objects = [GameObj]()

    private let scheduler = Scheduler()
    private var grid: SpatialGrid!

    /// Scene protocol: called once when the scene is created.
    func initialize(services: SceneServices) {
        self.sceneMgr = services.sceneMgr
        self.renderer = services.renderer
        self.input = services.input

        // Camera2D.defaultDistance is the engine's suggested starting camera z position
        renderer.setCamera()
        renderer.setCameraRotation(angle: 0)
        renderer.setDefaultPerspective()

        // Cell size of 4 covers the largest collider diameter (super zombie radius 2 -> diameter 4)
        let bounds = renderer.getVisibleBounds(zOrder: 0)
        grid = SpatialGrid(bounds: bounds, cellWidth: 4, cellHeight: 4)

        createObjects()

        // Spawn 20 ships immediately so the scene starts populated
        for _ in 0..<20 { spawnShip() }

        // Spawn one ship per second using a repeating scheduled task
        scheduler.add(task: ScheduledTask(time: 1, action: { [unowned self] _ in
            self.spawnShip()
        }))
    }

    func resume() {}

    /// Scene protocol: called on device rotation. Recalculate projection and recreate objects
    /// because the visible world bounds have changed.
    func resize() {
        renderer.setDefaultPerspective()
    }

    private let maxAge: Float = 30.0

    func update(dt: Float) {
        // Advance the spawn timer
        scheduler.update(dt: dt)

        // Update all objects' behaviors and age them
        for i in 0..<objects.count {
            let obj = objects[i]
            guard obj.isActive else { continue }

            obj.get(FindAndGoBehavior.self)?.update(dt: dt)

            if let zombie = obj.get(ZombieDemoComponent.self) {
                zombie.age += dt

                // Blue and green die after 30s. Zombies persist forever.
                if obj.get(AlphaBlendComponent.self)?.textureID != GameTextures.orange
                    && zombie.age >= maxAge {
                    obj.isActive = false
                }
            }
        }

        checkCollision()

        objects.sort(by: Self.activeFirst)
    }

    /// Active objects first.
    /// A `nonisolated` function, not a closure: a closure written in this
    /// `@MainActor` scene would make `sort` check the actor on every comparison.
    private nonisolated static func activeFirst(_ lhs: GameObj, _ rhs: GameObj) -> Bool {
        lhs.isActive && !rhs.isActive
    }

    func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        renderer.submit(objects: objects)
        renderer.endPass()
    }

    /// Scene protocol: clean up everything -- objects, textures, scheduler, and UI.
    func shutdown() {
        objects.removeAll()
        scheduler.clear()
    }

    /// Pre-allocate the full pool of GameObjs. They start inactive (isActive = false)
    /// and get activated one per second by the scheduler.
    private func createObjects() {
        objects.removeAll()
        for _ in 0..<objectCount {
            let obj = GameObj()
            obj.isActive = false
            obj.add(AlphaBlendComponent(parent: obj, textureID: GameTextures.blue))
            objects.append(obj)
        }
    }

    private func spawnShip() {
        guard let obj = objects.last(where: { !$0.isActive }) else { return }
        let bounds = renderer.getVisibleBounds(zOrder: 0)

        // 5% zombie, 2% super zombie. Green only spawns (3%) when 20+ reds exist.
        let redCount = objects.filter {
            $0.isActive && $0.get(AlphaBlendComponent.self)?.textureID == GameTextures.orange
        }.count
        let roll = Int.random(in: 0..<100)
        let texIndex: Int
        let isSuperZombie: Bool
        
        if roll < 2 {
            texIndex = 2; isSuperZombie = true
        } else if roll < 7 {
            texIndex = 2; isSuperZombie = false
        } else if roll < 10 && redCount >= 20 {
            texIndex = 1; isSuperZombie = false
        } else {
            texIndex = 0; isSuperZombie = false
        }

        obj.position.set(
            Float.random(in: bounds.minX...bounds.maxX),
            Float.random(in: bounds.minY...bounds.maxY))

        obj.scale = isSuperZombie ? Vec2(4, 4) : Vec2(2, 2)
        if let comp = obj.get(AlphaBlendComponent.self) {
            comp.textureID = GameTextures.all[texIndex]
            comp.tintColor = TokyoNight.shipTints[texIndex]
        }
        obj.isActive = true

        obj.add(FindAndGoBehavior(parent: obj, bounds: bounds))
        obj.add(CircleCollider(parent: obj, radius: isSuperZombie ? 2 : 1))

        let zombie = ZombieDemoComponent(parent: obj)
        zombie.charges = texIndex == 1 ? 3 : (isSuperZombie ? 3 : 0)
        zombie.isSuper = isSuperZombie
        zombie.age = 0
        obj.add(zombie)
    }

    private func setType(_ obj: GameObj, index: Int) {
        if let comp = obj.get(AlphaBlendComponent.self) {
            comp.textureID = GameTextures.all[index]
            comp.tintColor = TokyoNight.shipTints[index]
        }
        if let zombie = obj.get(ZombieDemoComponent.self) {
            zombie.age = 0
        }
    }

    /// Broadphase + narrowphase collision with zombie/cure mechanics.
    /// SpatialGrid reduces candidate pairs from O(n^2) to nearby objects only.
    private func checkCollision() {
        grid.clear()
        grid.insert(contentsOf: objects)

        let redTex = GameTextures.orange
        let blueTex = GameTextures.blue
        let greenTex = GameTextures.green

        for (first, second) in grid.potentialPairs() {
            guard first.isActive, second.isActive else { continue }
            guard let fCollider = first.get(CircleCollider.self),
                  let sCollider = second.get(CircleCollider.self) else { continue }
            guard fCollider.doesCollideWith(collider: sCollider) else { continue }

            guard let fTex = first.get(AlphaBlendComponent.self)?.textureID,
                  let sTex = second.get(AlphaBlendComponent.self)?.textureID else { continue }

            // Red + Blue -> 80% infection, 20% blue dies
            if fTex == redTex && sTex == blueTex {
                bite(second)
            } else if sTex == redTex && fTex == blueTex {
                bite(first)

            // Green + Red -> cure the zombie, green loses a charge
            } else if fTex == greenTex && sTex == redTex {
                cure(zombie: second, healer: first)
            } else if sTex == greenTex && fTex == redTex {
                cure(zombie: first, healer: second)

            // Green + Blue -> blue becomes green (cure spreads)
            } else if fTex == greenTex && sTex == blueTex {
                recruit(second)
            } else if sTex == greenTex && fTex == blueTex {
                recruit(first)
            }
        }
    }

    /// Convert a blue ship to green (healer). Gets fresh 3 charges.
    private func recruit(_ obj: GameObj) {
        setType(obj, index: 1)
        if let zombie = obj.get(ZombieDemoComponent.self) {
            zombie.charges = 3
        }
    }

    /// Zombie bite: 80% chance blue becomes red, 20% blue dies.
    private func bite(_ blue: GameObj) {
        if Float.random(in: 0...1) < 0.8 {
            setType(blue, index: 2)
            if let zombie = blue.get(ZombieDemoComponent.self) {
                zombie.isSuper = false
                zombie.charges = 0
            }
        } else {
            blue.isActive = false
        }
    }

    /// Green cures a zombie. Normal zombies become blue. Super zombies
    /// lose a hit point and die when charges hit 0. Green loses a charge
    /// and dies after 3 cures.
    private func cure(zombie: GameObj, healer: GameObj) {
        if let zData = zombie.get(ZombieDemoComponent.self) {
            if zData.isSuper {
                zData.charges -= 1
                if zData.charges <= 0 {
                    zombie.isActive = false
                }
            } else {
                setType(zombie, index: 0)
            }
        }

        if let hData = healer.get(ZombieDemoComponent.self) {
            hData.charges -= 1
            if hData.charges <= 0 {
                healer.isActive = false
            }
        }
    }

    /// Required factory method for TSceneBuilder.
    static func build() -> Scene { return CollisionDemo() }
}
