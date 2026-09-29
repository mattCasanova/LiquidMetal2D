# LiquidMetal2D-Demo

Demo app showcasing LiquidMetal2D engine features. Each scene demonstrates a different engine capability.

## Project Overview

- **Language:** Swift 6
- **Platform:** iOS 26+
- **Build System:** Xcode project (not SPM — uses `.xcodeproj`)
- **Dependency:** [LiquidMetal2D](https://github.com/mattCasanova/LiquidMetal2D) via SPM (local or remote)
- **Theme:** Tokyo Night color palette (`TokyoNight.swift`)

## Structure

All source files live in `LiquidMetal2D-Demo/LiquidMetal2D-Demo/`:

- **Entry point** — `ViewController.swift` subclasses `LiquidViewController`, registers all scenes with `SceneFactory`, creates `DefaultRenderer`, and starts the engine
- **Scene registry** — `SceneTypes.swift` enum conforming to `SceneType` with navigable list and next/prev helpers
- **Constants** — `GameConstants.MAX_OBJECTS` (10,000) sets the renderer's uniform buffer size
- **Textures** — `GameTextures.swift` holds global texture IDs loaded once at startup (blue/green/orange ships)
- **Shared UI** — `DemoSceneUI.swift` adds a Menu button overlay; `TokyoNight.swift` provides the color palette
- **Assets** — Ship PNGs (`playerShip1_blue/green/orange.png`) in the source directory

## Demo Scenes

| Scene | File | Demonstrates |
|-------|------|-------------|
| Mass Render | `MassRenderDemo.swift` | 10K objects with z-depth parallax |
| Touch & Zoom | `TouchZoomDemo.swift` | Touch input, screen-to-world unprojection |
| Instanced Rendering | `InstanceDemo.swift` | Batch instanced draw calls |
| Scheduler | `SchedulerDemo.swift` | Task chaining, timed events |
| Spawn | `SpawnDemo.swift` | Manual draw order with `useTexture()`/`draw()` |
| Collision & AI | `CollisionDemo.swift` | Colliders + behavior state machines |
| Bezier Curves | `BezierDemo.swift` | Cubic bezier path following |
| Camera Rotation | `CameraRotationDemo.swift` | Camera rotation and shake effects |
| Camera Pan | `CameraPanDemo.swift` | Camera x/y pan, parallax, unproject and visible bounds tracking the camera |
| Skeletal Animation | `SkeletonDemo.swift`, `StickFigure.swift` | White-box stick figure: `SkeletonComponent`, idle/walk/jump crossfades, slash on an override layer, `flipX`, two-bone IK (Reach: the near hand follows the touch). Auto-plays until the first touch |
| Smoke Layers | `SmokeLayersDemo.swift` | Two alpha-blended plumes at different z: the nearer (bigger) one must draw on top; Swap exchanges their `zOrder`. Checks `ParticleShader`'s far-to-near order (0.15.0) |
| Async Loading | `AsyncLoadDemo.swift` | Async texture loading with starfield loading screen |
| Pause Menu | `PauseDemo.swift` | Push/pop scene stack, SlidePanel UI, scene navigation |

## Behaviors & State Machines

- `BehaviorObj.swift` — `GameObj` subclass with a `Behavior` reference
- `FindAndGoBehavior.swift` / `FindAndGoStates.swift` — AI that picks a target and moves to it
- `MoveRightBehavior.swift` / `MoveRightState.swift` — Simple rightward movement with wrapping
- `RandomAngleBehavior.swift` / `RandomAngleState.swift` — Random-direction movement
- `PlayerStateMachine.swift` / `PlayerState.swift` — Player states for collision demo

## Build

```bash
xcodebuild -project LiquidMetal2D-Demo/LiquidMetal2D-Demo.xcodeproj \
  -scheme LiquidMetal2D-Demo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skipPackagePluginValidation build
```

## Notes

- No tests in this project — it's a visual demo app
- Textures are loaded globally once in `AsyncLoadDemo` (the initial scene), not per-scene
- `nonisolated(unsafe)` is used on `GameTextures` static vars since they're written once at startup
- Each demo scene creates its own `DemoSceneUI` for the Menu button and removes it on shutdown
- The PauseDemo is push-only (not in the navigable list) — it slides in as an overlay
- Per-frame scene code passes no closures to standard-library algorithms (`sort`, `filter`, `removeAll`, …). A closure written in a `@MainActor` scene is `@MainActor`, and those calls check the actor on every call (1.7 ms a frame for MassRender's 10,000-ship sort). Scenes sort with `nonisolated static` comparators (`isFarther`, `activeFirst`, `isSmaller`) or pass a `@Sendable` closure
- `SWIFT_ENFORCE_EXCLUSIVE_ACCESS = debug-only` on the app target: run-time exclusivity checks in Debug builds only. They cost MassRender ~0.9 ms a frame in Release (every `obj.position` read is checked)
