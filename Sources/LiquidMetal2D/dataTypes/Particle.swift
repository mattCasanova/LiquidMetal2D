//
//  Particle.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

/// A single particle in a ``ParticleEmitterComponent`` pool. Pure value type
/// stored inline in the emitter's array — no GameObj or component-bag
/// overhead. Transformed into a GPU uniform by ``ParticleShader`` each frame.
public struct Particle: Sendable {
    public var position: Vec2
    public var velocity: Vec2
    public var rotation: Float
    public var angularVelocity: Float
    public var scale: Vec2
    public var startColor: Vec4
    public var endColor: Vec4
    public var age: Float
    public var lifetime: Float

    /// A particle is alive while its age has not reached its lifetime. Dead
    /// slots are candidates for re-use on the next spawn.
    public var isAlive: Bool { age < lifetime }

    /// A particle in the "dead" state. Emitters initialize their pool with
    /// this value so every slot starts reusable.
    public static let dead = Particle(
        position: Vec2(),
        velocity: Vec2(),
        rotation: 0,
        angularVelocity: 0,
        scale: Vec2(1, 1),
        startColor: Vec4(1, 1, 1, 1),
        endColor: Vec4(1, 1, 1, 0),
        age: 1,
        lifetime: 0)

    public init(
        position: Vec2 = Vec2(),
        velocity: Vec2 = Vec2(),
        rotation: Float = 0,
        angularVelocity: Float = 0,
        scale: Vec2 = Vec2(1, 1),
        startColor: Vec4 = Vec4(1, 1, 1, 1),
        endColor: Vec4 = Vec4(1, 1, 1, 0),
        age: Float = 0,
        lifetime: Float = 1
    ) {
        self.position = position
        self.velocity = velocity
        self.rotation = rotation
        self.angularVelocity = angularVelocity
        self.scale = scale
        self.startColor = startColor
        self.endColor = endColor
        self.age = age
        self.lifetime = lifetime
    }
}
