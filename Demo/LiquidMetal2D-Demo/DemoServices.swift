//
//  DemoServices.swift
//  LiquidMetal2D-Demo
//
//  The engine's services plus the demo's own.
//

import LiquidMetal2D

/// What every scene receives in `initialize(services:)`: the engine's bag plus the SwiftUI
/// bridge. `ViewController` builds it through `DefaultEngine(buildServices:)`.
@MainActor
final class DemoServices: SceneServices {
    let renderer: Renderer
    let input: InputReader
    let sceneMgr: SceneManager
    let documents: DocumentIO
    let ui: DemoUI

    init(renderer: Renderer, input: InputReader, sceneMgr: SceneManager, documents: DocumentIO, ui: DemoUI) {
        self.renderer = renderer
        self.input = input
        self.sceneMgr = sceneMgr
        self.documents = documents
        self.ui = ui
    }
}

extension SceneServices {
    /// The demo's SwiftUI bridge. Every scene here runs in `DemoApp`'s engine, which always
    /// builds `DemoServices`; any other bag is a programming error.
    var demoUI: DemoUI {
        guard let demo = self as? DemoServices else {
            fatalError("\(type(of: self)) is not DemoServices; the demo's scenes need DemoApp's engine")
        }
        return demo.ui
    }
}
