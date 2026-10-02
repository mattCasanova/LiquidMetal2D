//
//  InputObservers.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// Hears pointer button events, with the pointer's location at delivery.
@MainActor
public protocol PointerObserver: AnyObject {
    func pointerTriggered(_ code: InputCode, at location: Vec2?)
    func pointerReleased(_ code: InputCode, at location: Vec2?)
}

/// Hears key events.
@MainActor
public protocol KeyboardObserver: AnyObject {
    func keyTriggered(_ code: InputCode)
    func keyReleased(_ code: InputCode)
}

/// Hears gamepad button events and connection changes.
@MainActor
public protocol GamepadObserver: AnyObject {
    func gamepadTriggered(_ code: InputCode)
    func gamepadReleased(_ code: InputCode)
    func gamepadConnectionChanged(isConnected: Bool)
}

/// A scene's observers. ``DefaultScene`` owns one and forwards the frame's
/// events to it; the engine delivers only to the current scene, so a pushed
/// menu silences the scene below with no work from the game.
///
/// Observers are held weakly: a dead one is pruned at the next delivery.
/// ``DefaultScene/shutdown()`` clears the lot.
@MainActor
public final class InputObservers {
    private var pointerObservers: [WeakBox<PointerObserver>] = []
    private var keyboardObservers: [WeakBox<KeyboardObserver>] = []
    private var gamepadObservers: [WeakBox<GamepadObserver>] = []

    public init() {}

    public func add(pointer observer: PointerObserver) {
        pointerObservers.append(WeakBox(observer))
    }

    public func add(keyboard observer: KeyboardObserver) {
        keyboardObservers.append(WeakBox(observer))
    }

    public func add(gamepad observer: GamepadObserver) {
        gamepadObservers.append(WeakBox(observer))
    }

    /// Removes the object from every list it is in.
    public func remove(_ observer: AnyObject) {
        pointerObservers.removeAll { $0.value == nil || $0.value === observer }
        keyboardObservers.removeAll { $0.value == nil || $0.value === observer }
        gamepadObservers.removeAll { $0.value == nil || $0.value === observer }
    }

    public func removeAll() {
        pointerObservers.removeAll()
        keyboardObservers.removeAll()
        gamepadObservers.removeAll()
    }

    /// Routes each event to the observers of its device, in order. Reads the
    /// pointer only when a pointer event needs its location, so a scene
    /// without the pointer device never asks for it.
    public func deliver(_ events: [InputEvent], from input: InputReader) {
        for event in events {
            switch event {
            case .triggered(let code):
                route(code, isDown: true, input: input)
            case .released(let code):
                route(code, isDown: false, input: input)
            case .gamepadConnected:
                forEachLive(&gamepadObservers) { $0.gamepadConnectionChanged(isConnected: true) }
            case .gamepadDisconnected:
                forEachLive(&gamepadObservers) { $0.gamepadConnectionChanged(isConnected: false) }
            }
        }
    }

    private func route(_ code: InputCode, isDown: Bool, input: InputReader) {
        switch code.device {
        case .pointer:
            let location = input.pointer.location
            forEachLive(&pointerObservers) { observer in
                if isDown {
                    observer.pointerTriggered(code, at: location)
                } else {
                    observer.pointerReleased(code, at: location)
                }
            }
        case .keyboard:
            forEachLive(&keyboardObservers) { isDown ? $0.keyTriggered(code) : $0.keyReleased(code) }
        case .gamepad:
            forEachLive(&gamepadObservers) { isDown ? $0.gamepadTriggered(code) : $0.gamepadReleased(code) }
        default:
            preconditionFailure("InputCode \(code) belongs to no single device")
        }
    }

    /// Calls `body` on every live observer and drops the dead boxes.
    private func forEachLive<T>(_ boxes: inout [WeakBox<T>], _ body: (T) -> Void) {
        var index = 0
        while index < boxes.count {
            if let value = boxes[index].value {
                body(value)
                index += 1
            } else {
                boxes.remove(at: index)
            }
        }
    }
}

/// A weak reference to an observer. `T` is an existential class-bound
/// protocol, so the box stores it as `AnyObject` and casts back.
struct WeakBox<T> {
    private weak var object: AnyObject?

    init(_ value: T) {
        object = value as AnyObject
    }

    var value: T? {
        object as? T
    }
}
