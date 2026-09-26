# LiquidMetal2D

Swift/Metal 2D game engine library for iOS.

## Project Overview

- **Language:** Swift 6
- **Graphics:** Apple Metal
- **Platform:** iOS 26+ (also declares macOS 26+ for SPM tooling)
- **Package Manager:** Swift Package Manager
- **Dependencies:** SwiftLint (build plugin only — no external runtime deps)

## Architecture

- **Graphics** (`graphics/`) — Metal rendering pipeline
  - `renderers/` — orchestration: `Renderer` protocol, `DefaultRenderer` (open for subclassing), `RenderCore` (Metal device/layer/queue)
  - `shaders/` — `Shader` protocol + built-in shaders (`AlphaBlendShader`, `WireframeShader`, `RippleShader`, `ParticleShader`) and their matching `*Pipeline` factories
  - `textures/` — `TextureManager` (async loading, ref counting, error/default textures, 64×64 procedural soft-circle particle texture), `TextureDescriptor`, `Texture`
  - `uniforms/` — `ProjectionUniform`, `AlphaBlendUniform`, `WireframeUniform`, `RippleUniform`, `ParticleUniform`: plain structs whose fields mirror the MSL struct in order. `UniformData` gives `stride` (= `MemoryLayout.stride`, padding included) and `store(into:index:)`, one store per instance. `UniformLayoutTests` pins every stride and offset. **No per-sprite matrices:** each sprite uniform carries a `Transform2D` (position, scale, rotation, zOrder) and the vertex shader builds the transform with `spriteWorld`, one copy per `.metalSource` (`SpriteTransformTests` runs every copy on the GPU against `Mat4.makeTransform2D`). Only `ProjectionUniform` is a matrix, once per frame
  - `shaders/DrawList.swift` — `DrawList<Comp: TexturedComponent>`: the per-frame `(GameObj, Comp)` list, sorted `.farToNear` (`zOrder`, then `textureID`; default) or `.byTexture`, reused across frames (no per-frame allocation). `AlphaBlendShader`, `RippleShader` and `ParticleShader` all use it
  - `shaders/InstanceBatches.swift` — internal value type: one frame's instance count and texture runs (one instanced draw per run). The textured shaders' `submit` swaps it into a local for the per-instance loop; `flush` drops the drawn runs but keeps the count, so later submits in the frame take the next slots
  - `metalHelpers/` — `BufferProvider` (triple-buffered semaphore)
  - `Camera2D`, `PerspectiveProjection`, `OrthographicProjection`, `RenderPass` (generic — owns encoder/drawable/command buffer)
- **Components** (`components/`) — `Component` protocol + render-state components: `AlphaBlendComponent`, `WireframeComponent`, `RippleComponent`, `ParticleEmitterComponent` (owns particle pool). `TexturedComponent` (`textureID`) is the refinement `DrawList` sorts by; the alpha-blend, ripple and emitter components conform
- **Scene Management** (`scenes/`) — Stack-based transitions (push/pop/set) via `SceneManager`. `SceneType` is a `Hashable` protocol (use an enum). `SceneFactory` maps types to `SceneBuilder`s. `DefaultScene` base class with built-in scheduler and object list
- **Game Engine** (`engine/`) — `GameEngine` protocol + `DefaultEngine`. Main loop via CADisplayLink with dt clamping. Full shutdown chain (engine → scenes → renderer)
- **Input** (`input/`) — `InputReader`/`InputWriter` protocols. Touch with screen-to-world unprojection
- **Game Objects** (`dataTypes/`) — `GameObj` (`final`: position, velocity, scale, rotation, zOrder, isActive, components) — **no subclassing, compose via components**. Plain value types: `Transform2D` (what shaders draw from; `GameObj.transform` reads and writes the four fields as one; `Transform2D(rigid, scale:, zOrder:)` places a quad at a `RigidTransform2D`), `Particle` (particle pool data), `WorldBounds`, `UnprojectRay`. The `Component` protocol + render components live in `components/`.
- **Colliders** (`colliders/`) — `Collider` protocol with double-dispatch. `CircleCollider`, `PointCollider`, `AABBCollider`, `NilCollider`. `SpatialGrid` (broad phase): `forEachPotentialPair` and `forEachNear` allocate nothing in optimized builds; `potentialPairs()` / `query(near:)` return arrays for convenience
- **Math** (`math/`) — Merged from MetalMath, no external dependency
  - `GameMath` enum — clamp, wrap, lerp, inverseLerp, remap, smoothstep, bezier curves, angle conversion, float comparison
  - `Easing` enum — quad, cubic, quartic, sine, expo, elastic, bounce, back (in/out/inOut)
  - `Intersect` — point/circle/AABB/line-segment collision tests
  - `Projection` — project/unproject between world and screen coordinates
  - `extensions/` — `simd_float2+`, `simd_float3+`, `simd_float4+`, `simd_float4x4+` (cross2D, to3D, lerp, setToTransform2D, etc.)
  - `shapes/` — `AABB`/`MutableAABB` and `Circle`/`MutableCircle` protocols
  - `TypeAliases` — `Vec2`, `Vec3`, `Vec4`, `Mat4` (aliases for simd types, `@_exported import simd`)
- **Behaviors** (`behaviors/`) — `Behavior`/`State` protocols for game logic state machines
- **Scheduling** (`scheduler/`) — `Scheduler` with pause/resume, `ScheduledTask` with repeat count, chaining (`.then`), completion callbacks. Action receives `dt`
- **Persistence** (`persistence/`) — Two-tier split by who owns the file:
  - **App-owned** — `BlobStore` protocol (key-value `Data` CRUD, throws) with `FileBlobStore` (writes to `Documents/<subdirectory>/<key>`) and `InMemoryBlobStore` (dict-backed, for tests; throws `KeyNotFoundError`). `CodableBlobStore<T>` wraps any `BlobStore` and handles JSON encode/decode for any `Codable` type. Callers construct the underlying `BlobStore` themselves so tests can substitute `InMemoryBlobStore` without a code-path change.
  - **User-owned** — `DocumentIO` (`final class`) wraps `UIDocumentPickerViewController` in async/await. Created once at app startup with the presenting view controller (stored weakly); scenes call `save(data:suggestedFilename:)` / `load(contentTypes:)` without seeing UIKit. `DocumentIO.Error.userCancelled` surfaces picker dismissal; I/O errors propagate as their underlying Cocoa type. Picker delegate lifetime uses a self-retaining coordinator (`selfRef = self`, cleared in callback).
- **View Controllers** (`viewControllers/`) — `LiquidViewController` (touch forwarding, resize on layout, shutdown on disappear), `SlidePanel` (animated UIView sliding in from screen edges), `SlideDirection`
- **Utilities** (`util/`) — `Debug` helpers, `SeededRandom` (SplitMix64 `RandomNumberGenerator`; pass it to `ParticleEmitterComponent(random:)` for a repeatable effect or exact tests)
- **Resources** — `AlphaBlendShader.metalSource`, `WireframeShader.metalSource`, `RippleShader.metalSource`, `ParticleShader.metalSource` (bundled, loaded at runtime)

## Rendering Pipeline

- `RenderCore` owns the Metal device, command queue, CAMetalLayer, camera, projections, and `TextureManager`
- `RenderPass` is generic — owns encoder/drawable/command buffer, has no shader knowledge
- `Shader` protocol encapsulates pipeline state + uniform format + per-frame buffer + batching. Each shader owns its own `BufferProvider` sized to its own uniform stride × its own `maxObjects`
- `AlphaBlendShader` is the built-in default. Filters objects by `AlphaBlendComponent` presence — objects without one are silently skipped
- `DefaultRenderer` owns one `AlphaBlendShader` (exposed as `renderer.alphaBlend`) and tracks the currently-bound shader on the pass
- Draw flow: `beginPass()` → `usePerspective()`/`useOrthographic()` → `useShader(shader)` (optional; `submit` auto-binds alphaBlend) → `submit(objects:)` → `endPass()`. Switching shaders mid-pass flushes the previous shader's batches
- Multi-shader per object: attach multiple render components (e.g., `AlphaBlendComponent` + a future `WireframeComponent`) to one GameObj and each shader picks up its matching component. No duplicate objects
- Advanced manual path: `renderer.alphaBlend.draw(_ transform: Transform2D, texTrans:color:textureId:)` (e.g. `draw(obj.transform, textureId: id)`) — per-call, no sort, batches consecutive same-texture calls
- `submit(objects:)` sorts by `(zOrder, textureID)` via `DrawList` and batches by texture for instanced drawing. Ascending `zOrder` is far-to-near (the camera sits at `z = distance` looking down −z), so the painter's order is ascending. Components build their uniform with `makeUniform()`
- Textures load asynchronously; missing textures show magenta error texture. Built-in 1×1 white `defaultTexture` (for solid-color tinting via `AlphaBlendComponent.tintColor`) and 64×64 soft-circle `defaultParticleTexture` (for additive `ParticleShader` glow) are procedurally generated — no asset files
- `ParticleShader` has two blend modes, **additive** (default, order-independent) and **alpha** ("over"). Alpha walks emitters far-to-near (`DrawList` order `.farToNear`: ascending `zOrder`, then texture; every particle of an emitter shares its `zOrder`, so sorting emitters sorts particles). Additive sorts by texture only (`.byTexture`): clamped addition is order-free, so it sorts purely for batching. `ParticleEmitterComponent` owns a pre-allocated `[Particle]` pool with a free-list stack (O(1) spawn); scenes call `emitter.update(dt:)` each frame. Shader writes one uniform per live particle. CPU interpolates `startColor`→`endColor` by `age/lifetime`

## Build & Test

This is an iOS-only library. Cannot build with `swift build` on macOS (no UIKit).

```bash
# Build
xcodebuild -scheme LiquidMetal2D -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation build

# Test
xcodebuild -scheme LiquidMetal2D -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation test

# Zero-allocation claims (skipped in Debug; only meaningful optimized)
xcodebuild -scheme LiquidMetal2D -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation \
  -configuration Release ENABLE_TESTABILITY=YES test -only-testing:LiquidMetal2DTests/AllocationTests
```

## Notes

- `-skipPackagePluginValidation` is needed for SwiftLint plugin in CLI builds
- Metal shader source is bundled as a resource (`Resources/AlphaBlendShader.metalSource`), compiled at runtime
- All rendering types are `@MainActor`; `DefaultRenderer` is `open` for subclassing; `AlphaBlendShader` is `final`
- `GameObj` is `final` — don't subclass. Compose via `Component` conformers in the component bag
- `@_exported import simd` in TypeAliases.swift — consumers get simd types automatically
- **Small public helpers are `@inlinable`** (math, `Intersect`, `Easing`, simd extensions, `WorldBounds`, `GameObj` component methods). Without it, game code calls them as real functions and generics like `GameObj.get<T>` run unspecialized (verified by disassembling the Release demo). New small, hot public helpers in these files get `@inlinable` too; anything they touch that isn't public needs `@usableFromInline`. Constants are `@inlinable static var x: Float { … }`, not `static let` (a `let` is read through an accessor function across modules). Don't mark large functions inlinable
- **Tests run the real shaders** on the simulator's Metal device: `ShaderTestSupport` builds a `RenderCore` from a bare `UIView`; `OffscreenRenderTests` draws through each shader into a readable 64×64 texture and checks pixels by world position (one world unit per pixel, y up); `SpriteTransformTests` compiles each `.metalSource` with a compute kernel added. Shader or uniform changes must keep these passing
- **Hot plain-data fields are `@exclusivity(unchecked)`** (`GameObj`'s transform fields and `isActive`; the render components' texture, colour and effect fields). Every access to a class's stored `var` otherwise pays a run-time exclusivity check (`swift_beginAccess`); in the 2026-09-25 MassRender profile those checks cost more than all the math. Only plain values get it, never an array, dictionary or reference (`GameObj.components` keeps its check). The attribute covers accesses compiled in this module only; a game turns off its own checks with `SWIFT_ENFORCE_EXCLUSIVE_ACCESS = debug-only`. For the same reason, per-frame loops keep a class's state in locals (`InstanceBatches` in `submit`), and component `parent`s are `unowned let` (a `let` is never checked)
- **Scene code: closures into standard-library algorithms pay an actor-isolation check per call.** A closure written in `@MainActor` code (every scene) is `@MainActor`; passed to `sort`, `filter`, `forEach`, `contains`, `removeAll` and the like, it checks the executor on every call. A 10,000-object sort in the demo's MassRender spent 1.7 ms a frame on it. In per-frame code use a `for-in` loop, a `nonisolated` named function or a `@Sendable` closure. Closures passed to engine APIs (`forEachPotentialPair`, `forEachNear`) don't pay it: the engine is a Swift 6 module
