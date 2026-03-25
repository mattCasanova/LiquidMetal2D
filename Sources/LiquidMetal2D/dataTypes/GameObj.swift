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

    /// Adds a component to this object. One component per type.
    public func add<T: Component>(_ component: T) {
        components[ObjectIdentifier(T.self)] = component
    }

    /// Returns the component of the given type, or nil if not attached.
    public func get<T: Component>(_ type: T.Type) -> T? {
        components[ObjectIdentifier(T.self)] as? T
    }

    /// Removes the component of the given type.
    public func remove<T: Component>(_ type: T.Type) {
        components.removeValue(forKey: ObjectIdentifier(T.self))
    }

    /// Builds the uniform data for this object. Override in subclasses to
    /// provide custom uniform types (e.g., tinted uniforms).
    /// Called by ``Renderer/submit(objects:)`` for each object.
    open func toUniform(_ uniform: WorldUniform) {
        uniform.transform.setToTransform2D(
            scale: scale, angle: rotation,
            translate: Vec3(position, zOrder))
        uniform.color = tintColor
    }
}
