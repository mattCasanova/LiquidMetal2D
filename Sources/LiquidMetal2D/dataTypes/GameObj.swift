//
//  GameObj.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/24/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

open class GameObj {
    public var position = Vec2()
    public var velocity = Vec2()
    public var scale = Vec2()
    public var zOrder: Float = 0.0
    public var rotation: Float = 0.0
    public var textureID = 0
    public var isActive: Bool = true
    public var tintColor = Vec4(1, 1, 1, 1)

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

    /// Builds the uniform data for this object. Override in subclasses to
    /// provide custom uniform types for different shaders.
    /// Called by ``Renderer/submit(objects:)`` for each object.
    open func toUniform() -> UniformData {
        let uniform = WorldUniform()
        uniform.transform.setToTransform2D(
            scale: scale, angle: rotation,
            translate: Vec3(position, zOrder))
        uniform.color = tintColor
        return uniform
    }
}
