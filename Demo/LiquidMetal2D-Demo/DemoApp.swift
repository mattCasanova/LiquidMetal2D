//
//  DemoApp.swift
//  LiquidMetal2D-Demo
//
//  The app's entry point: one window holding the engine's Metal view with SwiftUI
//  controls over it. Runs on iPhone, iPad and the Mac from this one target.
//  `GameWindow` makes it one window on the Mac with no accidental way to close
//  or quit; the pause panel's Quit asks first, as a game would.
//

import SwiftUI
import LiquidMetal2D

@main
struct DemoApp: App {
    /// Shared with `ViewController` (which fills in the scene manager), the scenes (which
    /// set their overlay) and the SwiftUI controls (which read it).
    @State private var ui = DemoUI()

    var body: some SwiftUI.Scene {
        GameWindow("LiquidMetal2D Demo") {
            ZStack(alignment: .topLeading) {
                LiquidView { ViewController(ui: ui) }
                    .ignoresSafeArea()
                if let overlay = ui.overlay {
                    overlay
                }
                if !ui.isMenuHidden {
                    SceneMenu(ui: ui)
                        .padding(8)
                }
            }
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 500)
            #endif
        }
    }
}
