/// A state machine that manages transitions between ``State`` instances.
///
/// A behavior holds a single current state and drives its lifecycle.
/// Call ``setStartState(startState:)`` to initialize, then
/// ``setNext(next:)`` from within a state to transition. The behavior's
/// ``update(dt:)`` forwards to the current state each frame.
///
/// Default implementations are provided via a protocol extension, so
/// conforming types only need to declare a `current` property.
public protocol Behavior: AnyObject {
    /// The currently active state.
    var current: State! { get set }

    /// Sets the initial state and calls its ``State/enter()`` method.
    func setStartState(startState: State)

    /// Transitions from the current state to a new one.
    /// Calls ``State/exit()`` on the old state and ``State/enter()`` on the new one.
    func setNext(next: State)

    /// Forwards the frame update to the current state.
    func update(dt: Float)
}

public extension Behavior {
    func setStartState(startState: State = NilState()) {
        current = startState
        current.enter()
    }

    func setNext(next: State) {
        current.exit()
        current = next
        current.enter()
    }

    func update(dt: Float) {
        current.update(dt: dt)
    }
}
