//
//  PauseDemo.swift
//  LiquidMetal2D-Demo
//
//  Scene menu overlay: a SwiftUI panel over the paused scene's last frame.
//

import SwiftUI
import LiquidMetal2D

/// Menu overlay scene pushed on top of the current game scene.
///
/// **What the user sees:** the scene underneath freezes on its last frame behind a dim panel
/// listing every demo scene, with Resume at the top. Resume pops this scene; a scene name
/// replaces the whole stack with that scene.
///
/// **Engine features demonstrated:**
/// - **Scene stacking (push/pop):** `SceneMenu`'s Pause item *pushes* this scene with
///   `sceneMgr.pushScene(type:)`. The scene underneath is not shut down: it stays on the stack,
///   stops getting `update` and `draw`, and gets `resume()` when `popScene()` removes this one.
/// - **setScene vs pushScene:** `setScene(type:)` replaces the whole stack (shutting down every
///   stacked scene); `pushScene` adds on top. Picking a scene here uses `setScene`; Resume uses
///   `popScene`.
/// - **The overlay pattern:** this scene's whole job is the SwiftUI view it hands to
///   `DemoUI.overlay` in `initialize` and clears in `shutdown` (see `DemoUI`). `update` and
///   `draw` do nothing, so the last frame drawn by the scene below stays on screen.
final class PauseDemo: LiquidMetal2D.Scene {
    static var sceneType: any SceneType { SceneTypes.pauseDemo }

    private var ui: DemoUI!

    func initialize(services: SceneServices) {
        let sceneMgr = services.sceneMgr
        ui = services.demoUI
        ui.isMenuHidden = true
        ui.overlay = AnyView(PausePanel(
            onResume: { sceneMgr.popScene() },
            onSelect: { scene in sceneMgr.setScene(type: scene) }))
    }

    /// Nothing can be pushed on top of this scene.
    func resume() {}
    /// SwiftUI lays the panel out itself.
    func resize() {}
    func update(dt: Float) {}
    func draw() {}

    func shutdown() {
        ui.overlay = nil
        ui.isMenuHidden = false
    }

    static func build() -> LiquidMetal2D.Scene { PauseDemo() }
}

/// The pause menu: dims the frozen scene and lists the demo scenes.
struct PausePanel: View {
    let onResume: () -> Void
    let onSelect: (SceneTypes) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            TokyoNight.color(TokyoNight.bg).opacity(0.85)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Button("Resume", action: onResume)
                        .font(.headline)
                        .foregroundStyle(TokyoNight.color(TokyoNight.blue))
                        .padding(.bottom, 8)
                    ForEach(SceneTypes.navigable, id: \.self) { scene in
                        Button(scene.title) { onSelect(scene) }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(TokyoNight.color(TokyoNight.fg))
                .padding(16)
            }
            .frame(maxWidth: 400, alignment: .leading)
        }
    }
}
