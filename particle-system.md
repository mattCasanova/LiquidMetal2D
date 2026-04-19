# CPU-Driven Particle System

## Context

Adds a fourth shader to LiquidMetal2D: `ParticleShader` (additive-blended,
texture-capable) plus a `ParticleEmitterComponent` that owns a pre-allocated
particle pool. The emitter attaches to any `GameObj`; the shader walks emitters
and iterates each emitter's internal particle array to write per-particle
uniforms.

**Why now:** the multi-shader refactor (0.8.0–0.8.4) proved the architecture
supports arbitrary shaders. Particles are the canonical "many cheap sprites
with lifetime and animation" case — a natural test of the Shader/Component
pattern under higher throughput than the existing three shaders.

**Intended outcome:** ship additive-blended particles in 0.9.0 with a demo
scene showing a movable emitter + live controls. Alpha-blended particles
(smoke/dust) deferred as a follow-up shader class reusing the same component.

## Checklist

- [ ] 1. `Particle` struct — plain struct with transform/color/lifetime state
- [ ] 2. `ParticleEmitterComponent` — pool + config + `update(dt:)` for simulation
- [ ] 3. `ParticleUniform` — per-particle GPU payload (transform + color)
- [ ] 4. `ParticleShader.metalSource` — vertex + fragment (samples texture, multiplies tint)
- [ ] 5. `ParticlePipeline` — factory for the additive-blend pipeline state
- [ ] 6. `ParticleShader` — `Shader` conformer; walks emitters, iterates live particles, batches by texture
- [ ] 7. Bundle the new `.metalSource` resource in `Package.swift`
- [ ] 8. Add `defaultParticleTexture` (64×64 soft-circle, procedurally generated) to `TextureManager`; expose via `Renderer.defaultParticleTextureId`
- [ ] 9. Demo scene (`ParticleDemo`) in LiquidMetal2D-Demo + Xcode project file entry
- [ ] 10. Run `xcodebuild test` (engine) + `xcodebuild build` (demo)
- [ ] 11. Tag as `0.9.0` (minor bump — new feature, no breaking API)
- [ ] 12. Update `CLAUDE.md` architecture section

---

## Design

### Data model

**`Particle`** — value type, stored inline in emitter's pool array:

```swift
public struct Particle {
    public var position: Vec2
    public var velocity: Vec2
    public var rotation: Float
    public var angularVelocity: Float
    public var scale: Vec2
    public var startColor: Vec4
    public var endColor: Vec4
    public var age: Float
    public var lifetime: Float

    public var isAlive: Bool { age < lifetime }
    public static let dead = Particle(... age: 1, lifetime: 0 ...)  // age >= lifetime
}
```

Color interpolates on CPU (`lerp(startColor, endColor, age/lifetime)`) during
uniform assembly — trivial cost, keeps GPU uniform small.

### `ParticleEmitterComponent`

Lives under `dataTypes/` alongside other components. Owns the pool and all
emitter config. Matches the Behavior dispatch pattern: scene calls
`emitter.update(dt:)` each frame.

Config fields:
- `maxParticles: Int` — pool size (pre-allocated at init)
- `textureID: Int` — all particles from this emitter share one texture
- `emissionRate: Float` — particles per second
- `localOffset: Vec2` — emit point relative to `parent.position` (rotated by `parent.rotation`)
- `lifetimeRange: ClosedRange<Float>` — random per spawn
- `speedRange: ClosedRange<Float>`
- `angleRange: ClosedRange<Float>` — radians; added to `parent.rotation` at spawn
- `scaleRange: ClosedRange<Float>` — uniform scale per particle
- `angularVelocityRange: ClosedRange<Float>`
- `startColor`, `endColor: Vec4` — interpolated over lifetime (alpha fades for smooth pop-out)
- `gravity: Vec2` — acceleration applied each frame
- `isEmitting: Bool` — pause emission without clearing pool

State:
- `particles: [Particle]` — fixed-size, pre-allocated, dead particles marked `age >= lifetime`
- `timeToNextSpawn: Float` — accumulator for emission rate

`update(dt:)` responsibilities (one call per frame, scene-driven):
1. Advance all live particles (integrate position, velocity, rotation, age).
2. Spawn new particles while `timeToNextSpawn <= 0`, decrementing by `1 / emissionRate`.
3. Finding a free slot: linear scan for `!isAlive`. For `maxParticles = 500` this is fine; upgrade to a free-list if it ever shows in a profile.

`forEachAlive(_ body: (Particle) -> Void)` — read-only iteration for the shader.

### `ParticleUniform`

```swift
public final class ParticleUniform: UniformData {
    public var transform: Mat4 = Mat4()
    public var color: Vec4 = Vec4(1, 1, 1, 1)
    // 80 bytes total
}
```

No `texTrans` for v1 — full texture per particle. Easy to add later.

### Textures and shape

Every particle samples a texture. Shape comes from the texture's alpha mask:
- **Soft-circle gradient (`renderer.defaultParticleTextureId`)** → glow look (classic particle) when additively blended
- **Star PNG** → glowing stars that brighten on overlap (user-supplied)
- **1×1 white (`renderer.defaultTextureId`)** → flat tinted squares with additive hotspots

No SDF in the fragment shader, no "texture or no texture" branch. Always sample.
Texture swap = shape change.

The emitter's `textureID` is a required init parameter — no nil case. Users
pick from the engine's built-in textures or their own.

### Built-in particle texture (engine-side)

Add a third procedural texture to `TextureManager` alongside `defaultTexture`
(1×1 white) and `errorTexture` (1×1 magenta):

- **Size:** 64×64, `bgra8Unorm` (16 KB — trivial).
- **Content:** RGB = white for every pixel. Alpha channel is a radial falloff
  — `alpha = (1 - normalizedDistance)²` clamped to [0, 1]. Opaque center,
  transparent at corners, smooth gradient in between.
- **Generated in code** at `TextureManager.init` time, exactly like the
  existing `createDefaultTexture` pattern. No asset file.

API additions:
- `TextureManager.defaultParticleTexture: Texture`
- `TextureManager.defaultParticleTextureId: Int`
- `Renderer.defaultParticleTextureId: Int` (protocol + DefaultRenderer forwards)

Demo and end users can reach for this without adding PNG assets; swap to a
custom texture (star, spark, hexagon) whenever they want a specific shape.

### `ParticleShader.metalSource`

Vertex function: identical shape to the existing shaders (project unit quad,
apply per-instance transform, pass through UV + color).

Fragment function:
```metal
fragment half4 particle_fragment(VertOut interp [[ stage_in ]],
                                 texture2d<half> tex2D [[ texture(0) ]],
                                 sampler sampler2D [[ sampler(0) ]]) {
    half4 texColor = tex2D.sample(sampler2D, interp.texCoord);
    return texColor * half4(interp.color);
}
```

Same fragment as AlphaBlendShader's — pipeline-level blend state is what makes
this additive instead of alpha-composited:

```swift
// Additive:
colorDescriptor?.sourceRGBBlendFactor        = .sourceAlpha
colorDescriptor?.sourceAlphaBlendFactor      = .sourceAlpha
colorDescriptor?.destinationRGBBlendFactor   = .one
colorDescriptor?.destinationAlphaBlendFactor = .one
```

**Why the texture's alpha doesn't force alpha-compositing:** the alpha channel
in a PNG is just data (a weight). The blend mode decides how it's used. With
`sourceAlpha * one` additive blending, transparent areas of the texture
contribute zero to the framebuffer, opaque areas contribute their full tinted
color, additively. No sort needed — addition is commutative.

### `ParticleShader` class

Same lifecycle as existing shaders. Differences:
- No z-sort (additive is order-independent — this is the whole point of picking additive for v1)
- Batches by `emitter.textureID` (so emitters with different textures split into separate draws)
- Per-frame submission: walks `[GameObj]`, for each emitter iterates its alive particles, writes uniform per particle
- `maxObjects` sizes the BufferProvider and counts total live particles across all emitters in the frame (not emitter count)

Submit pseudocode:
```swift
for obj in objects where obj.isActive {
    guard let emitter = obj.get(ParticleEmitterComponent.self) else { continue }
    emitter.forEachAlive { particle in
        scratchUniform.transform.setToTransform2D(
            scale: particle.scale,
            angle: particle.rotation,
            translate: Vec3(particle.position, obj.zOrder))
        scratchUniform.color = lerp(
            particle.startColor, particle.endColor, particle.age / particle.lifetime)
        scratchUniform.setBuffer(buffer: contents, offsetIndex: drawCount)
        appendBatch(textureId: emitter.textureID)
        drawCount += 1
    }
}
```

### Integration with other shaders (same-object multi-shader)

A GameObj can carry `AlphaBlendComponent` + `ParticleEmitterComponent`
simultaneously — e.g., a ship sprite with a jet-exhaust emitter behind it.
Each shader picks up only its matching component; the scene's `draw()`
does two passes over the same `[GameObj]` list:

```swift
func draw() {
    guard renderer.beginPass() else { return }
    renderer.usePerspective()

    // Pass 1: sprite pass
    renderer.submit(objects: objects)       // AlphaBlendShader picks up AlphaBlendComponent

    // Pass 2: particle pass
    renderer.useShader(particleShader)
    renderer.submit(objects: objects)       // ParticleShader picks up ParticleEmitterComponent

    renderer.endPass()
}
```

Key points:
- Ship contributes to both passes (has both components).
- Pure anchor with only emitter contributes to pass 2 only.
- Pure sprite with only alpha-blend component contributes to pass 1 only.
- Wireframe + ripple can be added as more passes — same pattern as MultiShaderDemo.

Each particle holds its own **world** position (computed during emitter
`update` from `parent.position + rotate(localOffset, parent.rotation)`),
so the particle shader never has to know about the parent. Matches how
alpha-blend uses the ship's transform — particles are standalone GPU
entities once spawned.

### Demo scene

`ParticleDemo` (new file in LiquidMetal2D-Demo, `ParticleDemo.swift`):
- One `GameObj` acting as the emitter anchor, positioned at screen center
- Attaches `ParticleEmitterComponent` with sensible defaults (rate 60/s, lifetime 1.0–2.0s, fan-out ~30° cone, white sprite texture with soft alpha)
- Scene's `update(dt:)` calls `emitterObj.get(ParticleEmitterComponent.self)?.update(dt:)`
- Three buttons: **Burst** (spawns 50 at once by calling a `spawn(count:)` method), **Pause/Resume** (toggles `isEmitting`), **Move** (random-walks the emitter anchor)
- Demonstrates: continuous emission, one-shot burst, emitter motion (proves the local-offset + parent-tracking works)

Particle texture for the demo — pick one of:
- Use `renderer.defaultTextureId` (1×1 white) → flat tinted squares, additive overlap still produces hotspots. Zero setup.
- Add a 64×64 soft-circle gradient PNG (`softGlow.png` or similar) to the demo's assets → classic fire/glow look. One-time asset add in Xcode.
- Add a star PNG later if we want the "sparkle / magic" variant.

V1 can ship with either; option 2 makes the campfire effect look right.

---

## Files to add

### Engine (`/Users/mattcasanova/src/games/LiquidMetal2D`)

| File | Purpose |
|------|---------|
| `Sources/LiquidMetal2D/dataTypes/Particle.swift` | Plain-struct particle state |
| `Sources/LiquidMetal2D/components/ParticleEmitterComponent.swift` | Component with pool + update |
| `Sources/LiquidMetal2D/graphics/uniforms/ParticleUniform.swift` | GPU uniform layout |
| `Sources/LiquidMetal2D/graphics/shaders/ParticlePipeline.swift` | MTLRenderPipelineState factory (additive blend) |
| `Sources/LiquidMetal2D/graphics/shaders/ParticleShader.swift` | `Shader` conformer |
| `Sources/LiquidMetal2D/Resources/ParticleShader.metalSource` | GPU code |

Edits:
- `Package.swift` — add `.copy("Resources/ParticleShader.metalSource")`
- `CLAUDE.md` — mention the fourth shader + component in the architecture section

### Demo (`/Users/mattcasanova/src/games/LiquidMetal2D-Demo`)

| File | Purpose |
|------|---------|
| `LiquidMetal2D-Demo/LiquidMetal2D-Demo/ParticleDemo.swift` | Demo scene |

Edits:
- `SceneTypes.swift` — add `.particleDemo` case + title + navigable list
- `ViewController.swift` — register `ParticleDemo.self`
- Xcode project (manual): add `ParticleDemo.swift` to target via Xcode (pbxproj can't be safely hand-edited)

---

## Existing utilities to reuse

- **`Shader` protocol** (`graphics/renderers/Shader.swift`) — same contract as AlphaBlend/Wireframe/Ripple; nothing new needed.
- **`BufferProvider`** (`graphics/metalHelpers/BufferProvider.swift`) — triple-buffered; size at `ParticleUniform.typeSize() * maxObjects`.
- **`RenderCore.createQuad()` / `.createDefaultSampler()` / `.loadShaderLibrary(...)`** — pipeline setup helpers (same as other shaders use).
- **`UniformData` protocol** (`graphics/uniforms/UniformData.swift`) — implement on `ParticleUniform`.
- **`Vec2.set(angle:)` / `simd_float4x4+.setToTransform2D(...)`** — existing math helpers.
- **Renderer `register`/`unregister` lifecycle** (from 0.8.2) — scene constructs `ParticleShader`, registers on init, unregisters on shutdown.

---

## Step-by-step

### Step 1 — `Particle` struct
- New file: `dataTypes/Particle.swift`
- Plain struct with transform + color + lifetime fields, `isAlive` accessor, `static let dead` initializer.

### Step 2 — `ParticleEmitterComponent`
- New file: `components/ParticleEmitterComponent.swift`
- Implement `Component` (default id: per-type, own slot — does NOT share with anything).
- Pre-allocates `particles` array of `maxParticles`, all dead.
- `update(dt:)`: advance live + spawn new.
- `forEachAlive(_:)` for the shader to iterate.
- `spawn(count:)` for one-shot bursts.

### Step 3 — `ParticleUniform`
- New file: `graphics/uniforms/ParticleUniform.swift`
- Matches the existing uniform pattern (transform + color, `setBuffer(buffer:offsetIndex:)`).

### Step 4 — `ParticleShader.metalSource`
- New file: `Resources/ParticleShader.metalSource`
- Vertex + fragment as sketched above. Fragment is essentially identical to `alphaBlend_fragment`; blend mode is set on the pipeline, not in the shader code.

### Step 5 — `ParticlePipeline`
- New file: `graphics/shaders/ParticlePipeline.swift`
- Enum with binding index constants + `create(renderCore:)` factory.
- Key difference from AlphaBlendPipeline: **additive** blend factors (`sourceAlpha` → `.one` add).

### Step 6 — `ParticleShader`
- New file: `graphics/shaders/ParticleShader.swift`
- Owns pipeline, vertex buffer, sampler, BufferProvider, TextureBatch array, draw count, scratch uniform.
- Walks emitters, iterates each emitter's alive particles, writes uniform per particle, batches by `emitter.textureID`.
- `flush(pass:)`: iterate batches, set texture, emit `drawPrimitives` with `instanceCount = batch.count`.
- No sort — additive is order-independent.

### Step 7 — Package resource + build
- Add `.copy("Resources/ParticleShader.metalSource")` to `Package.swift`.
- `xcodebuild build` and `xcodebuild test` (iPhone 17 Pro sim).

### Step 8 — Demo scene
- `ParticleDemo.swift` as described.
- Register in `SceneTypes` + `ViewController.swift`.
- Build the demo (will require Xcode file add + package bump to new tag).

### Step 9 — Tag + publish
- Commit engine, push, tag `0.9.0`, push tag.
- In demo repo: bump Package.resolved, add ParticleDemo.swift to Xcode, commit, push.

### Step 10 — Docs
- Update `CLAUDE.md` rendering pipeline section: mention particles as the fourth shader, additive blending, emitter-owned particle pool.

---

## Verification

1. **Engine builds + tests pass:**
   ```
   xcodebuild -scheme LiquidMetal2D -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation test
   ```
   Expect all 290+ tests to still pass. No existing tests touch particles, so this is a regression guard.

2. **Demo runs visually:**
   - Navigate to Particle Demo in menu.
   - Continuous emission: particles stream from the anchor in a fan-out cone, fade out over their lifetime.
   - Burst button: 50-particle one-shot spawn.
   - Pause button: stops emission but existing particles finish their lifetimes.
   - Move button: emitter repositions; new particles spawn at the new anchor, old particles continue on their old velocity.

3. **Performance sanity check:**
   - At 500 particles active simultaneously, frame stays at 60fps.
   - Instruments / Xcode memory report: uniform buffer allocation is ~120 KB (500 × 80 × 3 buffers). Trivial.

4. **Multi-emitter behavior (optional):**
   - Stretch goal for the demo: add a second emitter with a different texture to prove texture batching works within `ParticleShader`. If time-boxed, skip and rely on the single-emitter demo.

---

## Out of scope (follow-ups)

- **Alpha-blended particle shader** for smoke/dust/fog. Same `ParticleEmitterComponent` + new `ParticleShader` subclass/variant with alpha-blend pipeline and z-sort. Defer until there's a concrete demand.
- **Parent-child transforms.** V1 uses component-on-parent + local offset — covers jet-exhaust-on-ship. Parent-child is worth it when you want independent child GameObjs (turrets), not for particles.
- **Texture atlas / sprite-sheet particles.** Needs `texTrans` in the uniform and per-particle sub-rect support. Not hard but adds complexity.
- **GPU simulation.** Current plan is CPU-only. GPU-compute particles are a different architecture (compute shader, indirect draw) — deferred indefinitely.
- **Pool freelist.** Linear scan for free slot is fine at 500 particles. Upgrade if profiles show it's hot.
