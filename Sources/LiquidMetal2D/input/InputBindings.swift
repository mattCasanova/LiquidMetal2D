//
//  InputBindings.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// A game's actions, declared the way scenes are (``SceneType``): an enum of
/// the game's own, backed by `String` so saved bindings are keyed by name.
///
/// ```swift
/// enum Action: String, InputAction {
///     case jump, attack, pause, moveLeft, moveRight
/// }
/// ```
public protocol InputAction: Hashable, CaseIterable, Sendable, RawRepresentable where RawValue == String {}

/// Which codes trigger each of a game's actions. Scenes ask about the action,
/// never the button:
///
/// ```swift
/// var bindings = InputBindings<Action>(defaults: [
///     .jump: [.space, .w, .gamepadA],
///     .attack: [.pointerPrimary, .j, .gamepadX],
///     …
/// ])
/// if input.isTriggered(.jump, in: bindings) { … }
/// let walk = input.axis(negative: .moveLeft, positive: .moveRight, in: bindings)
/// ```
///
/// Every action is always bound to a list, which may be empty (the player
/// cleared it): an empty list is never down. A list may name codes of
/// devices that are off; they count as never down (see `InputReader`).
/// Combos with modifiers are shortcuts, not bindings: ask
/// `isComboTriggered` for those.
///
/// Remapping writes new lists (`set`, `add`, `remove`); `saved` and
/// `restore` turn the table into a `[String: [InputCode]]` that any
/// `Codable` store can keep, codes and actions both by name.
public struct InputBindings<Action: InputAction>: Equatable, Sendable {
    /// The lists the game shipped with; `reset` goes back to them.
    public let defaults: [Action: [InputCode]]
    private var table: [Action: [InputCode]]

    /// - Parameter defaults: A list for every case of `Action`. A missing
    ///   case is a programmer error and traps: an action nobody can press
    ///   should be an explicit empty list.
    public init(defaults: [Action: [InputCode]]) {
        for action in Action.allCases where defaults[action] == nil {
            preconditionFailure("InputBindings: no default for \(Action.self).\(action.rawValue)")
        }
        self.defaults = defaults
        table = defaults
    }

    /// The codes bound to an action, in the order they were bound.
    public func codes(for action: Action) -> [InputCode] {
        guard let codes = table[action] else {
            // init binds every case and nothing removes a key.
            preconditionFailure("InputBindings: \(Action.self).\(action.rawValue) has no list")
        }
        return codes
    }

    /// The actions a code is bound to, in case order. More than one means a
    /// conflict a controls screen may want to show.
    public func actions(boundTo code: InputCode) -> [Action] {
        Action.allCases.filter { codes(for: $0).contains(code) }
    }

    // MARK: - Remapping

    public mutating func set(_ codes: [InputCode], for action: Action) {
        table[action] = codes
    }

    /// Adds a code to the end of an action's list; nothing if it is already there.
    public mutating func add(_ code: InputCode, to action: Action) {
        var codes = codes(for: action)
        guard !codes.contains(code) else { return }
        codes.append(code)
        table[action] = codes
    }

    public mutating func remove(_ code: InputCode, from action: Action) {
        var codes = codes(for: action)
        codes.removeAll { $0 == code }
        table[action] = codes
    }

    /// Puts one action back to its default list.
    public mutating func reset(_ action: Action) {
        table[action] = defaults[action]
    }

    public mutating func resetAll() {
        table = defaults
    }

    // MARK: - Saving

    /// The table keyed by action name, ready for any `Codable` store. Codes
    /// encode by name too (`InputCode+Codable`).
    public var saved: [String: [InputCode]] {
        var saved: [String: [InputCode]] = [:]
        for (action, codes) in table {
            saved[action.rawValue] = codes
        }
        return saved
    }

    /// Loads saved lists over the current ones. An action the file lacks
    /// keeps its current list (it was added after the save); a name this
    /// game no longer has is skipped (it was removed), with a Debug line.
    public mutating func restore(_ saved: [String: [InputCode]]) {
        for (name, codes) in saved {
            guard let action = Action(rawValue: name) else {
                DebugPrint("InputBindings: skipping saved action \"%@\"; %@ has no such case",
                           name, String(describing: Action.self))
                continue
            }
            table[action] = codes
        }
    }
}
