# LiquidMetal2D Library Audit v2

**Date:** 2026-03-16
**Scope:** Full top-to-bottom audit — rendering, engine, math, collisions, input, scheduling, tests, project config
**Source files reviewed:** 43 Swift files across 13 directories + Package.swift + shaders

---

## Executive Summary

LiquidMetal2D is a functional 2D game engine with clean protocol-driven architecture and solid math/collision foundations. The biggest issues fall into three categories:

1. **Rendering performance** — one draw call per object with no instancing or batching makes this engine O(N) draw calls for N sprites. At 4,500 sprites this is the primary bottleneck.
2. **Lifecycle/memory** — CADisplayLink is never invalidated, scenes hold strong references through the stack, scheduler tasks survive scene destruction, and NotificationCenter cleanup is incorrect.
3. **Robustness** — force unwraps in critical paths (SceneFactory, shader compilation, RenderPass creation), no bounds checking on buffer writes, and unsafe pointer arithmetic.

The math library and intersection tests are well-implemented with 116 passing tests. The overall architecture (protocol-driven, stack-based scenes, factory pattern) is sound and appropriate for a 2D engine.

---

## Table of Contents

- [1. Critical Issues](#1-critical-issues)
- [2. High Priority Issues](#2-high-priority-issues)
- [3. Medium Priority Issues](#3-medium-priority-issues)
- [4. Low Priority Issues](#4-low-priority-issues)
- [5. Rendering Pipeline Deep Dive](#5-rendering-pipeline-deep-dive)
- [6. Math & Collision Audit](#6-math--collision-audit)
- [7. Test Coverage Analysis](#7-test-coverage-analysis)
- [8. Project Configuration](#8-project-configuration)
- [9. Feature Gaps & Roadmap](#9-feature-gaps--roadmap)
- [10. Summary Table](#10-summary-table)

---

## 1. Critical Issues

These can cause crashes, memory leaks, or severe performance problems.

### 1.1 One Draw Call Per Object (Performance)

**File:** `renderers/DefaultRenderer.swift:172-182`

Every game object issues its own `drawPrimitives` call:

```swift
public func draw(uniforms: UniformData) {
    guard drawCount < maxObjects else { return }
    uniforms.setBuffer(buffer: worldBufferContents, offsetIndex: drawCount)
    renderPass.encoder.setVertexBufferOffset(offset, index: 2)
    renderPass.encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
    drawCount += 1
}
```

With 4,500 sprites, that's 4,500 draw calls per frame. Each has CPU encoding overhead and prevents the GPU from parallelizing work.

**Fix:** Use instanced rendering. Write all WorldUniforms to the buffer in one pass, then issue a single `drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: N)`. The vertex shader reads `[[instance_id]]` to index into the uniform buffer. For multiple textures, batch by texture ID and issue one draw call per unique texture.

### 1.2 CADisplayLink Never Invalidated (Memory Leak)

**Files:** `engines/DefaultEngine.swift:40-43`, `engines/GameEngine.swift`

```swift
public func run() {
    timer = CADisplayLink(target: self, selector: #selector(gameLoop(displayLink:)))
    timer.add(to: RunLoop.main, forMode: .default)
}
```

CADisplayLink retains its `target` (DefaultEngine). DefaultEngine holds `timer`. This creates a **retain cycle** that prevents either from being deallocated. There is no `stop()` method, no `timer.invalidate()` call, and `LiquidViewController.viewWillDisappear` does not stop the timer.

**Fix:** Add a `stop()` method to `GameEngine` that calls `timer.invalidate()`. Call it from `LiquidViewController.viewWillDisappear`. Consider using `[weak self]` pattern or a proxy target.

### 1.3 SceneFactory Force Unwrap Crash

**File:** `scenes/SceneFactory.swift:23-25`

```swift
public func get(_ type: SceneType) -> SceneBuilder {
    return builderMap[type.value]!
}
```

If a scene type isn't registered, this crashes at runtime during a scene transition — potentially deep into gameplay. No error message, no recovery.

**Fix:** Return `SceneBuilder?` with proper nil handling, or use `guard let` with a descriptive `fatalError` in debug builds and a fallback in release.

### 1.4 Unsafe Buffer Writes Without Bounds Checking

**Files:** `uniforms/WorldUniform.swift:18-23`, `uniforms/ProjectionUniform.swift:18-19`

```swift
public func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int) {
    memcpy(buffer + (offsetIndex * size), &transform, mtxSize)
    memcpy(buffer + (offsetIndex * size + mtxSize), &texTrans, texSize)
}
```

No validation that `offsetIndex * size` is within the allocated buffer. The only guard is `drawCount < maxObjects` in `DefaultRenderer.draw()`, which silently drops objects. If the sizes ever mismatch between the uniform and the buffer allocation, this causes memory corruption.

**Fix:** In debug builds, assert that the write offset + write size <= buffer length. Consider wrapping the raw pointer in a safer abstraction.

### 1.5 RenderPass fatalError on Dropped Frame

**File:** `dataTypes/RenderPass.swift:19-27`

```swift
guard let safeDrawable = layer.nextDrawable(),
    let safeBuffer = commandQueue.makeCommandBuffer(),
    ...
else {
    fatalError("Unable to start render pass")
}
```

`layer.nextDrawable()` returns `nil` when the app is backgrounded or the system is under memory pressure. This causes a guaranteed crash. This is especially likely on older devices.

**Fix:** Return an optional `RenderPass?` from the initializer (or use a factory method) and skip the frame in `DefaultRenderer.beginPass()` when the drawable is unavailable.

---

## 2. High Priority Issues

These affect correctness, resource management, or create significant tech debt.

### 2.1 Deprecated Metal Shader Types

**File:** `constants/constants.swift:15-17`

```glsl
struct VertIn {
    packed_float3 position;    // deprecated since Metal 2.1
    packed_float2 texCoord;    // deprecated since Metal 2.1
};
```

`packed_float` types are deprecated. Apple recommends `float3`/`float2` which have proper alignment. This may generate warnings or errors on future Metal versions.

**Fix:** Change to `float3` and `float2`. Adjust vertex buffer layout to account for the `float3` padding (16 bytes instead of 12). Update `createVertBuffer()` accordingly.

### 2.2 Force-Try in Shader and Pipeline Creation

**File:** `renderers/RenderCore.swift:94, 116`

```swift
let defaultLibrary = try! device.makeLibrary(source: ShaderSources.alphaBlendShader, options: nil)
// ...
return try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
```

If shader compilation fails (syntax error in the string literal, unsupported feature on older GPU), this crashes with no diagnostic info.

**Fix:** Use `do-catch` and propagate errors or log shader compilation errors before crashing.

### 2.3 Scheduler Mutation During Iteration

**File:** `scheduler/Scheduler.swift:30-51`

```swift
public func update(dt: Float) {
    for task in tasks {
        // ...
        if task.repeatCount == 0 {
            task.onComplete?()
            remove(toRemove: task)  // mutates tasks array during iteration!
        }
    }
}
```

`remove(toRemove:)` calls `tasks.removeAll(where:)` while iterating over `tasks`. Swift's COW semantics technically prevent a crash here (the `for` loop iterates over the snapshot), but `onComplete?()` could add new tasks, and subsequent iterations may skip or double-process tasks.

**Fix:** Collect completed tasks in a separate array, then remove them after the loop.

### 2.4 Scheduler Timer Drift

**File:** `scheduler/Scheduler.swift:38`

```swift
task.currentTime = 0  // discards overshoot
```

When a task fires, `currentTime` is reset to exactly `0`, discarding any overshoot. With `dt = 0.016` and `maxTime = 0.03`:
- Frame 1: `currentTime = 0.016` (no fire)
- Frame 2: `currentTime = 0.032` (fire, reset to 0, **0.002 lost**)

Over time this causes significant timing drift. A task that should fire every 30ms actually fires every 32ms — a 6.7% error.

**Fix:** Use `task.currentTime -= task.maxTime` instead of `= 0`. For tasks where dt >> maxTime, use a while loop to fire multiple times per frame.

### 2.5 NotificationCenter Observer Cleanup Bug

**File:** `viewControllers/LiquidViewController.swift:18-25, 44-46`

The observer is added using the **block-based API** (which returns a token), but the token is never stored:

```swift
// viewDidLoad — block-based, returns token (discarded)
NotificationCenter.default.addObserver(forName: ..., object: nil, queue: .main) { ... }

// viewWillDisappear — tries to remove self, but self was never the observer
NotificationCenter.default.removeObserver(self, name: ..., object: nil)
```

`removeObserver(self, ...)` is a no-op because `self` was never registered as the observer — the block-based API created a separate observer object. The closure is never removed.

**Fix:** Store the observer token returned by `addObserver(forName:...)` and call `NotificationCenter.default.removeObserver(token)` in `viewWillDisappear`.

### 2.6 Texture Pixel Format Mismatch

**Files:** `metalHelpers/Texture.swift:64`, `renderers/RenderCore.swift:48`

Textures are loaded as `.rgba8Unorm`:
```swift
let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: MTLPixelFormat.rgba8Unorm, ...)
```

But the render target is `.bgra8Unorm`:
```swift
layer.pixelFormat = .bgra8Unorm
```

Metal handles the cross-format sampling correctly, so this doesn't produce wrong colors. However, `.bgra8Unorm` is the **native format** on Apple GPUs. Using `.rgba8Unorm` for textures means every sample requires a channel swizzle, adding a small per-pixel cost.

**Fix:** Load textures as `.bgra8Unorm` and use `CGBitmapInfo.byteOrder32Little` with `CGImageAlphaInfo.premultipliedFirst` for the CGContext to produce BGRA data directly.

### 2.7 Scene Shutdown Is Incomplete

**File:** `scenes/Scene.swift:82`

```swift
public func shutdown() { objects.removeAll() }
```

Only clears the game objects array. Does NOT:
- Clear scheduled tasks (tasks with captured `self` will continue executing)
- Unload textures loaded by the scene
- Cancel pending operations

**Fix:** DefaultScene should own a `Scheduler` instance (or reference one) and call `scheduler.clear()` in `shutdown()`. Consider making texture loading/unloading per-scene.

### 2.8 `@available(iOS 13.0, *)` Annotations Are Stale

**Files:** `renderers/DefaultRenderer.swift:13`, `renderers/RenderCore.swift:13`, `dataTypes/RenderPass.swift:12`

The minimum deployment target is iOS 17, but several classes still carry `@available(iOS 13.0, *)` annotations. These are dead code.

**Fix:** Remove all `@available` annotations since iOS 17 is the minimum.

---

## 3. Medium Priority Issues

### 3.1 Directory Name Typos

Two directories have spelling errors:
- `behavoirs/` → should be `behaviors/`
- `extentions/` → should be `extensions/`

The `Behavoir` protocol and `NilBehavoir` class are also misspelled. This affects public API surface.

**Fix:** Rename directories and types. This is a breaking change for consumers.

### 3.2 Implicitly Unwrapped Optionals in Critical Paths

| Location | Property | Risk |
|----------|----------|------|
| `LiquidViewController.swift:13` | `gameEngine: GameEngine!` | Crash if viewDidLoad runs before engine is set |
| `DefaultEngine.swift:15` | `timer: CADisplayLink!` | Crash if accessed before `run()` |
| `DefaultRenderer.swift:18` | `renderPass: RenderPass!` | Crash if accessed outside begin/end |
| `DefaultScene.swift:24-26` | `sceneMgr!`, `renderer!`, `input!` | Crash if accessed before `initialize()` |
| `Behavoir.swift:9` | `current: State!` | Crash if accessed before `setStartState()` |

**Fix:** Use proper optionals with `guard let` or restructure initialization to avoid the two-phase init pattern.

### 3.3 Missing `@MainActor` Annotations

The following classes are used exclusively on the main thread but lack `@MainActor`:
- `DefaultEngine` (conforms to `@MainActor GameEngine` but not explicitly annotated)
- `Scheduler`
- `LiquidViewController`
- `SceneFactory`
- `BufferProvider`

**Fix:** Add `@MainActor` explicitly. Replace `@unchecked Sendable` on `BufferProvider` and `DefaultRenderer` with `@MainActor`.

### 3.4 WorldUniform Allocated Every Frame

**File:** `scenes/Scene.swift:50-51`

```swift
public func draw() {
    let worldUniforms = WorldUniform()  // allocates every frame
```

Creates a new heap-allocated class instance every frame. At 60fps that's 60 allocations/deallocations per second for no reason.

**Fix:** Make `worldUniforms` a stored property on `DefaultScene`, reuse it across frames.

### 3.5 No Texture Batching

**File:** `scenes/Scene.swift:56-68`

Objects are drawn in array order. If objects `[A(tex1), B(tex2), C(tex1)]` are drawn, texture 1 is bound, then texture 2, then texture 1 again — 3 texture binds for 2 textures.

**Fix:** Sort objects by `textureID` before drawing, or maintain pre-sorted draw lists. This reduces texture state changes from O(N) to O(unique textures).

### 3.6 Single-Touch Input Only

**Files:** `viewControllers/LiquidViewController.swift:49-71`, `engines/DefaultEngine.swift:13`

```swift
private var touchLocation: simd_float2?  // single touch only
```

Only tracks one touch. Multi-touch is ignored (only `touches.first` is used). For a 2D game engine this is limiting.

**Fix:** Track a `Set<UITouch>` or array of touch positions. Add multi-touch support to `InputReader`/`InputWriter`.

### 3.7 Viewport Calculated But Never Set

**File:** `renderers/RenderCore.swift:27, 65-68`

```swift
var viewPort: [Int32] = [0, 0, 0, 0]  // updated on resize...

// ...but never applied to encoder
```

The viewport is recalculated every resize but never passed to `renderPass.encoder.setViewport()`. Currently works by accident (Metal defaults to drawable size), but will break if the drawable and view sizes ever diverge.

**Fix:** Apply viewport in `DefaultRenderer.beginPass()`.

### 3.8 Semaphore Blocks Main Thread

**File:** `renderers/DefaultRenderer.swift:150-151`

```swift
projectionBufferProvider.wait()  // blocks main thread!
worldBufferProvider.wait()
```

The semaphore wait uses `DispatchTime.distantFuture`. If the GPU is behind, this blocks the main thread indefinitely. UI events, system callbacks, and touch input all freeze.

**Fix:** Use a timeout (e.g., 16ms). If the wait times out, skip the frame. Or move to Metal's `addScheduledHandler` for non-blocking synchronization.

### 3.9 `unowned` References on Colliders

**Files:** `colliders/CircleCollider.swift:11`, `colliders/PointCollider.swift:11`

```swift
private unowned let obj: GameObj
```

If the `GameObj` is deallocated while the collider still exists, accessing `obj.position` crashes immediately. Unlike `weak`, `unowned` provides no nil safety.

**Fix:** Use `weak` if the lifetime isn't guaranteed, or document and enforce that colliders must not outlive their GameObj.

### 3.10 Delta Time Handling

**File:** `engines/DefaultEngine.swift:46-50`

```swift
let dt: Float = Float(displayLink.timestamp - lastFrameTime)
guard dt < 5 else { return }
```

Issues:
- First frame: `lastFrameTime` is set to `timer.timestamp` at `run()` time, but the first `gameLoop` callback may fire much later, causing a large initial dt
- After app backgrounding/foregrounding, dt can be several seconds
- Negative dt is theoretically possible (not guarded)
- The 5-second threshold is arbitrary and doesn't cap dt to a usable value

**Fix:** Cap dt to a reasonable maximum (e.g., 1/15th second = 0.067). Reset `lastFrameTime` when resuming from background. Guard against `dt <= 0`.

---

## 4. Low Priority Issues

### 4.1 Dead Code

| Location | Code | Issue |
|----------|------|-------|
| `LiquidViewController.swift:35-37` | `didRotate(_:)` | Never called — no observer wired to it |
| `renderers/DefaultRenderer.swift:141-142` | `useOrthographic()` | Empty stub, protocol requires it |
| `renderers/RenderCore.swift:154-166` | `getUnprojectRay(...)` | Duplicate of same method on DefaultRenderer |
| `metalHelpers/Debug.swift:12-18` | `DebugPrint`, `DebugRun` | Appear unused across the codebase |
| `extentions/Bool+.swift:9-11` | `Bool.toInt()` | Appears unused |

### 4.2 Print Statement in Production

**File:** `metalHelpers/Texture.swift:88`

```swift
print("Loaded Texture \(fileName)")
```

Should use `DebugPrint` or `#if DEBUG` guard.

### 4.3 `nonisolated(unsafe)` Static Counter

**File:** `metalHelpers/Texture.swift:13`

```swift
nonisolated(unsafe) private static var sIdCounter = 0
```

Works because texture loading only happens on the main thread, but the annotation is semantically misleading. Should use `@MainActor` instead.

### 4.4 File Header Comments Don't Match Filenames

Several files have generic `// File.swift` headers instead of their actual names:
- `constants/constants.swift` → "File.swift"
- `scheduler/Scheduler.swift` → "File.swift"
- `scenes/SceneFactory.swift` → "File.swift"
- `colliders/Collider.swift` → "File.swift"
- `colliders/PointCollider.swift` → "File.swift"
- `colliders/CircleCollider.swift` → "File.swift"
- `behavoirs/Behavoir.swift` → "Behavoir.swift" (typo)

### 4.5 WorldBounds Parameter Order

**File:** `dataTypes/WorldBounds.swift:14`

```swift
public init(maxX: Float, minX: Float, maxY: Float, minY: Float)
```

Parameters alternate max/min in a non-intuitive order. Standard convention is `(minX, maxX, minY, maxY)` or `(minX, minY, maxX, maxY)`. No validation that min <= max.

### 4.6 SceneType Is Just an Int Wrapper

**File:** `scenes/SceneType.swift:11-13`

```swift
public protocol SceneType {
    var value: Int { get }
}
```

Scenes are identified by raw `Int` values compared with `==`. This is fragile — typos in scene type registration go undetected until that scene is requested at runtime. Could use `Hashable` directly.

---

## 5. Rendering Pipeline Deep Dive

### Architecture Overview

```
LiquidViewController
  └─ DefaultEngine (game loop via CADisplayLink)
       └─ DefaultRenderer
            └─ RenderCore (device, layer, pipeline state, textures)
                 └─ BufferProvider (triple-buffered uniforms)
```

### Buffer Layout

**Vertex Buffer** (static, created once):
```
4 vertices × 5 floats each = 80 bytes
Layout per vertex: [x, y, z, u, v] — 20 bytes (packed_float3 + packed_float2)
```

**Projection Buffer** (1 per frame, triple-buffered):
```
1 × simd_float4x4 = 64 bytes
Contains: projectionMatrix × viewMatrix
```

**World Buffer** (N per frame, triple-buffered):
```
maxObjects × 80 bytes (simd_float4x4 + simd_float4)
Contains: per-object transform matrix + texture transform
```

### Triple Buffering Assessment

The implementation is **correct**:
- 3 buffers per BufferProvider, cycled via round-robin index
- DispatchSemaphore prevents CPU from writing to a buffer the GPU is still reading
- `addCompletedHandler` signals the semaphore when the GPU finishes

**Issue:** The semaphore wait on the main thread (`distantFuture` timeout) can freeze the UI if the GPU falls behind. See issue 3.8.

### Per-Frame Flow

1. `beginPass()`: wait on semaphores, get next buffers, create RenderPass (fatalError if no drawable), set pipeline state
2. `usePerspective()`: write projection × view matrix to projection buffer
3. For each object: `useTexture()` + `draw()` (write world uniform, set offset, issue draw call)
4. `endPass()`: end encoding, present drawable, commit command buffer

### What's Missing

- **No instanced rendering** — most impactful improvement possible
- **No depth buffer** — z-ordering relies on draw order only
- **No orthographic projection** — `useOrthographic()` is an empty stub
- **No render state caching** — pipeline state, vertex buffer, and sampler are re-bound every frame even though they never change
- **No texture atlas support** — each sprite is a separate texture, requiring a texture bind per object (partially mitigated by the texture coordinate transform in the shader)

---

## 6. Math & Collision Audit

### GameMath (math/Math.swift)

**Verdict: Well-implemented, no bugs found.**

- `epsilon` (0.00001) is appropriate for game-scale floating point
- `clamp`, `wrap`, `wrapEdge`, `isInRange` all handle edge cases correctly
- `wrap` uses `truncatingRemainder` (correct for negative values)
- `nextPowerOfTwo` uses standard bit-twiddling (correct for positive integers, documented behavior for powers of two)

### Intersection Tests (math/Intersect.swift)

**Overall: Solid implementations with one edge case concern.**

| Test | Correct? | Notes |
|------|----------|-------|
| `pointCircle` | Yes | Uses squared distance comparison, epsilon tolerance |
| `pointAABB` | Yes | Translates to AABB-local space, inclusive boundary |
| `pointLineSegment` | Yes | Cross product for collinearity, projected length for range |
| `circleCircle` | Yes | Sum of radii vs distance, squared comparison |
| `circleAABB` | Yes | Clamp-to-rect approach, handles interior case |
| `circleLineSegment` | Yes | Projection + Pythagorean theorem |
| `aabbAABB` | Yes | Minkowski sum reduction to pointAABB |

**Edge case:** `circleLineSegment` — when the circle completely contains the line segment, the function still returns `true` (correct). When the circle radius is 0, it reduces to a point-line test (correct).

**Potential concern with `pointCircle`:** Uses `< epsilon` instead of `<= epsilon`. This means a point exactly on the circle boundary may not register as a collision in extreme edge cases. In practice, this is fine for gameplay.

### SIMD Extensions

Reviewed `simd_float2+.swift`, `simd_float3+.swift`, `simd_float4+.swift`, `simd_float4x4+.swift`. All standard operations (length, normalize, cross, dot, matrix transforms) delegate to Apple's `simd` library. No bugs found.

### Collision System Architecture

**Strengths:**
- Visitor pattern via `Collider` protocol dispatches to the correct test method
- `NilCollider` provides null-object pattern
- CircleCollider bridges between `GameObj.position` and `Circle` protocol

**Weaknesses:**
- No `AABBCollider` class (only raw `Intersect.aabbAABB` function exists)
- No collision response / callbacks / event system
- No spatial partitioning (brute-force O(N^2) all-pairs)
- `unowned` references on colliders are crash-prone (see 3.9)

---

## 7. Test Coverage Analysis

### Current State: 116 tests across 2 files

| Test Class | Count | Coverage Area |
|------------|-------|--------------|
| MathUtilityTests | 33 | Constants, conversions, clamp, wrap, range, float equality, powers of two |
| SimdFloat2ExtensionTests | 13 | angle, length, normalize, cross, UV aliases, conversions |
| SimdFloat3ExtensionTests | 9 | swizzles, length, normalize, RGB, conversions |
| SimdFloat4ExtensionTests | 13 | swizzles, RGBA, texture transform aliases, set methods |
| SimdFloat4x4ExtensionTests | 11 | zero, diagonal, scale, translate, rotate, transform, lookAt |
| IntersectTests | 32 | All 7 intersection functions with edge cases |
| CircleColliderTests | 3 | Position tracking, center setter, radius |
| LiquidMetal2DTests | 5 | GameObj/Camera2D/WorldBounds/PerspectiveProjection defaults, Scheduler basic |

### NOT Tested (Gaps)

**Rendering (0% coverage):**
- BufferProvider cycling and semaphore behavior
- Texture loading, caching, unloading, reference counting
- RenderPass creation and lifecycle
- Uniform packing and buffer layout
- Draw call encoding

**Engine & Scene Management (0% coverage):**
- Game loop delta time calculation
- Scene push/pop/set transitions
- SceneFactory registration and retrieval
- Scene lifecycle: initialize → update → draw → shutdown → resume
- Scene stack behavior

**Input System (0% coverage):**
- Touch coordinate conversion
- Screen-to-world unprojection
- World bounds calculation from camera

**Scheduler (minimal coverage):**
- Timer drift / accumulation behavior
- Task removal during update
- Completion callbacks
- Edge cases: 0-time tasks, negative dt, INFINITE repeat

**Colliders (minimal coverage):**
- PointCollider not tested at all
- AABBCollider doesn't exist as a class
- No lifecycle / ownership tests

### Recommendations

Priority test additions:
1. **Scheduler edge cases** — drift, mutation during iteration, completion callbacks
2. **Scene transitions** — push/pop/set lifecycle, stack integrity
3. **Unprojection round-trip** — project → unproject should return original point
4. **SceneFactory** — missing scene type handling
5. **WorldBounds** — validation, edge cases

---

## 8. Project Configuration

### Package.swift

- **Swift Tools:** 6.0 ✓
- **Platforms:** iOS 17+, macOS 14+ ✓
- **Dependencies:** SwiftLint 0.63.2 (build plugin) ✓
- **Note:** CLAUDE.md references MetalMath as a dependency, but the math code has been migrated into the project. CLAUDE.md should be updated to reflect this.

### Platform Target

iOS 17 is reasonable but could be bumped to iOS 18 given the engine is in active development and iOS 18 is the current release. The `@available(iOS 13.0, *)` annotations on 3 classes should be removed since they're below the deployment target.

### SwiftLint

Configuration at `.swiftlint.yml` is minimal but functional:
- `line_length`: 120 warning / 200 error
- `force_try`: warning (should probably be error)
- `identifier_name`: min 1 char

Missing rules worth adding: `cyclomatic_complexity`, `nesting`, `large_tuple`.

### CI/CD

**None configured.** No GitHub Actions, no automated builds or tests.

**Recommendation:** Add a workflow for:
- Build on iOS Simulator
- Run tests
- SwiftLint validation

---

## 9. Feature Gaps & Roadmap

These are missing features and architectural improvements identified by cross-referencing with the original library audit. They're separate from bugs — these are things the engine doesn't do yet but should.

### Rendering & Shaders

#### 9.1 Shader as Embedded String → .metal File

**File:** `constants/constants.swift`

The shader is a Swift string literal. No compile-time validation, no Xcode syntax highlighting, no Metal compiler diagnostics until runtime. Moving to a `.metal` file requires a bundling strategy for SPM (resource bundles or embedding).

#### 9.2 No Color Tint / Fade in Shader

The fragment shader only samples the texture — no way to tint, fade, flash white (hit effect), or colorize sprites. Standard 2D engines pass a per-instance vertex color that multiplies the texture sample.

**Fix:** Add a `color` field to `WorldUniform`, multiply in fragment shader: `return tex.sample(...) * world.color;`

#### 9.3 Texture Atlas Support

Each sprite is a separate texture, wasting VRAM and causing extra binds. Atlas packing (multiple sprites in one texture, addressed by UV region) is the standard approach. The `texTrans` UV transform in the shader already supports this — just needs tooling and a lookup system.

#### 9.4 Post-Processing / Render-to-Texture

No off-screen render target support. Can't do blur, color grading, screen shake, or full-screen effects. Would require rendering to an intermediate texture, then drawing that texture to screen with a post-process shader.

#### 9.5 Particle System

No particle support. Two paths:
- **CPU-driven:** Use existing renderer with many small DrawCommands (easier, sufficient for 2D)
- **GPU compute:** Metal compute shaders for particle simulation (better for 10K+ particles)

Recommend starting CPU-driven since the deferred draw submission architecture (issue #13) naturally supports it.

### Collision & Physics

#### 9.6 Missing AABBCollider Class

AABB intersection tests exist in `Intersect` but there's no `AABBCollider` class to use with the `Collider` protocol. Games need rectangle collisions constantly.

**Fix:** Create `AABBCollider: Collider` following the `CircleCollider` pattern, with `width`/`height` properties backed by a `GameObj`.

#### 9.7 Broadphase Collision Detection

Currently O(N²) — every object checked against every other. At 1,000 objects that's 1,000,000 checks per frame.

**Fix:** Implement spatial partitioning. A uniform grid is simplest for 2D and pairs well with the existing `WorldBounds`. Quadtree is an option if object density varies widely.

#### 9.8 Collision Callbacks / Events

No `onCollisionEnter`/`onCollisionStay`/`onCollisionExit` pattern. Games must manually track collision state frame-to-frame.

**Fix:** Add a collision event system that tracks previous-frame collision pairs and fires enter/stay/exit callbacks.

#### 9.9 Collision Groups / Layers

No way to filter which objects collide with which. Every collider tests against every other.

**Fix:** Add a layer bitmask to `Collider`. Two objects only test collision if `(a.mask & b.layer) != 0`.

#### 9.10 OBB (Oriented Bounding Box) Collider

Only axis-aligned collision. Rotated rectangles require OBB tests (separating axis theorem). Lower priority since most 2D games use AABB + circle, but needed for games with rotated obstacles.

### Game Objects & Behavior

#### 9.11 GameObj Missing Common Properties

No `active: Bool` (skip update/draw), no `tag: String` (identification), no `layer: Int` (collision/render grouping). These are standard in game engines.

#### 9.12 Sprite Sheet / Animation System

`textureID` is a single `Int` — no built-in frame animation. The `texTrans` UV transform supports sprite sheets at the rendering level, but there's no animation controller to advance frames, set playback speed, loop, or trigger callbacks on specific frames.

#### 9.13 State Machine Hierarchy

`Behavoir` only supports one state at a time. Can't do nested/hierarchical states (e.g., "Moving" with sub-states "Walking"/"Running"). No state transition guards.

### Scheduler

#### 9.14 Scheduler Pause/Resume

Can't pause individual tasks or the whole scheduler. Useful for pause menus, cutscenes, slow-motion.

**Fix:** Add `isPaused` flag to `ScheduledTask` and `Scheduler`.

### Platform & Integration

#### 9.15 macOS Platform Support

~4 files need `#if os(iOS)` / `#if os(macOS)` conditionals. Would need `NSView`/`NSViewController` equivalents and keyboard/mouse input handlers.

#### 9.16 SwiftUI Overlay Integration

Wrap `LiquidViewController` in `UIViewControllerRepresentable` to allow SwiftUI HUD/UI on top of Metal rendering.

#### 9.17 Game Controller Support (GCController)

Zero gamepad integration. Would need an input abstraction layer that unifies touch, keyboard, and controller input.

### Math Library Additions

#### 9.18 Missing Math Utilities

- `lerp(a, b, t)` — linear interpolation
- `smoothstep(edge0, edge1, x)` — smooth Hermite interpolation
- Easing functions (ease-in, ease-out, ease-in-out variants)
- `randomFloat(min:max:)` — convenience random in range
- Bezier curves — for path following and animation curves
- `distance(a, b)` — convenience wrapper around `simd_length(a - b)`

### Architecture

#### 9.19 ECS (Entity Component System)

Current class-based `GameObj` with inheritance doesn't scale well for complex games. ECS separates data (components) from logic (systems), enabling better composition and cache performance. This would be a major architectural shift — consider for a v2.0 if the engine outgrows the current pattern.

---

## 10. Summary Table

### By Severity

| # | Issue | File(s) | Severity | Category |
|---|-------|---------|----------|----------|
| 1.1 | One draw call per object | DefaultRenderer.swift:172-182 | **CRITICAL** | Performance |
| 1.2 | CADisplayLink never invalidated | DefaultEngine.swift:40-43 | **CRITICAL** | Memory Leak |
| 1.3 | SceneFactory force unwrap | SceneFactory.swift:24 | **CRITICAL** | Crash Risk |
| 1.4 | Unsafe buffer writes, no bounds check | WorldUniform.swift:18-23 | **CRITICAL** | Memory Safety |
| 1.5 | RenderPass fatalError on dropped frame | RenderPass.swift:26 | **CRITICAL** | Crash Risk |
| 2.1 | Deprecated packed_float in shader | constants.swift:16-17 | **HIGH** | Compatibility |
| 2.2 | Force-try in shader compilation | RenderCore.swift:94, 116 | **HIGH** | Error Handling |
| 2.3 | Scheduler mutation during iteration | Scheduler.swift:49 | **HIGH** | Correctness |
| 2.4 | Scheduler timer drift | Scheduler.swift:38 | **HIGH** | Correctness |
| 2.5 | NotificationCenter cleanup bug | LiquidViewController.swift:18-46 | **HIGH** | Memory Leak |
| 2.6 | Texture pixel format mismatch | Texture.swift:64 | **HIGH** | Performance |
| 2.7 | Scene shutdown incomplete | Scene.swift:82 | **HIGH** | Memory Leak |
| 2.8 | Stale @available annotations | Multiple | **HIGH** | Code Quality |
| 3.1 | Directory name typos | behavoirs/, extentions/ | **MEDIUM** | API/Naming |
| 3.2 | Implicitly unwrapped optionals | Multiple (6 files) | **MEDIUM** | Crash Risk |
| 3.3 | Missing @MainActor annotations | Multiple (5 classes) | **MEDIUM** | Swift 6 |
| 3.4 | WorldUniform allocated every frame | Scene.swift:51 | **MEDIUM** | Performance |
| 3.5 | No texture batching | Scene.swift:56-68 | **MEDIUM** | Performance |
| 3.6 | Single-touch input only | DefaultEngine.swift:13 | **MEDIUM** | Limitation |
| 3.7 | Viewport calculated but never set | RenderCore.swift:27, 65-68 | **MEDIUM** | Correctness |
| 3.8 | Semaphore blocks main thread | DefaultRenderer.swift:150-151 | **MEDIUM** | UX/Freeze |
| 3.9 | unowned references on colliders | CircleCollider.swift:11 | **MEDIUM** | Crash Risk |
| 3.10 | Delta time handling edge cases | DefaultEngine.swift:46-50 | **MEDIUM** | Correctness |
| 4.1 | Dead code (5 instances) | Multiple | **LOW** | Cleanup |
| 4.2 | Print in production code | Texture.swift:88 | **LOW** | Code Quality |
| 4.3 | nonisolated(unsafe) static counter | Texture.swift:13 | **LOW** | Swift 6 |
| 4.4 | Wrong file header comments | 7 files | **LOW** | Code Quality |
| 4.5 | WorldBounds parameter order | WorldBounds.swift:14 | **LOW** | API Design |
| 4.6 | SceneType is raw Int wrapper | SceneType.swift:11-13 | **LOW** | Type Safety |

### Recommended Fix Order

**Phase 1 — Safety & Stability:**
1. Fix RenderPass crash on missing drawable (1.5)
2. Fix SceneFactory force unwrap (1.3)
3. Add CADisplayLink invalidation (1.2)
4. Fix NotificationCenter cleanup (2.5)
5. Fix scheduler mutation during iteration (2.3)
6. Fix scheduler timer drift (2.4)
7. Fix delta time capping (3.10)

**Phase 2 — Performance (Rendering Overhaul):**
8. Implement deferred draw submission + instanced rendering (1.1, see issue #13)
9. Texture batching/sorting — automatic via deferred draw (3.5)
10. Move WorldUniform to stored property (3.4)
11. Fix texture pixel format (2.6)
12. Add color tint to shader (9.2)

**Phase 3 — Modernization & Cleanup:**
13. Remove stale `@available` annotations (2.8)
14. Add `@MainActor` everywhere needed (3.3)
15. Fix directory/type name typos (3.1)
16. Replace `!` with proper optionals (3.2)
17. Update deprecated shader types (2.1)
18. Move shader to .metal file (9.1)

**Phase 4 — Collision System:**
19. Create AABBCollider class (9.6)
20. Add collision callbacks (9.8)
21. Add collision groups / layer bitmask (9.9)
22. Broadphase spatial partitioning (9.7)

**Phase 5 — Game Features:**
23. Sprite sheet / animation system (9.12)
24. Scheduler pause/resume (9.14)
25. GameObj active/tag/layer properties (9.11)
26. Math library additions — lerp, smoothstep, easing, random (9.18)
27. Texture atlas tooling (9.3)

**Phase 6 — Tests & Infrastructure:**
28. Add scheduler edge case tests
29. Add scene transition tests
30. Add unprojection round-trip tests
31. Set up CI/CD pipeline

**Phase 7 — Future / v2.0:**
32. Particle system (9.5)
33. Post-processing / render-to-texture (9.4)
34. macOS platform support (9.15)
35. SwiftUI overlay (9.16)
36. Game controller support (9.17)
37. OBB collider (9.10)
38. State machine hierarchy (9.13)
39. ECS architecture (9.19)
