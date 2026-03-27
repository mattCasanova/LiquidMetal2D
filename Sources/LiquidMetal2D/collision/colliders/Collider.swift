//
//  Collider.swift
//
//
//  Created by Matt Casanova on 3/23/20.
//

/// Collision shape attached to a ``GameObj`` via the component system.
///
/// Conforms to ``Component`` — attach via `obj.add(collider)`.
/// Uses double-dispatch for shape-vs-shape collision checks.
/// All collider types share the same component id so
/// `obj.get(Collider.self)` works regardless of concrete type.
public protocol Collider: Component {
    func doesCollideWith(collider: Collider) -> Bool
    func doesCollideWith(point: Vec2) -> Bool
    func doesCollideWith(circle: Circle) -> Bool
    func doesCollideWith(aabbCenter: Vec2, width: Float, height: Float) -> Bool
}

public extension Collider {
    static var id: ObjectIdentifier { ObjectIdentifier(Collider.self) }
}
