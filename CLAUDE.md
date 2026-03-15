# LiquidMetal2D

Swift/Metal 2D game engine library for iOS.

## Project Overview

- **Language:** Swift 6
- **Graphics:** Apple Metal
- **Platform:** iOS 17+ (also declares macOS 14+ for SPM tooling)
- **Package Manager:** Swift Package Manager
- **Dependencies:** [MetalMath](https://github.com/mattCasanova/MetalMath) (0.2.0+), SwiftLint (build plugin)

## Architecture

- **Rendering** (`renderers/`) — Metal pipeline with alpha blending, triple-buffered uniforms, texture caching
- **Scene Management** (`scenes/`) — Stack-based scene transitions (push/pop/set) with SceneFactory registry
- **Game Engine** (`engines/`) — Main loop via CADisplayLink, integrates scenes + input + rendering
- **Input** (`input/`) — Touch input with screen-to-world coordinate unprojection
- **Game Objects** (`dataTypes/`) — GameObj base class, Camera2D, PerspectiveProjection, WorldBounds
- **Colliders** (`colliders/`) — Circle, point, AABB collision via MetalMath's Intersect
- **State Machines** (`behavoirs/`) — Behavior/State protocols for game logic
- **Scheduling** (`scheduler/`) — Timed/repeating task system
- **View Controller** (`viewControllers/`) — LiquidViewController base class handling rotation + touch

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
- Metal shaders are embedded as string literals in `constants/constants.swift`
- `DefaultRenderer` is marked `@unchecked Sendable` for Swift 6 concurrency (game loop is single-threaded)
