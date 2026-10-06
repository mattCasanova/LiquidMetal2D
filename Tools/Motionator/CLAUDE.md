# Motionator

The engine's Mac tool for skeletal animation and particle effects (plan: `~/workspace/LM2D/editor-tool.md`;
the Skeleton-mode design and the order of work: `~/workspace/LM2D/motionator-skeleton-mode.md`). Lives in the
engine repo and builds against the engine in this checkout: no tags, no version bumps.

## Layout

- `MotionatorKit/` — a plain SwiftPM package, macOS 26, depending on the engine at `../../..`:
  - `Sources/MotionatorKit` — the document model and the editing operations, pure and testable:
    `Character` (a rig, its clips, its PNG images) and `CharacterFiles` (the `.character` folder:
    `Name.rig.json`, `clips/*.clip.json`, `images/*.png`; the engine's own formats through `AnimationFiles`,
    nothing new on disk); `ClipEditor` (keys, easing, poses, duration, events; each call returns a new clip,
    so undo is keeping the old value); `RigEditor` (bones, reparenting that keeps the world rest pose,
    attachments from images; every result validated); `PoseSampler` (world transforms, hit tests, the IK
    solve and rotate-to-point as plain functions, the same arithmetic as `SkeletonComponent`); `ContactSheet`
    (N frames of a clip drawn headless by the real renderer into one PNG: how an agent looks at an
    animation); `MotionatorCommand` (the command line's logic, so tests can run it)
  - `Sources/motionator` — the executable: `swift run motionator sheet <Hero.character | rig.json> [clip]
    [--frames 8] [--size 256] [--ghost] [--no-labels] [--out file.png]`, `info <path>`, `validate <path>`.
    A rig path takes the clips beside it (or in `clips/`) and looks for images beside the rig, in `images/`,
    or one folder up, so the demo's `Animations/` works as is
  - `Tests/MotionatorKitTests` — `swift test` on the host; the GPU tests skip without a Metal device and
    use the demo's stick figure as the fixture
- The app (`Motionator.xcodeproj`, SwiftUI, `DocumentGroup` over a `.character` package) is Phase B of the
  design plan and does not exist yet

## Build and test

```bash
cd Tools/Motionator/MotionatorKit
swift build
swift test
swift run motionator sheet ../../../Demo/LiquidMetal2D-Demo/Animations/stickfigure.rig.json walk --out /tmp/walk.png
```

## Notes

- Headless rendering: `ContactSheet` makes a `RenderCore` on an `NSView` in no window (as the engine's pixel
  tests do), a `DefaultRenderer` subclass whose `makeRenderPass()` draws into a readable texture
  (`TextureRenderPass`), and a `SkeletonComponent` posed by restarting the clip and advancing to each sample
  time, so the sheet shows exactly what the game draws. Images outside the bundle reach the GPU through
  `DefaultRenderer.addTexture(_ image: CGImage)`
- Components hold their `GameObj` unowned: anything that makes a `SkeletonComponent` keeps its root alive
  for as long as the parts are drawn (`withExtendedLifetime`)
- Hit tests prefer the bone drawn on top when two coincide (the near and far legs at rest)
- No third-party dependencies; the command line parses its own arguments
