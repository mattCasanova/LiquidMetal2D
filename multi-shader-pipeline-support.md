# Multi-Shader Pipeline Support

Goal: decouple the render pipeline from the single `AlphaBlendPipeline` so a scene
can use multiple shaders in one pass (e.g. alpha-blend textures for sprites,
solid-color wireframe for debug overlay). Keep `DefaultRenderer`'s default
behavior identical for simple games; move alpha-blend specifics into a reusable
`Shader` abstraction, and move per-object shader state (textureID, tint, etc.)
out of `GameObj` and into **render components** so one GameObj can participate
in multiple shaders without duplication.

## Checklist

- [x] 1. Introduce `Shader` protocol + per-shader ownership of pipeline, uniforms, buffer, batches
- [x] 2. Strip AlphaBlend specifics out of `RenderPass` (delete `AlphaBlendRenderPass`)
- [x] 3. Introduce `AlphaBlendComponent`; move `textureID`/`tintColor`/`texTrans` off `GameObj`; remove `GameObj.toUniform()`; mark `GameObj` as `final`
- [x] 4. Build `AlphaBlendShader` as the first conforming Shader (holds pipeline, BufferProvider, TextureBatch)
- [x] 5. Refactor `DefaultRenderer` to own shaders and flush-on-switch via `useShader(_:)`
- [x] 6. Update `Renderer` protocol surface
- [x] 7. Migrate all affected `LiquidMetal2D-Demo` scenes to `AlphaBlendComponent` (SpawnDemo, CollisionStressDemo, AsyncLoadDemo, CollisionDemo, SchedulerDemo, TouchZoomDemo, CameraRotationDemo, BezierDemo, InstanceDemo)
- [x] 8. Update/port tests; run full xcodebuild test (290 tests pass)
- [x] 9. Update `CLAUDE.md` rendering pipeline section

_Demo runtime verification pending dep-switch to new engine version._

---

## Current coupling (what to fix)

- `DefaultRenderer.swift:16` — `renderPass: AlphaBlendRenderPass!` is typed to the concrete subclass
- `DefaultRenderer.swift:25-26` — single `pipelineState` + `vertexBuffer` baked into the renderer
- `DefaultRenderer.swift:32-33` — `worldBufferProvider` sized once at init for one uniform stride
- `DefaultRenderer.swift:42` — `AlphaBlendPipeline.create(...)` called directly in init
- `DefaultRenderer.swift:179-199` — `submit(objects:)` calls `obj.toUniform()` which returns `AlphaBlendUniform`; batching is `TextureBatch`
- `DefaultRenderer.swift:236-259` — `beginPass` constructs `AlphaBlendRenderPass` and wires its specific setup API
- `AlphaBlendRenderPass.swift:35` — `batch.startIndex * AlphaBlendUniform.typeSize()` hardcodes the uniform stride in the pass
- `GameObj.swift:15, 17` — `textureID` and `tintColor` live on the base class, meaning every GameObj carries alpha-blend-specific state whether it uses that shader or not
- `GameObj.swift:51-58` — `toUniform()` is hardcoded to AlphaBlendUniform — can't produce other uniform types without subclassing, and subclassing a GameObj to pick a shader is the wrong axis

## Target architecture

### Component-driven render state

The engine already has a first-class component system — `Component` protocol with
`ObjectIdentifier`-based O(1) lookup (`GameObj.swift:19-46`), and the demo's
`CollisionDemo.swift:172-179` shows the pattern: one ship has Behavior +
Collider + game-state components. Render state is a natural fit for the same
pattern.

- **`GameObj`** (base): only transform/lifecycle — `position`, `velocity`, `scale`, `rotation`, `zOrder`, `isActive`, `components`. **No** `textureID`, `tintColor`, `toUniform()`.
- **`AlphaBlendComponent: Component`**: holds `textureID`, `tintColor`, `texTrans`. Knows how to produce an `AlphaBlendUniform` from its parent's transform + its own fields.
- **Future `WireframeComponent: Component`**: would hold color/thickness and produce a wireframe uniform.
- A single GameObj can carry **both** components → rendered by both shaders in one frame, no duplicate objects.

Render components do **not** override `Component.id` (unlike `Behavior`/`Collider`
which share a slot across subtypes). Each render component type gets its own
slot so they can coexist on the same GameObj.

Each shader's `submit` takes `[GameObj]` and filters by component:

```swift
func submit(objects: [GameObj]) {
    for obj in objects where obj.isActive {
        guard let comp = obj.get(AlphaBlendComponent.self) else { continue }
        // ... build uniform from (obj.transform, comp.fields), batch by comp.textureID
    }
}
```

O(N) walk × O(1) component lookup = O(N) per shader per frame. At 4000 objects
× 2 shaders that's 8000 dict lookups/frame — negligible.

### Layer 1: `RenderPass` (pure pass, no shader knowledge)

`RenderPass.swift` is already close to generic. After this refactor:

- Owns `commandBuffer`, `drawable`, `encoder`, `renderCore`
- Exposes `encoder`, `end()`, `addCompletedHandler(_:)`
- **No** `setup(pipelineState:vertexBuffer:samplerState:worldBuffer:)` — that belongs to a shader
- **No** `setProjection(buffer:)` — the shader knows its own projection binding index
- **No** `drawBatches(_:)` — batch type is shader-specific

Delete `AlphaBlendRenderPass.swift` — everything it does moves into `AlphaBlendShader`.

### Layer 2: `Shader` protocol

A shader encapsulates pipeline state + uniform format + per-frame GPU buffer + batching strategy. Each shader owns its own `BufferProvider` sized to its uniform × its `maxObjects`.

```swift
@MainActor
public protocol Shader: AnyObject {
    var maxObjects: Int { get }

    /// Called at beginPass. Acquire a buffer from the provider, reset batches.
    /// Returns false if the semaphore timed out (frame should bail).
    func beginFrame() -> Bool

    /// Bind pipeline + per-shader resources onto the encoder.
    /// Also re-bind projection buffer (shader owns its binding index).
    func bind(pass: RenderPass, projectionBuffer: MTLBuffer)

    /// Walk [GameObj], filter by this shader's matching Component, build
    /// uniforms, accumulate batches. Each shader handles its own sort/batching.
    func submit(objects: [GameObj])

    /// Flush any accumulated batches to the encoder. Called on shader switch
    /// and at endPass. Safe to call multiple times (drains batch list).
    func flush(pass: RenderPass)

    /// Called after command buffer commits (completed handler) to signal the
    /// shader's semaphore. Nonisolated so it can run on any thread.
    func signalFrameComplete()
}
```

`submit` on the protocol makes `renderer.submit(objects:)` a clean pass-through
to `currentShader.submit(...)` — same user-facing API as today, just routed
through the active shader. Simple games don't notice the indirection.

**Advanced draw paths stay on concrete shaders** (not in the protocol) because
they're type-specific. For `AlphaBlendShader`:

- `draw(transform: Mat4, texTrans: Vec4, color: Vec4, textureId: Int)` — manual single-draw, no sort

### Layer 3: `AlphaBlendShader` (first implementation)

Contains everything that was AlphaBlend-specific:

- `MTLRenderPipelineState` (from `AlphaBlendPipeline.create`)
- `MTLBuffer` quad vertex buffer (moves off `DefaultRenderer`, stays created via `RenderCore.createQuad`)
- `MTLSamplerState`
- `BufferProvider` for world uniforms sized `AlphaBlendUniform.typeSize() * maxObjects`
- `worldBufferContents` pointer + `drawCount`
- `TextureBatch` array + `currentTextureId`
- `submit(objects:)` logic (component filter + sort + uniform build + batching)
- `draw(...)` advanced-path logic
- `flush(pass:)` walks batches and emits `drawPrimitives` instanced calls — replaces `AlphaBlendRenderPass.drawBatches`

`TextureBatch` becomes an internal type of `AlphaBlendShader`.

### Layer 4: `AlphaBlendComponent`

```swift
public final class AlphaBlendComponent: Component {
    public unowned var parent: GameObj
    public var textureID: Int
    public var tintColor: Vec4
    public var texTrans: Vec4    // (scaleU, scaleV, offsetU, offsetV)

    public init(parent: GameObj, textureID: Int,
                tintColor: Vec4 = Vec4(1, 1, 1, 1),
                texTrans: Vec4 = Vec4(1, 1, 0, 0)) { ... }

    /// Builds the uniform from parent transform + component fields.
    /// Called by AlphaBlendShader.submit.
    func fillUniform(_ u: AlphaBlendUniform) {
        u.transform.setToTransform2D(
            scale: parent.scale, angle: parent.rotation,
            translate: Vec3(parent.position, parent.zOrder))
        u.texTrans = texTrans
        u.color = tintColor
    }
}
```

Default `id` is `ObjectIdentifier(AlphaBlendComponent.self)` — own slot, can coexist with other render components.

### Layer 5: `DefaultRenderer`

Owns the default alpha-blend shader and tracks the currently-bound shader:

```swift
public let alphaBlend: AlphaBlendShader       // exposed for scenes to submit to
private var currentShader: Shader?            // for flush-on-switch
private let projectionBufferProvider: BufferProvider
private var projectionBuffer: MTLBuffer!
```

New pass flow:

```swift
renderer.beginPass()                 // acquires encoder + projection buffer; calls beginFrame() on registered shaders
renderer.usePerspective()            // writes projection uniform (pass-scoped)
renderer.useShader(alphaBlend)       // flushes previous (if any); binds alphaBlend pipeline/buffer/projection
alphaBlend.submit(objects: allObjs)  // filters by AlphaBlendComponent, builds uniforms, batches

if debugEnabled {
    renderer.useShader(wireframe)    // flushes alphaBlend batches, binds wireframe
    wireframe.submit(objects: allObjs) // filters by WireframeComponent
}

renderer.endPass()                   // flushes current shader, ends encoder, presents
```

**Projection ordering:** projection is pass-scoped, not shader-scoped. `usePerspective`/`useOrthographic` write into `projectionBuffer`. Each `useShader` re-binds that buffer (the shader knows its own vertex index). Order-independent within a pass.

### `Renderer` protocol changes

Remove:
- `submit(objects:)` — moved to each shader (or kept as convenience forward to `alphaBlend`, see decision below)
- `draw(uniforms:)` and `useTexture(_:)` — were AlphaBlend-specific pretending to be generic; callers use the concrete shader

Add:
- `useShader(_ shader: Shader)`

Keep:
- `beginPass() -> Bool`, `usePerspective()`, `useOrthographic()`, `endPass()`
- Projection/camera/unproject/bounds methods — unchanged
- Texture loading/unloading — unchanged

**Decision: keep `submit(objects:)` on `Renderer`?** Recommendation: **yes**, as a convenience that auto-binds the alpha-blend shader if nothing is bound, then forwards to `alphaBlend.submit`. Rationale: simple games that never touch shaders directly should see no API change. Advanced games use `useShader` + shader-specific submit.

### `RenderCore`

Unchanged. `createQuad()` stays (AlphaBlendShader uses it in its init). `createDefaultSampler()` stays.

### `BufferProvider`

No changes — already generic. One per shader instead of one per renderer.

---

## Migration / compat

### Breaking: `GameObj` field removal

`GameObj.textureID` and `GameObj.tintColor` go away. Consumers must migrate:

```swift
// Before
let ship = GameObj()
ship.textureID = shipTextureID
ship.tintColor = Vec4(1, 0, 0, 1)

// After
let ship = GameObj()
ship.add(AlphaBlendComponent(parent: ship, textureID: shipTextureID,
                             tintColor: Vec4(1, 0, 0, 1)))
```

Known consumers to update in this PR:
- `LiquidMetal2D-Demo` — CollisionDemo and any other scenes that set `textureID`/`tintColor` directly.

Matt's other game projects (Shmupper, Crunch, etc. per memory) will need the same migration in follow-up work — flagged but not blocking this PR.

### Breaking: advanced draw path

`renderer.useTexture(...)` and `renderer.draw(uniforms:)` go away. Equivalent:
`renderer.alphaBlend.draw(transform:texTrans:color:textureId:)` — one-shot call
that carries its own texture, no separate `useTexture` step.

### Non-breaking: `submit(objects:)`

`renderer.submit(objects:)` keeps working — forwards to `alphaBlend.submit`. Objects that don't have an `AlphaBlendComponent` are silently skipped (not an error). This matches existing behavior where an object without a valid `textureID` would render the default magenta error texture.

### Init signature

`DefaultRenderer(parentView:maxObjects:uniformSize:)` → `DefaultRenderer(parentView:maxObjects:)`. The `uniformSize` parameter had become redundant once the shader owns its own uniform.

---

## Step-by-step plan

### Step 1 — `Shader` protocol
- New file: `graphics/renderers/Shader.swift`
- Add protocol as sketched above.

### Step 2 — Strip `RenderPass`
- `RenderPass.swift`: confirm it no longer exposes shader-specific helpers. Should already be minimal.
- Delete `graphics/renderers/AlphaBlendRenderPass.swift`.

### Step 3 — `AlphaBlendComponent` + `GameObj` cleanup
- New file: `dataTypes/AlphaBlendComponent.swift` (lives next to `Component.swift`).
- Delete `GameObj.textureID`, `GameObj.tintColor`, `GameObj.toUniform()`.
- Change `open class GameObj` → `public final class GameObj`. No subclassing; enforces component composition.
- GameObj now: transform/lifecycle/components only.

### Step 4 — `AlphaBlendShader`
- New file: `graphics/renderers/AlphaBlendShader.swift`.
- Move pipeline state, quad vertex buffer, sampler, world `BufferProvider`, `TextureBatch`, draw count into here.
- Implement `Shader` protocol methods.
- Public draw API: `submit(objects: [GameObj])`, `draw(transform:texTrans:color:textureId:)`.
- `flush(pass:)` does the `drawPrimitives` loop (replaces `AlphaBlendRenderPass.drawBatches`).

### Step 5 — `DefaultRenderer`
- Remove pipelineState / vertexBuffer / worldBufferProvider / samplerState / batches / drawCount / currentTextureId fields.
- Hold `public let alphaBlend: AlphaBlendShader` (constructed in init).
- Hold `private var currentShader: Shader?`.
- Rewrite `beginPass()`:
  - wait on projection provider; call `beginFrame()` on each registered shader (v1: just `alphaBlend`).
  - create generic `RenderPass`.
  - wire completion handler to signal all per-shader semaphores (and projection).
  - no shader is bound yet; `currentShader = nil`.
- `usePerspective()`/`useOrthographic()`: write to `projectionBuffer` only. No encoder binding yet (happens on `useShader`).
- `useShader(_:)`: `currentShader?.flush(pass)`; `shader.bind(pass, projectionBuffer)`; `currentShader = shader`.
- `submit(objects:)`: if `currentShader == nil`, call `useShader(alphaBlend)`; then forward to `currentShader.submit(objects:)`.
- `endPass()`: `currentShader?.flush(pass)`; `pass.end()`; reset state.

### Step 6 — `Renderer` protocol
- Keep `submit(objects:)` as convenience (auto-binds alpha-blend).
- Remove `useTexture(_:)` and `draw(uniforms:)` from base protocol.
- Add `func useShader(_ shader: Shader)`.

### Step 7 — Migrate LiquidMetal2D-Demo
Nine scenes touch `textureID`/`tintColor`/`toUniform` directly and need migration:
- SpawnDemo, CollisionStressDemo, AsyncLoadDemo, CollisionDemo, SchedulerDemo, TouchZoomDemo, CameraRotationDemo, BezierDemo, InstanceDemo
Mechanical replacement: `obj.textureID = X; obj.tintColor = Y` → `obj.add(AlphaBlendComponent(parent: obj, textureID: X, tintColor: Y))`.
Verify each scene builds and runs.

### Step 8 — Tests + sample verification
- Run `xcodebuild test` (iPhone 17 Pro sim) on LiquidMetal2D.
- Build + run LiquidMetal2D-Demo, exercise CollisionDemo, confirm sprites render correctly, perf stays at ~60fps at the target object count.

### Step 9 — Docs
- Update `CLAUDE.md` rendering pipeline section: describe Shader abstraction, component-based render state, new draw flow.

---

## Validation case: debug wireframe overlay

Components make the multi-shader case trivial. To draw wireframe outlines over
sprites, you add a second component to the same GameObj:

```swift
// At spawn
let ship = GameObj()
ship.add(AlphaBlendComponent(parent: ship, textureID: shipTextureID))
if debugMode {
    ship.add(WireframeComponent(parent: ship, color: .green))
}

// Scene draw
renderer.beginPass()
renderer.usePerspective()

renderer.useShader(alphaBlend)
alphaBlend.submit(objects: allObjects)  // picks up AlphaBlendComponent

renderer.useShader(wireframe)
wireframe.submit(objects: allObjects)   // picks up WireframeComponent (no-op if not present)

renderer.endPass()
```

One GameObj. Two render components. Two shaders. No parallel debug-object
tracking. Toggle wireframe globally by gating the `add` at spawn, or dynamically
by `add`/`remove` on existing objects.

This is the reason render state **must not** live on base `GameObj` — a single
canonical uniform forces one shader per object, and fields pile up as shaders
are added. Components keep the base class clean and let each shader own its
own per-object data.

## Out of scope (follow-ups)

- A second concrete shader (e.g. `WireframeShader`) — prove the abstraction by writing one, but that's a separate task.
- Scene-level auto-sort across shader types (v1: each shader walks the full list and filters).
- Migrating Matt's other game projects (Shmupper, Crunch, etc.) to the new component-based render state.
- Depth buffer / stencil for real 3D pipelines.
- Shader hot-reload.
