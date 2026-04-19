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
    public var position = Vec2()
    public var velocity = Vec2()
    public var scale = Vec2()
    public var zOrder: Float = 0.0
    public var rotation: Float = 0.0
    public var isActive: Bool = true

    private var components = [ObjectIdentifier: Component]()

    public init() {}

    /// Adds a component, stored under its type's ``Component/id``.
    public func add(_ component: Component) {
        components[type(of: component).id] = component
    }

    /// Returns the component stored under the given type's id, cast to that type.
    public func get<T: Component>(_ type: T.Type) -> T? {
        components[T.id] as? T
    }

    /// Returns the component stored under the given id without casting.
    public func get(id: ObjectIdentifier) -> Component? {
        components[id]
    }

    /// Removes the component stored under the given type's id.
    public func remove<T: Component>(_ type: T.Type) {
        components.removeValue(forKey: T.id)
    }

    /// Removes the component stored under the given id.
    public func remove(id: ObjectIdentifier) {
        components.removeValue(forKey: id)
    }
}
