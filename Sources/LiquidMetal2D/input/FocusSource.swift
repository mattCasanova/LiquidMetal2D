//
//  FocusSource.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Tells the input queue when the app stops receiving input, so held keys
/// and buttons release instead of sticking: on iOS when the app resigns
/// active, on the Mac when the app resigns active or the game's window
/// stops being the key window. Created by ``DefaultEngine`` for every
/// device set; ``stop()`` detaches on shutdown.
@MainActor
final class FocusSource {
    private var observers: [NSObjectProtocol] = []

    init(view: PlatformView, enqueue: @escaping @MainActor (RawInputEvent) -> Void) {
        let center = NotificationCenter.default
        #if canImport(UIKit)
        observers.append(center.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { enqueue(.focusLost) }
        })
        #elseif canImport(AppKit)
        observers.append(center.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { enqueue(.focusLost) }
        })
        observers.append(center.addObserver(
            forName: NSWindow.didResignKeyNotification, object: nil, queue: .main
        ) { [weak view] note in
            // Only the identity crosses into the actor; the notification itself is not Sendable.
            let resigned = (note.object as AnyObject?).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                guard let resigned, let window = view?.window, ObjectIdentifier(window) == resigned else { return }
                enqueue(.focusLost)
            }
        })
        #endif
    }

    func stop() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
}
