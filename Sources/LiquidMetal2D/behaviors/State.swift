/// A single state within a ``Behavior`` state machine.
///
/// Each state has three lifecycle methods called by its owning behavior:
/// 1. ``enter()`` — called once when transitioning into this state
/// 2. ``update(dt:)`` — called every frame while this state is active
/// 3. ``exit()`` — called once when transitioning out of this state
///
/// Implement concrete states by conforming to this protocol, then
/// transition between them via ``Behavior/setNext(next:)``.
public protocol State: AnyObject {
    /// Called once when the behavior transitions into this state.
    func enter()

    /// Called every frame while this state is the current state.
    /// - Parameter dt: Delta time in seconds since the last frame.
    func update(dt: Float)

    /// Called once when the behavior transitions out of this state.
    func exit()
}
