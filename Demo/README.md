# LiquidMetal2D-Demo

Part of [LiquidMetal2D](../README.md); builds against the engine in this repo through a local
package reference, so an engine change shows up here on the next build. No tag or version bump.

## Run

1. Open `../LiquidMetal2D.xcworkspace` (engine and demo together) or `LiquidMetal2D-Demo.xcodeproj`.
2. Pick the `LiquidMetal2D-Demo` scheme and a simulator or device.
3. Run. If Xcode asks, trust and enable the SwiftLint build plugin.

Or from the engine root:

```bash
xcodebuild -project Demo/LiquidMetal2D-Demo.xcodeproj -scheme LiquidMetal2D-Demo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -skipPackagePluginValidation build
```

Each scene shows one engine feature; `CLAUDE.md` lists them.
