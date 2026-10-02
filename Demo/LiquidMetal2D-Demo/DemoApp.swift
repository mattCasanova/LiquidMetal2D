//
//  DemoApp.swift
//  LiquidMetal2D-Demo
//
//  The app's entry point: one window holding the engine's Metal view with SwiftUI
//  controls over it. Runs on iPhone, iPad and the Mac from this one target.
//

import SwiftUI
import LiquidMetal2D

@main
struct DemoApp: App {
    /// Shared with `ViewController` (which fills in the scene manager) and the SwiftUI
    /// controls (which read it).
    @State private var ui = DemoUI()

    var body: some SwiftUI.Scene {
        WindowGroup {
            ZStack(alignment: .topTrailing) {
                LiquidView { ViewController(ui: ui) }
                    .ignoresSafeArea()
                SceneMenu(ui: ui)
                    .padding(8)
            }
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 500)
            #endif
        }
    }
}
