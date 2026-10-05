# LiquidMetal2D-Demo

Demo app showcasing LiquidMetal2D engine features. Each scene demonstrates a different engine capability.

## Project Overview

- **Language:** Swift 6
- **Platforms:** iPhone, iPad and Mac from one target (iOS 26+, macOS 26+). The Mac build signs ad hoc ("Sign to Run Locally"); iOS uses automatic signing
- **Build System:** Xcode project (not SPM — uses `.xcodeproj`)
- **Dependency:** LiquidMetal2D as the local package `..` (the engine in this repo); an engine change shows up on the next build, no tag or version bump
- **UI:** SwiftUI over the engine's `LiquidView`. No UIKit or AppKit in the scenes; the only platform imports are `ViewController`'s, which subclasses the engine's view controller
- **Theme:** Tokyo Night color palette (`TokyoNight.swift`): `Vec4`s for the engine, `TokyoNight.color(_:)` for SwiftUI

## Structure

All source files live in `Demo/LiquidMetal2D-Demo/` (paths below are relative to the engine root):

- **Entry point** — `DemoApp.swift` (SwiftUI `App`, declaring the engine's `GameWindow`: on the Mac one window with the close button disabled, no Command-W, N or Q) → `LiquidView { ViewController(ui:) }` → `ViewController.swift` subclasses `LiquidViewController`, registers all scenes with `SceneFactory`, creates `DefaultRenderer`, builds the engine with `buildServices` returning `DemoServices`, and starts it with `inputDevices: [.pointer, .keyboard]`. It is also the engine's `AppStateObserver`: when the app goes inactive or out of sight it pushes `PauseDemo` (unless it is already up or the loader is running), the one place the demo reacts to the app lifecycle; nothing pops on return
- **The overlay pattern** — `DemoUI` (`@Observable`, one for the app) carries `sceneMgr`, the current scene's `overlay: AnyView?` and `isMenuHidden`. A scene with controls owns an `@Observable` `XControls` object (slider values, readouts, button closures), builds an `XPanel` SwiftUI view over it, sets `ui.overlay = AnyView(XPanel(controls:))` in `initialize` **and** `resume` (a pushed scene takes the slot), and clears it in `shutdown`. Scenes reach `DemoUI` through `services.demoUI` (`DemoServices.swift`). Sliders are read by the scene each `update` (`FireControls.apply(to:palette:)`); buttons call closures the scene set. SwiftUI controls eat their own input; touches and clicks on the Metal view reach the engine
- **Scene menu** — `SceneMenu.swift`: a `Menu` top-left listing `SceneTypes.navigable` plus a Pause item that pushes `PauseDemo`. `DemoApp` hides it while `ui.isMenuHidden`
- **Shared controls** — `DemoControls.swift`: `DemoButtonStyle` (`.buttonStyle(.demo)`), `BottomBar` (centred button row along the bottom), `ReadoutText` (monospaced readout), `LabeledSlider(title:value:range:format:)`, `ControlColumn` (right-docked scrolling column)
- **Scene registry** — `SceneTypes.swift` enum conforming to `SceneType` with navigable list and next/prev helpers
- **Constants** — `GameConstants.MAX_OBJECTS` (10,000) sets the renderer's uniform buffer size
- **Textures** — `GameTextures.swift` holds global texture IDs loaded once at startup (blue/green/orange ships, disc)
- **Assets** — Ship PNGs (`playerShip1_blue/green/orange.png`) and `disc.png` (a white anti-aliased disc on a clear ground, tinted for round shapes) in the source directory. `disc.png` came from ImageMagick: `magick -size 256x256 xc:white \( -size 256x256 xc:black -fill white -draw "circle 127.5,127.5 127.5,0" \) -alpha off -compose CopyOpacity -composite PNG32:disc.png`

## Demo Scenes

| Scene | File | Demonstrates |
|-------|------|-------------|
| Mass Render | `MassRenderDemo.swift` | 10K objects with z-depth parallax |
| Touch & Zoom | `TouchZoomDemo.swift` | Touch input, screen-to-world unprojection |
| Instanced Rendering | `InstanceDemo.swift` | Batch instanced draw calls |
| Scheduler | `SchedulerDemo.swift` | Task chaining, timed events |
| Spawn | `SpawnDemo.swift` | Manual draw order with `useTexture()`/`draw()`. Reads the visible bounds once on scene load (Matt, 2026-10-02: keep it; resize the Mac window and re-enter the scene for new bounds) |
| Collision & AI | `CollisionDemo.swift` | Colliders + behavior state machines |
| Collision Stress | `CollisionStressDemo.swift` | 7000 ships, `SpatialGrid` broadphase vs brute force, live stats |
| Bezier Curves | `BezierDemo.swift` | Cubic bezier path following |
| Camera Rotation | `CameraRotationDemo.swift` | Camera rotation, scheduled waves, live angle readout |
| Camera Pan | `CameraPanDemo.swift` | Camera x/y pan, parallax, unproject and visible bounds tracking the camera |
| Multi-Shader | `WireframeDemo.swift` (`MultiShaderDemo`) | `AlphaBlendShader`, `WireframeShader` and `RippleShader` in one pass; Wire and Ripple switches read by `draw` each frame |
| Particles (fire, line, smoke) | `ParticleDemo.swift`, `LineParticleDemo.swift`, `RocketTrailDemo.swift` (`SmokeDemo`) | `ParticleEmitterComponent` + `ParticleShader` (additive, line shape, alpha with scale over lifetime). Sliders in a `ControlColumn`; the two fire scenes share `FireControls`/`FirePanel` |
| Skeletal Animation | `SkeletonDemo.swift`, `StickFigure.swift` | White-box stick figure (box limbs with `disc.png` caps at every joint and a disc head, so bends look round): `SkeletonComponent`, idle/walk/jump crossfades, slash on an override layer, `flipX`, two-bone IK (Reach: the near hand follows the touch). Rig and clips load from `Animations/*.json` (`AnimationFiles`); a Debug build checks them against the `StickFigure` builders. Auto-plays until the first touch. Events flash on screen |
| Input | `InputDemo.swift` | The input layer: pointer (hover vs buttons), a marker per touch point, held keys, a flash per trigger, the observer log, Shift-A and Command-B combos (`isComboTriggered` with stored arrays), and actions: `DemoAction` through `InputBindings` (jump logs, the move axis reads -1/0/1, Rebind Jump captures the next key with `firstTriggeredCode()`). Logs `app inactive` / `app background` through `appStateChanged(to:)` as the pause menu goes up. The engine is created with `inputDevices: [.pointer, .keyboard]` |
| Smoke Layers | `SmokeLayersDemo.swift` | Two alpha-blended plumes at different z: the nearer (bigger) one must draw on top; Swap exchanges their `zOrder`. Checks `ParticleShader`'s far-to-near order |
| Async Loading | `AsyncLoadDemo.swift` | Async texture loading with starfield loading screen; Start button appears when done |
| Pause Menu | `PauseDemo.swift` | Push/pop scene stack: a plain `Scene` whose only job is the `PausePanel` overlay; `draw` does nothing so the frozen scene stays visible. `ViewController` also pushes it when the app loses focus. On the Mac its Quit Demo… asks first, then calls `LiquidApp.quit()`: the only in-app way out (the Dock's Quit, log out, restart and shut down also quit, and every path runs the engine's shutdown) |

## Behaviors & State Machines

- `FindAndGoBehavior.swift` / `FindAndGoStates.swift` — AI that picks a target and moves to it
- `MoveRightBehavior.swift` / `MoveRightState.swift` — Simple rightward movement with wrapping
- `RandomAngleBehavior.swift` / `RandomAngleState.swift` — Random-direction movement
- `PlayerStateMachine.swift` / `PlayerState.swift` — Player states for collision demo

## Build

```bash
# from the engine root; iOS simulator
xcodebuild -project Demo/LiquidMetal2D-Demo.xcodeproj -scheme LiquidMetal2D-Demo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -skipPackagePluginValidation build
# Mac
xcodebuild -project Demo/LiquidMetal2D-Demo.xcodeproj -scheme LiquidMetal2D-Demo \
  -destination 'platform=macOS' -skipPackagePluginValidation build
```

## Notes

- No tests in this project — it's a visual demo app
- Lives in the engine repo: an engine change and its demo change land on the same branch. Open `../LiquidMetal2D.xcworkspace` to get both
- Adding a file means editing `project.pbxproj` by hand (a `PBXBuildFile`, a `PBXFileReference`, a group child and a Sources entry) or dragging it into Xcode; the project still uses groups, not synchronized folders
- Textures are loaded globally once in `AsyncLoadDemo` (the initial scene), not per-scene
- `nonisolated(unsafe)` is used on `GameTextures` static vars since they're written once at startup
- The PauseDemo is push-only (not in the navigable list); `SceneMenu`'s Pause item pushes it
- `var body: some SwiftUI.Scene` in `DemoApp` and `LiquidMetal2D.Scene` for scene classes in files that import SwiftUI: both modules have a `Scene`
- Per-frame scene code passes no closures to standard-library algorithms (`sort`, `filter`, `removeAll`, …). A closure written in a `@MainActor` scene is `@MainActor`, and those calls check the actor on every call (1.7 ms a frame for MassRender's 10,000-ship sort). Scenes sort with `nonisolated static` comparators (`isFarther`, `activeFirst`, `isSmaller`) or pass a `@Sendable` closure
- `SWIFT_ENFORCE_EXCLUSIVE_ACCESS = debug-only` on the app target: run-time exclusivity checks in Debug builds only. They cost MassRender ~0.9 ms a frame in Release (every `obj.position` read is checked)
