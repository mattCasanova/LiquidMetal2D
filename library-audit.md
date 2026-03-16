# LiquidMetal2D — Full Library Audit

## Context

Deep audit of the entire LiquidMetal2D engine covering rendering pipeline, engine architecture, math, collision, input, scene management, and more. Goal: identify performance issues, bugs, missing features, and create a prioritized roadmap for improvements.

---

## CRITICAL — Performance & Bugs

### 1. Instanced Rendering (biggest performance win)
- **Current:** Each object = 1 draw call (4 vertices). 4500 objects = 4500 draw calls.
- **Fix:** Change shader to accept `instance_id`, draw all objects in 1 call with `instanceCount: N`.
- **Effort:** ~30 min (shader change + 1 line in DefaultRenderer)
- **Impact:** 10-50x fewer GPU commands

### 2. Per-frame WorldUniform allocation in DefaultScene.draw()
- `Scene.swift:51` creates `WorldUniform()` inside the draw loop every frame
- **Fix:** Reuse a single instance, just update its transform
- **Effort:** 5 min

### 3. Unsafe pointer arithmetic without bounds checking
- `WorldUniform.setBuffer()` and `ProjectionUniform.setBuffer()` use `memcpy` with raw pointer math
- No validation that `offsetIndex` is within buffer capacity
- **Risk:** Memory corruption if uniform buffer overflows
- **Fix:** Add bounds check or assert

### 4. SceneFactory force-unwrap crash
- `SceneFactory.get()` force-unwraps: `builderMap[type.value]!`
- Crashes if scene type isn't registered
- **Fix:** Return optional or fatalError with descriptive message

### 5. Deprecated `packed_float` types in shader
- Shader uses `packed_float3` and `packed_float2` (deprecated in Metal 2.1)
- **Fix:** Use regular `float3`/`float2`

---

## HIGH — Essential Features

### 6. Shader as embedded string → .metal file
- Shader is hardcoded as a Swift string in `constants.swift`
- No compile-time validation, no Xcode syntax highlighting
- **Fix:** Move to a .metal file (requires bundling strategy for SPM)

### 7. AABB Collider class
- AABB intersection tests exist in `Intersect` but there's no `AABBCollider` class
- Games need rectangle collisions constantly
- **Fix:** Create `AABBCollider: Collider, MutableAABB` following Circle/MutableCircle pattern

### 8. Broadphase collision detection
- Currently O(N²) — every object checked against every other
- At 1000 objects: 1,000,000 checks per frame
- **Fix:** Implement spatial grid or quadtree for broadphase

### 9. Input system — single touch only
- `LiquidViewController` only reads `touches.first`
- No multi-touch, no touch phase (began/moved/ended), no keyboard, no gamepad
- **Fix:** Expand InputReader/InputWriter to support multiple touches and input types

### 10. Texture loading blocks main thread
- `UIImage(contentsOfFile:)` and `CGContext` allocation happen synchronously
- Large textures stall the game loop
- **Fix:** Load on background thread, upload to GPU asynchronously

### 11. No sprite batching by texture
- Each object binds its texture individually
- Objects using the same texture could be batched
- **Fix:** Sort by texture, reduce texture bind calls

---

## MEDIUM — Important Improvements

### 12. Empty useOrthographic() stub
- `DefaultRenderer.useOrthographic()` is empty — incomplete API
- **Fix:** Implement or remove from protocol

### 13. Collision callbacks / events
- No onCollisionEnter/Stay/Exit pattern
- Games must manually track collision state
- **Fix:** Add collision event system

### 14. Collision groups / layers
- No way to filter which objects collide with which
- **Fix:** Add layer bitmask to Collider protocol

### 15. State machine hierarchy
- Current `Behavoir` only supports one state at a time
- Can't do nested states (e.g., "Moving" with sub-states "Walking"/"Running")
- **Fix:** Support state stacks or composite states

### 16. Scheduler pause/resume
- Can't pause individual tasks or the whole scheduler
- **Fix:** Add `isPaused` flag to ScheduledTask and Scheduler

### 17. Scheduler task removal during iteration
- `remove(toRemove:)` modifies the array during `for task in tasks` loop
- **Risk:** Potential mutation during iteration
- **Fix:** Mark tasks for removal, clean up after iteration

### 18. No color tint in shader
- Fragment shader only samples texture — can't tint, fade, or colorize sprites
- **Fix:** Add vertex color attribute to shader

### 19. GameObj missing common properties
- No `active: Bool`, `tag: String`, `layer: Int`
- **Fix:** Add these to GameObj or consider component system

### 20. No animation / sprite sheet support
- `textureID` is a single Int — no frame animation
- **Fix:** Add sprite sheet UV mapping and frame animation system

---

## LOW — Polish & Future

### 21. Particle system
- Two approaches: CPU-driven (sprites as particles) or GPU compute particles
- CPU approach can use existing renderer with many small GameObjs
- GPU approach needs compute shaders
- **Recommendation:** Start CPU-driven, add GPU particles later

### 22. Post-processing effects
- No off-screen render target support
- Can't do blur, color grading, screen shake effects
- **Fix:** Add render-to-texture capability

### 23. Texture atlas support
- Each sprite is a separate texture — wastes VRAM, causes extra binds
- **Fix:** Atlas packer + UV coordinate lookup

### 24. Math library additions
- Missing: `lerp()`, `smoothstep()`, easing functions
- Missing: random helpers (`randomFloat(min:max:)`)
- Missing: Bezier curves for path following
- Missing: `distance()` between two points as convenience

### 25. OBB (Oriented Bounding Box) collider
- For rotated rectangles — currently only axis-aligned
- Lower priority since most 2D games use AABB + circle

### 26. ECS (Entity Component System)
- Current class-based GameObj with inheritance doesn't scale
- ECS separates data (components) from logic (systems)
- **Big refactor** — consider for v2.0

### 27. SwiftUI overlay integration
- Wrap LiquidViewController in UIViewControllerRepresentable
- Allow SwiftUI HUD on top of Metal rendering
- See issue #5

### 28. macOS platform support
- ~4 files need `#if os(iOS)` / `#if os(macOS)` conditionals
- Need keyboard/mouse input handlers
- See issue #4

### 29. Game controller support (GCController)
- Zero integration currently
- Would need input abstraction layer

### 30. @unchecked Sendable on BufferProvider
- Not actually thread-safe — `availableIndex` has no locking
- Works because only accessed from MainActor, but semantically wrong
- **Fix:** Mark as `@MainActor` or add proper synchronization

---

## Test Coverage Gaps

### Currently tested (116 tests):
- GameMath (constants, clamp, wrap, range, float equal, power of two)
- SIMD float2/float3/float4 extensions
- SIMD float4x4 matrix operations
- All Intersect collision methods (32 tests)
- CircleCollider tracking
- Camera2D, WorldBounds, PerspectiveProjection
- Scheduler

### NOT tested:
- Rendering pipeline (buffer management, texture loading)
- Scene management (push/pop/set transitions, lifecycle)
- Input coordinate conversion (screen → world unprojection)
- Projection math (project/unproject round-trip)
- World bounds calculation accuracy
- GameObj defaults and behavior
- PointCollider
- Draw call limits (what happens at maxObjects)
- ScheduledTask edge cases (removal during iteration, cancellation)

---

## Summary by priority

| Priority | Items | Theme |
|----------|-------|-------|
| CRITICAL | 1-5 | Performance bugs, crashes, memory safety |
| HIGH | 6-11 | Essential features for real games |
| MEDIUM | 12-20 | Important quality improvements |
| LOW | 21-30 | Future features, polish |

## Next steps
- Convert these into GitHub issues in the Liquid Metal project
- Tackle CRITICAL items first (especially instanced rendering — huge win)
- Add tests for untested subsystems alongside fixes
