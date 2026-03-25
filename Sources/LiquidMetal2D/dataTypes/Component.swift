/// Base protocol for all components attached to a ``GameObj``.
///
/// Components add optional capabilities (collision, AI, animation, etc.)
/// to game objects via composition instead of inheritance.
///
/// Each component holds an `unowned` reference to its parent GameObj.
/// **Components must not outlive their parent.** Do not hold references
/// to components outside the scene's object list — the parent may be
/// deallocated, causing a crash.
///
/// Components are stored by a hashable key, not by type. The engine
/// provides ``EngineComponent`` for built-in slots (collider, behavior).
/// Consumers define their own enum for game-specific components.
///
/// ```swift
/// let ship = GameObj()
/// ship.add(.collider, CircleCollider(parent: ship, radius: 1))
/// ship.add(.behavior, MyBehavior(parent: ship))
///
/// ship.get(.collider, as: Collider.self)?.doesCollideWith(...)
/// ship.get(.behavior, as: Behavior.self)?.update(dt: dt)
/// ```
public protocol Component: AnyObject {
    /// The GameObj that owns this component.
    var parent: GameObj { get }
}

/// Built-in component slots provided by the engine.
public enum EngineComponent: Hashable {
    case collider
    case behavior
}
