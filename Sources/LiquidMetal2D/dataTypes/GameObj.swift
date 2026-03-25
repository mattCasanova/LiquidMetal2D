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

    private var components = [AnyHashable: Component]()

    public init() {}

    /// Adds a component stored under the given key. One component per key.
    public func add(_ key: some Hashable, _ component: Component) {
        components[AnyHashable(key)] = component
    }

    /// Returns the component stored under the given key.
    public func get(_ key: some Hashable) -> Component? {
        components[AnyHashable(key)]
    }

    /// Returns the component stored under the given key, cast to the specified type.
    public func get<T: Component>(_ key: some Hashable, as type: T.Type) -> T? {
        components[AnyHashable(key)] as? T
    }

    /// Removes the component stored under the given key.
    public func remove(_ key: some Hashable) {
        components.removeValue(forKey: AnyHashable(key))
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
