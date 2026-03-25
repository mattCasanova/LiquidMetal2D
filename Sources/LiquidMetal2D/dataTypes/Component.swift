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
/// ```swift
/// let ship = GameObj()
/// ship.add(CircleCollider(parent: ship, radius: 1))
/// ship.add(MyBehavior(parent: ship))
///
/// ship.get(Collider.self)?.doesCollideWith(...)
/// ship.get(Behavior.self)?.update(dt: dt)
/// ```
public protocol Component: AnyObject {
    /// The GameObj that owns this component.
    var parent: GameObj { get }
}
