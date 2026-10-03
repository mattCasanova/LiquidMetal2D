//
//  AppStateSource.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/4/26.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Watches the platform's notifications and reports the app's ``AppState``
/// to ``DefaultEngine``. Created by the engine; ``stop()`` detaches on
/// shutdown. Reports may repeat a state; the engine drops repeats.
@MainActor
final class AppStateSource {
    private var observers: [NSObjectProtocol] = []

    #if canImport(UIKit)
    /// Each notification and the state it means. Leaving: resign active, then
    /// enter background. Coming back: enter foreground, then become active;
    /// back from Notification Center or a call, only become active.
    static let transitions: [(name: Notification.Name, state: AppState)] = [
        (UIApplication.willResignActiveNotification, .inactive),
        (UIApplication.didEnterBackgroundNotification, .background),
        (UIApplication.willEnterForegroundNotification, .inactive),
        (UIApplication.didBecomeActiveNotification, .active)
    ]

    init(view: PlatformView, report: @escaping @MainActor (AppState) -> Void) {
        let center = NotificationCenter.default
        for (name, state) in Self.transitions {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { report(state) }
            })
        }
    }

    #elseif canImport(AppKit)
    /// The state from four facts about the app and the game's window. Hidden
    /// or minimised is out of sight; otherwise the game has the player only
    /// when the app is active and its window is key (a sheet or another of
    /// the app's windows takes key status).
    nonisolated static func state(
        appActive: Bool, appHidden: Bool, windowKey: Bool, windowMinimised: Bool
    ) -> AppState {
        if appHidden || windowMinimised { return .background }
        return appActive && windowKey ? .active : .inactive
    }

    init(view: PlatformView, report: @escaping @MainActor (AppState) -> Void) {
        let recompute: @MainActor () -> Void = { [weak view] in
            // No window yet (launch) or any more (closing, which shuts the
            // engine down): nothing to report, so the last state stands.
            guard let window = view?.window else { return }
            let app = NSApplication.shared
            report(Self.state(
                appActive: app.isActive, appHidden: app.isHidden,
                windowKey: window.isKeyWindow, windowMinimised: window.isMiniaturized))
        }

        let center = NotificationCenter.default
        let appNames: [Notification.Name] = [
            NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
            NSApplication.didHideNotification, NSApplication.didUnhideNotification
        ]
        for name in appNames {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { recompute() }
            })
        }

        let windowNames: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
            NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification
        ]
        for name in windowNames {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak view] note in
                // Only the identity crosses into the actor; the notification itself is not Sendable.
                let changed = (note.object as AnyObject?).map(ObjectIdentifier.init)
                MainActor.assumeIsolated {
                    guard let changed, let window = view?.window, ObjectIdentifier(window) == changed else { return }
                    recompute()
                }
            })
        }
    }
    #endif

    func stop() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
}
