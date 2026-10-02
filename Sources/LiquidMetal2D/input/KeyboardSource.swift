//
//  KeyboardSource.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

import GameController

/// Feeds physical key presses from `GCKeyboard` into the input queue. The
/// same code runs on iOS and macOS. Created by ``DefaultEngine`` when the
/// keyboard device is enabled; ``stop()`` detaches on shutdown.
///
/// Keys the engine has no ``InputCode`` for (media keys, international keys)
/// are dropped: absent is normal there, not a bug.
@MainActor
final class KeyboardSource {
    private let enqueue: @MainActor (RawInputEvent) -> Void
    private var observers: [NSObjectProtocol] = []
    private weak var attached: GCKeyboard?

    init(enqueue: @escaping @MainActor (RawInputEvent) -> Void) {
        self.enqueue = enqueue
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                // The coalesced keyboard stands for every connected one.
                guard let keyboard = GCKeyboard.coalesced else { return }
                self.attach(keyboard)
            }
        })
        observers.append(center.addObserver(forName: .GCKeyboardDidDisconnect, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                // Keys held on the keyboard that left would otherwise stick.
                self.enqueue(.focusLost)
            }
        })
        if let keyboard = GCKeyboard.coalesced {
            attach(keyboard)
        }
    }

    private func attach(_ keyboard: GCKeyboard) {
        attached = keyboard
        keyboard.keyboardInput?.keyChangedHandler = { [enqueue] _, _, keyCode, pressed in
            // The handler arrives on the main queue; no Task hop, which could
            // reorder events.
            MainActor.assumeIsolated {
                guard let code = KeyboardSource.map[keyCode.rawValue] else { return }
                enqueue(pressed ? .down(code) : .up(code))
            }
        }
    }

    /// Detaches from the keyboard and the notifications.
    func stop() {
        attached?.keyboardInput?.keyChangedHandler = nil
        attached = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    /// `GCKeyCode` to ``InputCode``, keyed by the code's raw value.
    nonisolated static let map: [GCKeyCode.RawValue: InputCode] = {
        let pairs: [(GCKeyCode, InputCode)] = [
            (.keyA, .a), (.keyB, .b), (.keyC, .c), (.keyD, .d), (.keyE, .e), (.keyF, .f), (.keyG, .g),
            (.keyH, .h), (.keyI, .i), (.keyJ, .j), (.keyK, .k), (.keyL, .l), (.keyM, .m), (.keyN, .n),
            (.keyO, .o), (.keyP, .p), (.keyQ, .q), (.keyR, .r), (.keyS, .s), (.keyT, .t), (.keyU, .u),
            (.keyV, .v), (.keyW, .w), (.keyX, .x), (.keyY, .y), (.keyZ, .z),
            (.zero, .digit0), (.one, .digit1), (.two, .digit2), (.three, .digit3), (.four, .digit4),
            (.five, .digit5), (.six, .digit6), (.seven, .digit7), (.eight, .digit8), (.nine, .digit9),
            (.spacebar, .space), (.returnOrEnter, .returnKey), (.escape, .escape), (.tab, .tab),
            (.deleteOrBackspace, .backspace),
            (.upArrow, .arrowUp), (.downArrow, .arrowDown), (.leftArrow, .arrowLeft), (.rightArrow, .arrowRight),
            (.leftShift, .leftShift), (.rightShift, .rightShift),
            (.leftControl, .leftControl), (.rightControl, .rightControl),
            (.leftAlt, .leftOption), (.rightAlt, .rightOption),
            (.leftGUI, .leftCommand), (.rightGUI, .rightCommand),
            (.F1, .f1), (.F2, .f2), (.F3, .f3), (.F4, .f4), (.F5, .f5), (.F6, .f6),
            (.F7, .f7), (.F8, .f8), (.F9, .f9), (.F10, .f10), (.F11, .f11), (.F12, .f12)
        ]
        var map: [GCKeyCode.RawValue: InputCode] = [:]
        for (keyCode, code) in pairs {
            map[keyCode.rawValue] = code
        }
        return map
    }()
}
