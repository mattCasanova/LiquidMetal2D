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
/// Each component type declares a static ``id`` that determines its
/// storage slot in the GameObj's component dictionary. Related types
/// (e.g., all colliders) share the same id so they can be fetched
/// by their base protocol.
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

    /// The storage key for this component type. Components that share
    /// the same id occupy the same slot (one per id per GameObj).
    /// Override in base protocols (Collider, Behavior) so all
    /// subtypes share a single slot.
    static var id: ObjectIdentifier { get }
}

/// Default id: uses the concrete type's own ObjectIdentifier.
/// Base protocols (Collider, Behavior) override this to group
/// all their subtypes under one key.
public extension Component {
    static var id: ObjectIdentifier { ObjectIdentifier(Self.self) }
}
