# Blog Updates — LiquidMetal2D Development Log

## Session: March 22-23, 2026

### Major Changes This Session

#### 1. Broadphase Collision Detection — SpatialGrid

The biggest feature: we added a uniform grid broadphase collision system that takes collision detection from O(n^2) to practically O(n).

**The problem:** With 200 objects, brute force checks ~20,000 pairs per frame. At 1000 objects: 500,000 pairs. At 4000: 8 million. It doesn't scale.

**The solution:** `SpatialGrid` divides the world into fixed-size cells. Each frame, objects register in their cell by position. Instead of checking every pair, we only check objects in the same or adjacent cells.

**The algorithm:** Half-neighbor traversal — for each cell, we pair objects within the cell, then pair with 4 "forward" neighbors (right, below-left, below, below-right). This visits each cell-pair exactly once with zero duplicate pairs and no deduplication overhead.

**The results:**
- 2000 objects: 60fps with spatial grid, 14fps brute force
- 4000 objects: 50-60fps spatial grid, ~2fps brute force
- 5000 objects: 30fps spatial grid, ~1fps brute force

**Performance lessons learned:**
- The first implementation was actually *slower* than brute force despite checking fewer pairs. Why? Two hidden costs:
  1. `potentialPairs()` allocated a new array of tuples every frame — thousands of allocations per second
  2. Looking up which collider belongs to which object used a linear scan (`firstIndex(where:)`) — O(n) per pair lookup
- Fix #1: Added `forEachPotentialPair()` — a callback-based API that iterates inline with zero allocation
- Fix #2: Replaced linear scan with an `[ObjectIdentifier: Collider]` dictionary for O(1) lookup
- After both fixes: 60fps at 4000 objects. The lesson: algorithmic improvements mean nothing if your constants are terrible.

#### 2. Scene System Overhaul — Eliminated Boilerplate

Completely reworked how scenes are registered and built:

**Before:**
```swift
sceneFactory.addScene(type: SceneTypes.menu, builder: TSceneBuilder<MenuScene>())
sceneFactory.addScene(type: SceneTypes.gameplay, builder: TSceneBuilder<GameplayScene>())
// ... repeat for every scene
```

**After:**
```swift
sceneFactory.addScenes([
    MenuScene.self,
    GameplayScene.self,
])
```

Each scene declares its own type via `static var sceneType`. `DefaultScene.build()` uses `Self()` so subclasses inherit it automatically — no more `override class func build()` boilerplate. Deleted `SceneBuilder` and `TSceneBuilder` entirely.

#### 3. DefaultScene Subclassing

Made all `DefaultScene` methods `open` so games can subclass it from outside the module. Changed `build()` from `static` to `class func` with `Self()` return, and added `required init()`. Two demo scenes (`InstanceDemo`, `SchedulerDemo`) were refactored from awkward delegation pattern to clean subclassing — removing the `sceneDelegate.` prefix everywhere.

#### 4. Renderer API Cleanup

- `setDefaultPerspective()` no longer sets the camera — it only configures the projection. Camera and projection are now independent concerns.
- Added `setCamera()` no-arg overload that resets to origin at default distance.
- Added `setOrthographic(width:height:)` convenience that takes just screen dimensions.
- Renamed `getWorldBoundsFromCamera`/`getWorldBounds` to `getVisibleBounds` — because "world bounds" implies the whole level, but this is just the camera's visible area.
- Replaced 12 identical 5-line `setPerspective(fov:aspect:nearZ:farZ:)` calls across the demo with one-line `setDefaultPerspective()`.

#### 5. Behavior/State Machine Cleanup

Extracted `NilState` and `NilBehavior` into their own files with doc comments. They were previously hidden at the bottom of the protocol files.

#### 6. CLAUDE.md Overhaul

Rewrote the library's CLAUDE.md from scratch to reflect the current architecture — MetalMath merged in, new directory structure, rendering pipeline details, all new features. Created a CLAUDE.md for the demo project too.

#### 7. CameraRotationDemo Rewrite

Completely redesigned the demo to properly showcase both features it's named for:
- **Camera rotation:** Continuous sine-wave oscillation (always on)
- **Scheduler:** Button triggers 3 chained waves of ships (blue left-to-right, red top-to-bottom, green right-to-left). Shows repeat counts, chaining, and the `dt` callback.

Previously it used an empty scheduler callback as a pause toggle — a misuse of the scheduler that didn't actually demonstrate anything.

#### 8. New Demo: Collision Stress Test

4000 ships bouncing around with CircleColliders. Toggle between spatial grid (60fps) and brute force (~2fps) with live stats showing pairs checked, collisions found, and smoothed FPS. Visually dramatic proof that broadphase works.

#### 9. SwiftLint Cleanup

Suppressed `function_parameter_count` on the 4 orthographic projection methods (all legitimately need 6 params). Fixed deprecated `contentEdgeInsets` in PauseDemo with modern `UIButton.Configuration`.

#### 10. Project Board Audit

Did a full audit of both the library and demo:
- Filed 12 new library issues (code cleanup, missing features, test gaps)
- Filed 6 demo issues (underdeveloped feature coverage)
- Prioritized all unlabeled issues P0-P4
- Closed stale issues that were already done

### Architecture Insights

**Why uniform grid over quadtree?** For a 2D iOS game where most objects are similar size, uniform grid is simpler and faster. Quadtree adapts to varied density but has higher overhead per operation. The grid can always be swapped later since the API (`insert`, `query`, `potentialPairs`) is the same regardless of spatial data structure.

**Why callback over return value?** `forEachPotentialPair()` vs `potentialPairs()` is the classic allocation-free iteration pattern. In a game loop running 60 times per second, even small allocations add up. The callback version does the exact same traversal but never creates an intermediate collection. Both APIs exist — use the callback in hot paths, the array version when you need to store/filter/sort the pairs.

**Why `Self()` in `build()`?** Swift's `Self` refers to the actual runtime type, not the declaring class. So `DefaultScene.build()` returning `Self()` means when called on a `MenuScene` subclass, it returns `MenuScene()`. This eliminates the need for every subclass to override `build()` with its own constructor — a pattern that was pure boilerplate.

---

## Coming Next: Migrating to a Component System

### The Problem with Inheritance

Right now, extending GameObj requires subclassing. Want a collider? Make a `CollisionObj`. Want a behavior? Make a `BehaviorObj`. Want both? Now you need multiple inheritance (which Swift doesn't have) or awkward workarounds like delegation. In the demo code, we're doing `for case let obj as BehaviorObj in objects` — runtime type casting in a hot loop just to access a behavior property.

This is the classic inheritance trap that game developers have been solving since the early 2000s. Scott Bilas presented "A Data-Driven Game Object System" at GDC 2002, describing how Dungeon Siege used components instead of inheritance to manage 7,300+ unique object types. In game dev circles, we called this the **Component Object Model** (not to be confused with Microsoft's unrelated COM API). The pattern was well-established by the mid-2000s — years before Unity popularized the term "Entity Component System." ECS is essentially the same idea rebranded with more formalism around Systems and storage layouts, but the core insight — composition over inheritance for game objects — hasn't changed in 20 years.

### The Plan: Lightweight Component Bag

We're not going full ECS. No archetype storage, no parallel systems, no entity-as-pure-ID. GameObj keeps its built-in properties (position, velocity, scale, rotation, textureID) because this is a 2D engine and everything draws.

What we're adding: a component dictionary on GameObj. Instead of subclassing, you compose:

```swift
// Before (inheritance):
class CollisionObj: GameObj {
    var collider: Collider = NilCollider()
}

// After (composition):
let ship = GameObj()
ship.add(CircleCollider(obj: ship, radius: 1))
ship.add(FindAndGoBehavior(obj: ship, bounds: bounds))

// Access:
obj.get(Collider.self)?.doesCollideWith(...)
obj.get(Behavior.self)?.update(dt: dt)
```

Components use `unowned let parent: GameObj` — not weak, not optional. If a component outlives its parent, it crashes intentionally. That's better than silent nil behavior where your game appears to work but things stop colliding with no explanation. The ownership model is clear: scene owns objects, objects own components.

### Why This Matters

Once components are in place, every demo scene can use `DefaultScene` without casting. The spatial grid can pull colliders from components directly. New features (health, damage, AI, animation) just become new component types — no subclass explosion. It's the foundation that makes everything else cleaner.

More on this in the next session when we implement it.
