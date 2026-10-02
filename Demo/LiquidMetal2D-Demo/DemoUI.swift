//
//  DemoUI.swift
//  LiquidMetal2D-Demo
//
//  What the SwiftUI layer knows about the running engine.
//

import Observation
import LiquidMetal2D

/// One instance for the app, made in `DemoApp` and handed to `ViewController`, which sets
/// `sceneMgr` once the engine exists. SwiftUI views read it to drive the engine.
@MainActor
@Observable
final class DemoUI {
    /// The engine's scene manager; nil until `ViewController.viewDidLoad` has built the engine.
    var sceneMgr: SceneManager?
}
