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
- `Motionator.xcodeproj` — the Mac app (SwiftUI, macOS 26, synchronized folders, ad-hoc signed like the demo's
  Mac build, App Sandbox with user-selected files). Depends on the engine at `../..` and on `MotionatorKit`:
  - `Motionator/MotionatorApp.swift` — `DocumentGroup` over `CharacterDocument`
  - `CharacterDocument` — `ReferenceFileDocument` (the old `ObservableObject`, which the protocol requires; not
    the `@Observable` macro) over a `Character`; reads and writes through `CharacterFiles`; `apply(_:named:undoManager:)`
    is the one way to edit: it keeps the old value for undo and ticks `version` so the viewport rebuilds. The
    `.character` type is declared in `Info.plist` (a package UTType) and excluded from the resources phase
  - `EditorSession` — what isn't saved: mode, the selection (`EditorSelection`: a bone or a part), camera,
    grid, pixels per unit for imports, the last refused edit's reason, the window's undo manager
  - `CharacterEditorView` — the window: bones (indented by depth, context menu to add a child or delete),
    parts in draw order (drag to reorder) and clips in the sidebar; the viewport in the detail (PNGs dropped on
    it become parts); the mode picker, Add Bone, Add Part…, Delete, grid, Fit and the inspector toggle in the
    toolbar. Every edit goes through one `edit(name) { character in … }` helper that calls `RigEditor` and
    shows a refused edit's reason in the inspector
  - `InspectorView` — the selected bone's name, parent, length and rest pose (degrees shown, radians stored)
    or the selected part's name, bone, image, tint, size, offset and angle; in Animate mode the selected keys
    (time, value, easing, delete), the selected event, and the selected bone's pose at the playhead (editing
    it keys the bone there); number fields commit on Return or focus loss, one undo step each
  - `EditorViewController` / `EditorServices` / `EditorScene` (+`Pointer`, +`Overlay`) — the engine for one
    window, as the demo wires it. The scene draws the rig from a `SkeletonComponent` it rebuilds whenever the
    rig it shows changes, placing the parts with `place(pose:)` (its animator is never used), a unit grid, and
    an overlay of bone lines and joint dots (the selection in orange, bones pending a key in deeper orange).
    Pan by dragging empty space, zoom by scroll. **Setup mode:** a click on a bone selects it and a drag edits
    its rest pose: plain drag rotates it to point at the pointer, Command-drag moves it, Option-drag sets its
    length. **Animate mode:** the clip's pose at the playhead; a drag rotates the bone, Command-drag moves it,
    a drag on the ring at a hand, foot or head reaches with two-bone IK (Option flips the bend); with auto-key
    on the changed channels are keyed at the playhead when the button goes up, with it off the edit is kept as
    scratch and the bones go orange until Key (K) writes them or the playhead moves. Onion skins are two more
    skeletons at the previous and next key times, red and green. The reference image is a quad behind
    everything. A drag shows a draft and commits one undo step on release. The scene owns the figures' roots
    (components hold them unowned)
  - `TransportBar` — clip picker (new, delete), start, step, play (Space), end, time, length, loop, snap
    (free, 24, 30, 60 fps), auto-key, Key, onion skins
  - `TimelineView` (+`Drawing`, +`Gestures`; `TimelineLayout` is the pure geometry, tested) — a row per bone,
    a diamond per key time, an events row, the ruler with the playhead and the clip's end. Click the ruler to
    scrub, drag diamonds to move keys (Shift adds to the selection, Option copies), drag empty space to
    box-select, double-click a row to key that bone at that time, double-click the events row to add an event,
    drag the clip's end for its length, right-click for easing and delete
  - `MotionatorTests` — XCTest with the app as host; `SWIFT_DEFAULT_ACTOR_ISOLATION` is off for the test target
    (it makes XCTest's inherited initialisers main-actor bound and the target fails to compile)
- `Examples/StickFigure.character` — the demo's stick figure packed by `motionator pack`; open it in the app

## Build and test

```bash
cd Tools/Motionator/MotionatorKit
swift build
swift test
swift run motionator sheet ../../../Demo/LiquidMetal2D-Demo/Animations/stickfigure.rig.json walk --out /tmp/walk.png
# the app, from the engine root
xcodebuild -project Tools/Motionator/Motionator.xcodeproj -scheme Motionator -destination 'platform=macOS' \
  -skipPackagePluginValidation build      # or test
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
- Running the built app from a shell: start it as a job (`Motionator.app/Contents/MacOS/Motionator Some.character &`
  then `wait`), not in a subshell that exits, or it dies with the shell. A document opened by path that way shows
  as Locked: the sandbox only writes files the user picked in a panel. Launch Services (`open`) is the normal way
- `Info.plist` is hand-written for the document type; `GENERATE_INFOPLIST_FILE` still adds the usual keys
