//
//  GameTextures.swift
//  LiquidMetal2D-Demo
//
//  Global texture IDs loaded once during the loading screen.
//
//  **Texture loading strategy:**
//  All textures are loaded once in the LoadingScene at app startup.
//  They persist for the lifetime of the app and are available to every
//  scene via these static properties. No per-scene loading or unloading
//  is needed — the engine cleans up all textures on shutdown.
//
//  **Alternative approach:** For games with many textures, you can load
//  and unload textures per-scene using `renderer.loadTextures()` in
//  `initialize()` and `renderer.unloadTexture()` in `shutdown()`.
//  This is useful when different scenes use different assets and you
//  want to minimize GPU memory usage.
//

import Foundation

struct GameTextures {
    nonisolated(unsafe) static var blue: Int = 0
    nonisolated(unsafe) static var green: Int = 0
    nonisolated(unsafe) static var orange: Int = 0
    /// White anti-aliased disc on a clear ground; tint it for round shapes (the stick figure's joints and head).
    nonisolated(unsafe) static var disc: Int = 0

    /// The ship textures as an array, convenient for random selection.
    static var all: [Int] { [blue, green, orange] }
}
