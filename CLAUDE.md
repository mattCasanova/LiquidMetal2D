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
  - `renderers/` — `Renderer` protocol, `DefaultRenderer` (open for subclassing), `RenderCore` (Metal device/layer/queue), `AlphaBlendPipeline`/`AlphaBlendRenderPass`
  - `textures/` — `TextureManager` (async loading, ref counting, error/default textures), `TextureDescriptor`, `Texture`
  - `uniforms/` — `ProjectionUniform`, `WorldUniform`, `UniformData` protocol
  - `metalHelpers/` — `BufferProvider` (triple-buffered semaphore)
  - `Camera2D`, `PerspectiveProjection`, `OrthographicProjection`, `RenderPass`
- **Scene Management** (`scenes/`) — Stack-based transitions (push/pop/set) via `SceneManager`. `SceneType` is a `Hashable` protocol (use an enum). `SceneFactory` maps types to `SceneBuilder`s. `DefaultScene` base class with built-in scheduler and object list
- **Game Engine** (`engine/`) — `GameEngine` protocol + `DefaultEngine`. Main loop via CADisplayLink with dt clamping. Full shutdown chain (engine → scenes → renderer)
- **Input** (`input/`) — `InputReader`/`InputWriter` protocols. Touch with screen-to-world unprojection
- **Game Objects** (`dataTypes/`) — `GameObj` (position, velocity, scale, rotation, zOrder, textureID, isActive, tintColor), `WorldBounds`, `UnprojectRay`
- **Colliders** (`colliders/`) — `Collider` protocol with double-dispatch. `CircleCollider`, `PointCollider`, `AABBCollider`, `NilCollider`
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
- **View Controllers** (`viewControllers/`) — `LiquidViewController` (touch forwarding, resize on layout, shutdown on disappear), `SlidePanel` (animated UIView sliding in from screen edges), `SlideDirection`
- **Utilities** (`util/`) — `Debug` helpers
- **Resources** — `AlphaBlendShader.metalSource` (bundled, loaded at runtime)

## Rendering Pipeline

- `RenderCore` owns the Metal device, command queue, CAMetalLayer, camera, projections, and `TextureManager`
- `DefaultRenderer` manages triple-buffered uniform buffers and render pass lifecycle
- Draw flow: `beginPass()` → `usePerspective()`/`useOrthographic()` → `submit(objects:)` → `endPass()`
- `submit(objects:)` filters by `isActive`, sorts by `(zOrder, textureID)`, batches by texture for instanced drawing
- Advanced path: `useTexture()` + `draw(uniforms:)` for manual control (no auto-sorting)
- Textures load asynchronously; missing textures show magenta error texture. Built-in 1×1 white `defaultTexture` for solid-color tinting

## Build & Test

This is an iOS-only library. Cannot build with `swift build` on macOS (no UIKit).

```bash
# Build
xcodebuild -scheme LiquidMetal2D -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation build

# Test
xcodebuild -scheme LiquidMetal2D -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation test
```

## Notes

- `-skipPackagePluginValidation` is needed for SwiftLint plugin in CLI builds
- Metal shader source is bundled as a resource (`Resources/AlphaBlendShader.metalSource`), compiled at runtime
- All rendering types are `@MainActor`; `DefaultRenderer` is `open` for subclassing
- `@_exported import simd` in TypeAliases.swift — consumers get simd types automatically
