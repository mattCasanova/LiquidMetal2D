//
//  DemoUI.swift
//  LiquidMetal2D-Demo
//
//  What the SwiftUI layer knows about the running engine, and what the scenes put on it.
//

import SwiftUI
import LiquidMetal2D

/// One instance for the app, made in `DemoApp`. `ViewController` sets `sceneMgr` once the
/// engine exists and hands the object to every scene through `DemoServices`. SwiftUI reads it.
///
/// **The overlay pattern:** a scene with controls owns an `@Observable` controls object
/// (slider values, labels, button closures), builds a SwiftUI panel over it, and sets that
/// panel as `overlay` in `initialize` and again in `resume` (a pushed scene such as
/// `PauseDemo` takes the slot while it is up). It clears `overlay` in `shutdown`. SwiftUI
/// controls eat their own input; touches and clicks on the Metal view reach the engine.
@MainActor
@Observable
final class DemoUI {
    /// The engine's scene manager; nil until `ViewController.viewDidLoad` has built the engine.
    var sceneMgr: SceneManager?

    /// The current scene's controls, drawn over the Metal view; nil for none.
    var overlay: AnyView?

    /// Hides the scene menu while a scene (the pause menu) shows its own list.
    var isMenuHidden = false
}
