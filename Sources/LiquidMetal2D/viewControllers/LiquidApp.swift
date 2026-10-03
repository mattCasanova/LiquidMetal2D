//
//  LiquidApp.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/3/26.
//

#if canImport(AppKit) && !canImport(UIKit)
import AppKit

/// App-level calls a game makes on the Mac.
public enum LiquidApp {
    /// Quits for real. ``GameWindow`` removes every accidental way to quit,
    /// so a game calls this from its own Quit button, after whatever prompt
    /// it wants; the engine never asks.
    ///
    /// Every quit, this one or a deliberate system one (the Dock, log out,
    /// restart, shut down), runs ``DefaultEngine/shutdown()`` first, so the
    /// current scene and every stacked scene get `shutdown()`: save there.
    ///
    /// Mac only: iOS apps may not quit themselves.
    @MainActor
    public static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
#endif
