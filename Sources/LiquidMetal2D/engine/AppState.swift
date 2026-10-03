//
//  AppState.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/3/26.
//

/// Whether the player can see and use the game.
///
/// ``DefaultEngine`` tracks it from the platform's notifications and tells
/// app code (``AppStateObserver``) and the current scene
/// (``Scene/appStateChanged(to:)``) when it changes. What to do about it,
/// such as pushing a pause scene or saving, is the game's choice; the
/// engine only freezes its own loop (see ``DefaultEngine``).
public enum AppState: Sendable, Equatable {
    /// In front with focus: the player is playing.
    case active
    /// Visible but without focus: Command-Tab to another app, the game's
    /// window not key (an About window, a save panel's sheet), Notification
    /// Center or an incoming call on iOS.
    case inactive
    /// Not visible: the iOS home screen or app switcher, the Mac window
    /// minimised or the app hidden. On iOS this is the last warning before
    /// the system may end the app without telling it, so save here.
    case background
}

/// App-level code that wants every ``AppState`` change, whichever scene is
/// on top (a save service, the view controller). Register with
/// ``DefaultEngine/addAppStateObserver(_:)``; the engine holds it weakly.
@MainActor
public protocol AppStateObserver: AnyObject {
    /// Called when the app's state changes, before the current scene hears it.
    func appStateChanged(to state: AppState)
}
