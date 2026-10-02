//
//  SceneMenu.swift
//  LiquidMetal2D-Demo
//
//  The scene picker in the window's top-left corner.
//

import SwiftUI
import LiquidMetal2D

/// Lists every navigable scene; picking one replaces the scene stack. Pause pushes
/// `PauseDemo` on top of the current scene instead.
struct SceneMenu: View {
    let ui: DemoUI

    var body: some View {
        Menu {
            ForEach(SceneTypes.navigable, id: \.self) { scene in
                Button(scene.title) { sceneMgr.setScene(type: scene) }
            }
            Divider()
            Button("Pause") { sceneMgr.pushScene(type: SceneTypes.pauseDemo) }
        } label: {
            Label("Scenes", systemImage: "list.bullet")
        }
        .buttonStyle(.bordered)
        .tint(TokyoNight.color(TokyoNight.blue))
    }

    private var sceneMgr: SceneManager {
        guard let sceneMgr = ui.sceneMgr else {
            // The engine is built when the Metal view loads, before anything can be clicked.
            preconditionFailure("SceneMenu used before the engine was built")
        }
        return sceneMgr
    }
}
