//
//  GameObj.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/24/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

/// A renderable scene object. Holds transform + lifecycle state plus a
/// ``Component`` bag for everything else (render state, colliders, behaviors,
/// game-specific data).
///
/// **`final` by design:** don't subclass. Attach components instead —
/// ``AlphaBlendComponent`` for alpha-blend rendering, ``Collider`` conformers
/// for collision, ``Behavior`` conformers for state machines, and any
/// game-specific components you define.
public final class GameObj {
    // Plain values that shaders, colliders and behaviors read every frame.
    // `@exclusivity(unchecked)` drops Swift's run-time exclusivity check from
    // the engine's own accesses; code in other modules still checks unless it
    // turns checks off itself (`SWIFT_ENFORCE_EXCLUSIVE_ACCESS = debug-only`).
    // Safe for plain values: an overlapping access, such as passing
    // `&obj.position` inout to a function that also reads `obj.position`,
    // sees the value mid-change instead of trapping, and can't corrupt memory.
    // `components` is a dictionary, so it keeps its check.
    @exclusivity(unchecked) public var position = Vec2()
    @exclusivity(unchecked) public var velocity = Vec2()
    @exclusivity(unchecked) public var scale = Vec2()
    @exclusivity(unchecked) public var zOrder: Float = 0.0
    @exclusivity(unchecked) public var rotation: Float = 0.0
    @exclusivity(unchecked) public var isActive: Bool = true

    @usableFromInline var components = [ObjectIdentifier: Component]()

    public init() {}

    /// ``position``, ``scale``, ``rotation`` and ``zOrder`` as one value, the
    /// form shaders draw from. Setting it sets all four.
    @inlinable
    public var transform: Transform2D {
        get { Transform2D(position: position, scale: scale, rotation: rotation, zOrder: zOrder) }
        set {
            position = newValue.position
            scale = newValue.scale
            rotation = newValue.rotation
            zOrder = newValue.zOrder
        }
    }

    /// Adds a component, stored under its type's ``Component/id``.
    @inlinable
    public func add(_ component: Component) {
        components[type(of: component).id] = component
    }

    /// Returns the component stored under the given type's id, cast to that type.
    @inlinable
    public func get<T: Component>(_ type: T.Type) -> T? {
        components[T.id] as? T
    }

    /// Returns the component stored under the given id without casting.
    @inlinable
    public func get(id: ObjectIdentifier) -> Component? {
        components[id]
    }

    /// Removes the component stored under the given type's id.
    @inlinable
    public func remove<T: Component>(_ type: T.Type) {
        components.removeValue(forKey: T.id)
    }

    /// Removes the component stored under the given id.
    @inlinable
    public func remove(id: ObjectIdentifier) {
        components.removeValue(forKey: id)
    }
}
