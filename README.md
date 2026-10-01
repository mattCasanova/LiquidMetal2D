# LiquidMetal2D

A Swift 6 / Metal 2D game engine library for iOS 26+ and macOS 26+, as a Swift package.

## Run the demo

The demo app lives in `Demo/` and builds against the engine in this checkout, so an engine change
shows up in the demo on the next build.

1. Open `LiquidMetal2D.xcworkspace` (the engine package and the demo project together) or
   `Demo/LiquidMetal2D-Demo.xcodeproj` on its own.
2. Pick the `LiquidMetal2D-Demo` scheme and a simulator or device.
3. Run. If Xcode asks, trust and enable the SwiftLint build plugin.

The demo is a menu of scenes, one per engine feature: instanced rendering, collision, camera,
particles, skeletal animation and more. `Demo/CLAUDE.md` has the scene table.

Or from the command line:

```bash
xcodebuild -project Demo/LiquidMetal2D-Demo.xcodeproj -scheme LiquidMetal2D-Demo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -skipPackagePluginValidation build
```

## Build and test the engine

```bash
swift build
swift test
```
