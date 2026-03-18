# Graphics Pipeline Refactor Plan

## Context

Major overhaul of the LiquidMetal2D rendering pipeline. Fixes correctness bugs, modernizes the Metal shader, implements instanced rendering for 10-50x GPU performance, adds orthographic projection, and adds tests. The engine renders textured quads using Metal on iOS.

**Build:** `xcodebuild -scheme LiquidMetal2D -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation build`
**Test:** `xcodebuild -scheme LiquidMetal2D -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation test`

## Issues Addressed

| Issue | Title | Priority |
|-------|-------|----------|
| #51 | Replace force-try in shader/pipeline compilation | P1 |
| #57 | Fix texture pixel format mismatch (RGBA→BGRA) | P1 |
| #32 | Fix @unchecked Sendable on BufferProvider | P2 |
| #60 | Add @MainActor annotations to main-thread-only classes | P2 |
| #62 | Fix semaphore blocking main thread indefinitely | P2 |
| #15 | Add bounds checking to uniform buffer memcpy | P0 |
| #17 | Replace deprecated packed_float types in shader | P0 |
| #18 | Move/improve shader source handling | P1 |
| #13 | Implement instanced rendering | P0 |
| #23 | Sprite batching by texture | P1 |
| #14 | Fix per-frame WorldUniform allocation | P0 |
| #24 | Implement useOrthographic() stub | P2 |
| #41 | Add projection/unproject round-trip tests | P3 |

## Checklist

### Phase 1: Foundation Fixes (no API changes, each is independent)
- [x] Step 1: Replace `try!` in shader/pipeline compilation (#51)
- [x] Step 2: Fix texture pixel format to BGRA (#57)
- [x] Step 3: Fix @unchecked Sendable on BufferProvider + DefaultRenderer, add @MainActor to main-thread classes (#32, #60)
- [x] Step 4: Fix semaphore blocking main thread (#62)
- [x] Step 5: Add bounds checking to uniform buffer memcpy (#15)

### Phase 2: Shader Modernization
- [x] Step 6: Replace deprecated packed_float with vertex descriptor (#17)
- [x] Step 7: Add shader source documentation comment (#18)

### Phase 3: Instanced Rendering (the big one)
- [x] Step 8: Add submit(objects:) API + instanced rendering (#13, #23)
- [x] Step 9: Update demo scenes to use submit(objects:)
- [x] Step 10: WorldUniform stored property on DefaultRenderer (#14)

### Phase 4: Orthographic Projection
- [x] Step 11: Add makeOrthographic to Mat4 extensions
- [x] Step 12: Create OrthographicProjection class
- [x] Step 13: Implement useOrthographic() and setOrthographic() (#24)

### Phase 5: Tests
- [ ] Step 14: Add projection/unproject round-trip tests (#41)
- [ ] Step 15: Add orthographic projection tests

---

## Phase 1: Foundation Fixes

### Step 1: Replace `try!` in shader/pipeline (#51)

**File:** `renderers/RenderCore.swift` — `createPipelineState` method (~line 90)

Current code uses `try!` twice (shader compile + pipeline create). Replace with do-catch that produces descriptive `fatalError` messages:

```swift
let defaultLibrary: MTLLibrary
do {
    defaultLibrary = try device.makeLibrary(source: ShaderSources.alphaBlendShader, options: nil)
} catch {
    fatalError("Failed to compile Metal shader library: \(error)")
}

guard let fragmentProgram = defaultLibrary.makeFunction(name: fragmentName) else {
    fatalError("Failed to find fragment function '\(fragmentName)'")
}
guard let vertexProgram = defaultLibrary.makeFunction(name: vertexName) else {
    fatalError("Failed to find vertex function '\(vertexName)'")
}

// ... pipeline descriptor setup ...

do {
    return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
} catch {
    fatalError("Failed to create render pipeline state: \(error)")
}
```

Remove the `// swiftlint:disable:next force_try` comments.

### Step 2: Fix texture pixel format (#57)

**File:** `metalHelpers/Texture.swift` — `loadTexture` method

Two changes:
1. CGContext bitmapInfo (line 57): `CGImageAlphaInfo.premultipliedLast.rawValue` → `CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue`
2. Texture descriptor (line 64): `MTLPixelFormat.rgba8Unorm` → `MTLPixelFormat.bgra8Unorm`

This matches the CAMetalLayer format (`.bgra8Unorm`, set in RenderCore.swift line 48), eliminating per-pixel channel swizzle.

**Verify:** Run demo — textures should display with correct colors. Wrong format = red/blue swap.

### Step 3: Fix @unchecked Sendable (#32)

**Files:** `metalHelpers/BufferProvider.swift`, `renderers/DefaultRenderer.swift`

BufferProvider:
- Remove `@unchecked Sendable`
- Add `@MainActor` to class
- Mark `signal()` as `nonisolated` (only touches `DispatchSemaphore`, which is thread-safe)
- If compiler complains about `semaphore` access from nonisolated context, mark it `nonisolated(unsafe) private let semaphore` (safe because DispatchSemaphore is thread-safe)

DefaultRenderer:
- Remove `@unchecked Sendable` (already `@MainActor`)

Also add explicit `@MainActor` to classes that run on main thread but aren't annotated (#60):
- `DefaultEngine` — conforms to @MainActor protocols but class itself isn't marked
- `Scheduler` — only called from scenes on main thread
- `LiquidViewController` — UIViewController subclass, always main thread
- `SceneFactory` — only used during setup and transitions on main thread

### Step 4: Fix semaphore blocking main thread (#62)

**Files:** `metalHelpers/BufferProvider.swift`, `renderers/DefaultRenderer.swift`, `renderers/Renderer.swift`

Current: `semaphore.wait()` blocks indefinitely. If GPU is behind, the main thread freezes.

Fix: `BufferProvider.wait()` returns `Bool` with a 16ms timeout:
```swift
public func wait() -> Bool {
    return semaphore.wait(timeout: .now() + .milliseconds(16)) == .success
}
```

`beginPass()` returns `Bool` — false means GPU is behind, skip this frame:
```swift
public func beginPass() -> Bool {
    guard projectionBufferProvider.wait(),
          worldBufferProvider.wait() else {
        return false
    }
    // ... rest of beginPass
    return true
}
```

Update Renderer protocol: `func beginPass() -> Bool`

Update `DefaultEngine.gameLoop` / `SceneManager` to check the return value and skip the frame if false. This is a public API change but the right fix.

### Step 5: Add bounds checking (#15)

**Files:** `uniforms/WorldUniform.swift`, `uniforms/ProjectionUniform.swift`, `renderers/DefaultRenderer.swift`

Add `assert(offsetIndex >= 0)` to both `setBuffer` methods. Add `assert(drawCount < maxObjects)` before the guard in `DefaultRenderer.draw()`.

---

## Phase 2: Shader Modernization

### Step 6: Replace deprecated packed_float (#17)

**Files:** `constants/constants.swift`, `renderers/RenderCore.swift`

Shader change — replace VertIn struct:
```metal
struct VertIn {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};
```

Change vertex function to use `[[stage_in]]`:
```metal
vertex VertOut basic_vertex(VertIn inVert [[ stage_in ]],
                            const device ProjectionUniform& proj [[ buffer(1) ]],
                            const device WorldUniform& world [[ buffer(2) ]],
                            unsigned int vid [[ vertex_id ]]) {
```

RenderCore — add MTLVertexDescriptor to `createPipelineState`:
```swift
let vertexDescriptor = MTLVertexDescriptor()
vertexDescriptor.attributes[0].format = .float3
vertexDescriptor.attributes[0].offset = 0
vertexDescriptor.attributes[0].bufferIndex = 0
vertexDescriptor.attributes[1].format = .float2
vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 3  // 12 bytes
vertexDescriptor.attributes[1].bufferIndex = 0
vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 5  // 20 bytes
vertexDescriptor.layouts[0].stepRate = 1
vertexDescriptor.layouts[0].stepFunction = .perVertex

pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
```

Vertex data (20 bytes/vertex, 5 floats) is unchanged.

### Step 7: Move shader to real .metal file (#18)

**Files:** `Package.swift`, `constants/constants.swift` (delete), `renderers/RenderCore.swift`, new `Resources/AlphaBlendShader.metal`

Move the shader source from a Swift string literal to a proper `.metal` file bundled as an SPM resource. This gives Xcode syntax highlighting, autocomplete, and compile-time error checking in the editor. Runtime compilation stays the same.

1. Create `Sources/LiquidMetal2D/Resources/AlphaBlendShader.metal` with the shader source
2. Update `Package.swift` target to include resources:
   ```swift
   .target(
       name: "LiquidMetal2D",
       resources: [.copy("Resources/")],
       plugins: [...])
   ```
3. Update `RenderCore.createPipelineState` to load from bundle:
   ```swift
   guard let shaderURL = Bundle.module.url(forResource: "Shaders", withExtension: "metal"),
         let shaderSource = try? String(contentsOf: shaderURL) else {
       fatalError("Failed to load AlphaBlendShader.metal from bundle")
   }
   let defaultLibrary = try device.makeLibrary(source: shaderSource, options: nil)
   ```
4. Rename shader functions from `basic_vertex`/`basic_fragment` to `alphaBlend_vertex`/`alphaBlend_fragment` — frees up "basic" for consumers
5. Update `RenderCore.createPipelineState` calls to use new function names: `vertexName: "alphaBlend_vertex"`, `fragmentName: "alphaBlend_fragment"`
6. Delete `constants/constants.swift` (ShaderSources class no longer needed)

---

## Phase 3: Instanced Rendering

### Step 8: Add `submit(objects:)` API + instanced rendering (#13, #23, #14)

The big API change. Instead of scenes manually calling `useTexture()` → `draw(uniforms:)` per object,
scenes call `submit(objects:)` and the engine handles everything: transforms, sorting, batching, instancing.

**New consumer-side draw pattern:**
```swift
func draw() {
    guard renderer.beginPass() else { return }
    renderer.usePerspective()
    renderer.submit(objects: gameObjects)
    // Later (Phase 4): renderer.useOrthographic(); renderer.submit(objects: hudElements)
    renderer.endPass()
}
```

**What the engine does internally on `submit(objects:)`:**
1. Sorts objects by `(zOrder, textureID)` for optimal batching
2. For each object: computes WorldUniform transform from `position`, `rotation`, `scale`, `zOrder`
3. Writes each WorldUniform into the buffer via `memcpy`
4. Tracks texture batches (consecutive same-texture objects = one batch)

**What `endPass()` does:**
1. Flushes all batches as instanced draw calls (one `drawPrimitives(instanceCount: N)` per texture group)
2. Cleans up render pass state

**Files modified:**

- `Resources/AlphaBlendShader.metalSource` — add `instance_id` to vertex function, read from `WorldUniform*` array
- `renderers/DefaultRenderer.swift` — add `submit(objects:)`, batch tracking, instanced `endPass()`
- `renderers/Renderer.swift` — add `submit(objects:)` to protocol
- `scenes/Scene.swift` — simplify `DefaultScene.draw()` to use `submit(objects:)`

**Shader change** — read from WorldUniform array via `instance_id`:
```metal
vertex VertOut alphaBlend_vertex(VertIn inVert [[ stage_in ]],
                                const device ProjectionUniform& proj [[ buffer(1) ]],
                                const device WorldUniform* worlds [[ buffer(2) ]],
                                unsigned int vid [[ vertex_id ]],
                                unsigned int iid [[ instance_id ]]) {
    WorldUniform world = worlds[iid];
    // rest identical
}
```

**DefaultRenderer — batch tracking:**
```swift
private struct TextureBatch {
    let textureId: Int
    let startIndex: Int
    var count: Int
}

private var batches: [TextureBatch] = []
```

**New `submit(objects:)`** — sorts, transforms, accumulates:
```swift
public func submit(objects: [GameObj]) {
    let sorted = objects.sorted { ($0.zOrder, $0.textureID) < ($1.zOrder, $1.textureID) }

    let worldUniforms = WorldUniform()
    for obj in sorted {
        guard drawCount < maxObjects else { break }

        worldUniforms.transform.setToTransform2D(
            scale: obj.scale, angle: obj.rotation,
            translate: Vec3(obj.position, obj.zOrder))

        worldUniforms.setBuffer(buffer: worldBufferContents, offsetIndex: drawCount)

        if let last = batches.last, last.textureId == obj.textureID {
            batches[batches.count - 1].count += 1
        } else {
            batches.append(TextureBatch(
                textureId: obj.textureID, startIndex: drawCount, count: 1))
        }
        drawCount += 1
    }
}
```

**Change `endPass()`** — flush batches with instanced draws:
```swift
public func endPass() {
    for batch in batches {
        if let texture = renderCore.getTexture(id: batch.textureId) {
            renderPass.encoder.setFragmentTexture(texture.texture, index: 0)
        }
        let offset = batch.startIndex * WorldUniform.typeSize()
        renderPass.encoder.setVertexBufferOffset(offset, index: 2)
        renderPass.encoder.drawPrimitives(
            type: .triangleStrip, vertexStart: 0,
            vertexCount: 4, instanceCount: batch.count)
    }
    renderPass.end()
    renderPass = nil
    drawCount = 0
    batches.removeAll(keepingCapacity: true)
}
```

**Keep `useTexture()` + `draw(uniforms:)` as advanced API** for consumers who need manual control
(custom uniforms, non-GameObj rendering, etc.). These still work via the same batch accumulation
but the consumer is responsible for sort order and transform setup.

**`DefaultScene.draw()` simplification:**
```swift
public func draw() {
    guard renderer.beginPass() else { return }
    renderer.usePerspective()
    renderer.submit(objects: objects)
    renderer.endPass()
}
```

### Step 9: Update demo scenes to use `submit(objects:)`

All demo scenes that currently have manual `useTexture()` → `draw(uniforms:)` loops get simplified
to `submit(objects:)`. This is a **public API change** — demo must be updated.

### Step 10: WorldUniform stored property on DefaultRenderer

Move `WorldUniform()` allocation from per-`submit` call to a stored property on `DefaultRenderer`
so it's reused across frames instead of allocating each frame.

---

## Phase 4: Orthographic Projection

### Step 11: Add makeOrthographic to Mat4

**File:** `math/extensions/simd_float4x4+.swift`

Metal NDC z range is [0, 1]:
```swift
static func makeOrthographic(
    left: Float, right: Float, bottom: Float, top: Float,
    nearZ: Float, farZ: Float
) -> Mat4 {
    let rl = right - left
    let tb = top - bottom
    let fn = farZ - nearZ
    var mtx = Mat4()
    mtx[0] = Vec4(2 / rl, 0, 0, 0)
    mtx[1] = Vec4(0, 2 / tb, 0, 0)
    mtx[2] = Vec4(0, 0, -1 / fn, 0)
    mtx[3] = Vec4(-(right + left) / rl, -(top + bottom) / tb, -nearZ / fn, 1)
    return mtx
}
```

### Step 12: OrthographicProjection class

**New file:** `dataTypes/OrthographicProjection.swift` — mirrors PerspectiveProjection pattern with left/right/bottom/top/nearZ/farZ properties, `set()`, and `make()`.

### Step 13: Wire into renderer (#24)

- `RenderCore.swift`: add `public let orthographic = OrthographicProjection()`
- `Renderer.swift`: add `func setOrthographic(left:right:bottom:top:nearZ:farZ:)`
- `DefaultRenderer.swift`: implement `setOrthographic` (delegates to renderCore) and `useOrthographic` (same pattern as usePerspective but uses orthographic.make())

---

## Testing Strategy

### Tests Written With Each Step

Tests should be added alongside implementation, not deferred to the end.

| Step | Tests to Add |
|------|-------------|
| Step 2 (BGRA) | None (visual verification only — correct colors in demo) |
| Step 5 (bounds) | Test that assert fires on negative offsetIndex (if testable) |
| Step 6 (vertex descriptor) | None (visual verification — geometry renders correctly) |
| Step 7 (shader file) | Test that `Bundle.module.url(forResource: "AlphaBlendShader", withExtension: "metal")` resolves (not nil) |
| Step 8 (instancing) | Test TextureBatch accumulation logic in isolation — given a sequence of useTexture/draw calls, verify batch count and sizes |
| Step 11 (makeOrthographic) | Matrix edge mapping tests, round trip tests |
| Step 14 (#41) | Full projection round-trip suite: origin, positive/negative coords, different z, symmetry |
| Step 15 | Orthographic edge mappings, round trip, center→origin |

### Manual Test Checkpoints (STOP and verify with user)

These are the high-risk visual changes. After each one, push the demo update, have the user run the demo and visually confirm all 9 scenes render correctly.

**Checkpoint 1: After Step 2 (BGRA texture format)**
- Risk: Wrong bitmapInfo flags = every texture has red/blue swapped
- Verify: Run demo, check ship colors are correct (blue ships are blue, not orange)

**Checkpoint 2: After Step 6 (vertex descriptor) + Step 7 (shader file)**
- Risk: Wrong vertex descriptor stride/offset = garbled geometry. Wrong bundle path = crash on launch.
- Verify: Run demo, check all scenes render geometry correctly (ships are ship-shaped, not triangles or garbage)

**Checkpoint 3: After Step 8 (instanced rendering)**
- Risk: Wrong buffer offset calculation = transforms misaligned, objects render at wrong positions. Wrong instance count = missing objects or duplicates.
- Verify: Run all 9 demo scenes. Each should look **identical** to before the change. The instancing refactor must be invisible.

**Checkpoint 4: After Step 13 (orthographic)**
- Risk: Low — additive feature, doesn't change existing rendering
- Verify: If we add an orthographic demo scene, check that objects render without perspective distortion

---

## Phase 5: Remaining Tests

### Step 14: Projection round-trip tests (#41)

**File:** New `Tests/LiquidMetal2DTests/ProjectionTests.swift`

Test pure math (no Metal device needed):
- makePerspective produces non-zero diagonal
- Perspective project → unproject round trip (multiply by VP, perspective divide, multiply by VP.inverse)
- Test points: origin, positive/negative coords, different z depths
- Symmetry: (x,y) and (-x,-y) project symmetrically around center
- Non-default camera position

### Step 15: Orthographic tests

- makeOrthographic edge mappings (left→-1, right→1, top→1, bottom→-1)
- Orthographic project → unproject round trip
- Center of box maps to NDC origin
- nearZ maps to z=0, farZ maps to z=1 (Metal NDC)

---

## Verification

After each phase:
1. Build library: `xcodebuild ... build`
2. Run tests: `xcodebuild ... test`
3. At manual checkpoints: push demo update, user runs demo visually

The manual checkpoints are the critical gates — don't proceed past a checkpoint until the user confirms everything looks correct.

---

## Public API Changes (Demo Must Update)

These changes affect the `Renderer` protocol or other public API that the demo consumes. After the library refactor, the demo needs to be updated for these:

| Step | Change | Demo Impact |
|------|--------|-------------|
| Step 3 (#60) | `@MainActor` added to `Scheduler`, `SceneFactory`, `DefaultEngine`, `LiquidViewController` | May require `@MainActor` on demo classes or `MainActor.assumeIsolated` in callbacks. Likely no code change since demo already runs on main thread. |
| Step 4 (#62) | `beginPass()` returns `Bool` instead of `Void` | Scenes with custom `draw()` methods (VisualDemo, InputDemo, ExplosionDemo, StateDemo, CollisionDemo, BezierDemo, FOVDemo) need to check the return value or use `guard renderer.beginPass() else { return }`. DefaultScene.draw() handles it automatically. |
| Step 13 (#24) | New `setOrthographic(left:right:bottom:top:nearZ:farZ:)` on Renderer protocol | Additive — no existing code breaks. Demo can optionally add an orthographic demo scene. |

**No demo changes needed for:** Steps 1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15 — these are internal changes or additive additions.

---

## Key Context (Survives Compaction)

This section captures critical details that must not be lost.

### Repository Locations
- **Library:** `/Users/mattcasanova/src/games/LiquidMetal2D` (SPM package, GitHub: mattCasanova/LiquidMetal2D)
- **Demo:** `/Users/mattcasanova/src/games/LiquidMetal2D-Demo` (Xcode project, GitHub: mattCasanova/LiquidMetal2D-Demo)
- **Current library tag:** 0.5.4 (demo pinned to this)

### Build Commands
```bash
# Library build + test (must cd to library dir first)
cd /Users/mattcasanova/src/games/LiquidMetal2D
xcodebuild -scheme LiquidMetal2D -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation test

# Demo build
xcodebuild -project /Users/mattcasanova/src/games/LiquidMetal2D-Demo/LiquidMetal2D-Demo/LiquidMetal2D-Demo.xcodeproj -scheme LiquidMetal2D-Demo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation build
```

### Current File Layout (files this plan modifies)
```
Sources/LiquidMetal2D/
  constants/constants.swift        — shader string literal (DELETE in Step 7)
  renderers/DefaultRenderer.swift  — main renderer (Steps 4, 5, 8)
  renderers/RenderCore.swift       — Metal setup (Steps 1, 6, 7, 13)
  renderers/Renderer.swift         — protocol (Steps 4, 13)
  metalHelpers/BufferProvider.swift — triple buffering (Steps 3, 4)
  metalHelpers/Texture.swift       — texture loading (Step 2)
  uniforms/WorldUniform.swift      — per-object uniform (Step 5)
  uniforms/ProjectionUniform.swift — projection uniform (Step 5)
  uniforms/UniformData.swift       — uniform protocol (no change)
  dataTypes/RenderPass.swift       — command buffer wrapper (no change)
  dataTypes/Camera2D.swift         — has rotation support already
  dataTypes/PerspectiveProjection.swift — existing projection class
  math/extensions/simd_float4x4+.swift — matrix factory methods (Step 11)
  scenes/Scene.swift               — DefaultScene (Steps 9, 10)
  scheduler/Scheduler.swift        — has isPaused already
  engines/DefaultEngine.swift      — game loop
  viewControllers/LiquidViewController.swift — touch/rotation handler

New files:
  Resources/AlphaBlendShader.metal — shader source file (Step 7)
  dataTypes/OrthographicProjection.swift — new class (Step 12)
```

### Current Shader (in constants.swift as string)
- Vertex struct: `packed_float3 position`, `packed_float2 texCoord` (DEPRECATED)
- Buffer 0: static quad (4 verts × 5 floats = 80 bytes)
- Buffer 1: ProjectionUniform (64 bytes, Mat4)
- Buffer 2: WorldUniform (80 bytes, Mat4 + Vec4 texTrans) — one per object, contiguous
- Vertex function: `basic_vertex` — reads single WorldUniform reference
- Fragment function: `basic_fragment` — simple texture sample
- Pipeline: alpha blending (srcAlpha, oneMinusSourceAlpha)

### Current Draw Pattern (what Phase 3 changes)
```
beginPass() → [useTexture() → draw(uniforms:)] × 4500 → endPass()
```
Each `draw()` call issues its own `drawPrimitives(instanceCount: 1)`. After Phase 3:
```
beginPass() → [useTexture() → draw(uniforms:)] × 4500 → endPass()
```
API identical, but internally `draw()` just memcpys, `endPass()` flushes ~3 instanced draw calls (one per texture group).

### Current Test Count: 178 tests passing

### Commit Convention
- Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`
- Include `Closes #N` for issue auto-close
- Include `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>`

### User Preferences
- Matt swears casually — match his energy, push back directly when he's wrong
- Don't commit without asking first
- Don't suppress SwiftLint warnings — fix the underlying issue
- Show diffs before committing when making architectural changes
- Manual test checkpoints at high-risk visual changes
