# LiquidMetal2D-Demo

Demo app showcasing LiquidMetal2D engine features. Each scene demonstrates a different engine capability.

## Project Overview

- **Language:** Swift 6
- **Platform:** iOS 26+
- **Build System:** Xcode project (not SPM — uses `.xcodeproj`)
- **Dependency:** LiquidMetal2D as the local package `..` (the engine in this repo); an engine change shows up on the next build, no tag or version bump
- **Theme:** Tokyo Night color palette (`TokyoNight.swift`)

## Structure

All source files live in `Demo/LiquidMetal2D-Demo/` (paths below are relative to the engine root):

- **Entry point** — `ViewController.swift` subclasses `LiquidViewController`, registers all scenes with `SceneFactory`, creates `DefaultRenderer`, and starts the engine
- **Scene registry** — `SceneTypes.swift` enum conforming to `SceneType` with navigable list and next/prev helpers
- **Constants** — `GameConstants.MAX_OBJECTS` (10,000) sets the renderer's uniform buffer size
- **Textures** — `GameTextures.swift` holds global texture IDs loaded once at startup (blue/green/orange ships)
- **Shared UI** — `DemoSceneUI.swift` adds a Menu button overlay; `TokyoNight.swift` provides the color palette
- **Assets** — Ship PNGs (`playerShip1_blue/green/orange.png`) and `disc.png` (a white anti-aliased disc on a clear ground, tinted for round shapes) in the source directory. `disc.png` came from ImageMagick: `magick -size 256x256 xc:white \( -size 256x256 xc:black -fill white -draw "circle 127.5,127.5 127.5,0" \) -alpha off -compose CopyOpacity -composite PNG32:disc.png`

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
| Skeletal Animation | `SkeletonDemo.swift`, `StickFigure.swift` | White-box stick figure (box limbs with `disc.png` caps at every joint and a disc head, so bends look round): `SkeletonComponent`, idle/walk/jump crossfades, slash on an override layer, `flipX`, two-bone IK (Reach: the near hand follows the touch). Rig and clips load from `Animations/*.json` (`AnimationFiles`); a Debug build checks them against the `StickFigure` builders. Auto-plays until the first touch |
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
# from the engine root
xcodebuild -project Demo/LiquidMetal2D-Demo.xcodeproj \
  -scheme LiquidMetal2D-Demo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipPackagePluginValidation build
```

## Notes

- No tests in this project — it's a visual demo app
- Lives in the engine repo: an engine change and its demo change land on the same branch. Open `../LiquidMetal2D.xcworkspace` to get both
- Textures are loaded globally once in `AsyncLoadDemo` (the initial scene), not per-scene
- `nonisolated(unsafe)` is used on `GameTextures` static vars since they're written once at startup
- Each demo scene creates its own `DemoSceneUI` for the Menu button and removes it on shutdown
- The PauseDemo is push-only (not in the navigable list) — it slides in as an overlay
- Per-frame scene code passes no closures to standard-library algorithms (`sort`, `filter`, `removeAll`, …). A closure written in a `@MainActor` scene is `@MainActor`, and those calls check the actor on every call (1.7 ms a frame for MassRender's 10,000-ship sort). Scenes sort with `nonisolated static` comparators (`isFarther`, `activeFirst`, `isSmaller`) or pass a `@Sendable` closure
- `SWIFT_ENFORCE_EXCLUSIVE_ACCESS = debug-only` on the app target: run-time exclusivity checks in Debug builds only. They cost MassRender ~0.9 ms a frame in Release (every `obj.position` read is checked)
