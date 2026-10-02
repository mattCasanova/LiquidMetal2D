//
//  SceneMenu.swift
//  LiquidMetal2D-Demo
//
//  The scene picker in the window's top-right corner.
//

import SwiftUI

/// Lists every navigable scene; picking one replaces the scene stack. On the Mac this is
/// the only way to change scenes until the SwiftUI rewrite reaches the panels; on iOS it
/// sits beside the scenes' UIKit Menu button until that button and `PauseDemo` are replaced.
struct SceneMenu: View {
    let ui: DemoUI

    var body: some View {
        Menu {
            ForEach(SceneTypes.navigable, id: \.self) { scene in
                Button(scene.title) { select(scene) }
            }
        } label: {
            Label("Scenes", systemImage: "list.bullet")
        }
        .buttonStyle(.bordered)
        .tint(TokyoNight.color(TokyoNight.blue))
    }

    private func select(_ scene: SceneTypes) {
        guard let sceneMgr = ui.sceneMgr else {
            // The engine is built when the Metal view loads, before anything can be clicked.
            preconditionFailure("SceneMenu used before the engine was built")
        }
        sceneMgr.setScene(type: scene)
    }
}
