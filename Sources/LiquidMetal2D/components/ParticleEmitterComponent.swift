//
//  ParticleEmitterComponent.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Foundation

/// Region from which new particles spawn, expressed relative to the
/// emitter's ``ParticleEmitterComponent/localOffset``. The sampled offset
/// is added to `localOffset` and the result is rotated by `parent.rotation`,
/// so the shape rotates with its parent like the rest of the emit transform.
public enum EmitterShape: Sendable {
    /// All particles spawn at `localOffset` (the historical default).
    case point
    /// Uniform sample on the segment from `from` to `to`, with both
    /// endpoints expressed as deltas from `localOffset`.
    case line(from: Vec2, to: Vec2)
    /// Uniform sample inside an axis-aligned rectangle of the given
    /// half-extents, centered on `localOffset`.
    case box(halfExtents: Vec2)
    /// Uniform sample inside a disc of the given radius, centered on
    /// `localOffset`.
    case circle(radius: Float)
}

/// A CPU-driven particle emitter. Owns a pre-allocated pool of ``Particle``
/// values; ``ParticleShader`` walks emitters each frame and renders each
/// emitter's live particles.
///
/// Scene-driven update: call ``update(dt:)`` from your scene's `update(dt:)`
/// loop, the same way behaviors are dispatched.
///
/// Emit point is `parent.position + rotate(localOffset + shapeSample, parent.rotation)` —
/// attach the component to a moving GameObj (ship, character, weapon) and
/// the emitter follows automatically. Use ``shape`` to spread spawns across
/// a line, box, or disc instead of a single point.
public final class ParticleEmitterComponent: Component {
    public unowned var parent: GameObj

    // MARK: - Config

    /// Pool size. Pre-allocated at init; hard cap on simultaneously-alive particles.
    public let maxParticles: Int
    /// Texture sampled by each particle — pass `renderer.defaultParticleTextureId`
    /// for the built-in soft-circle, or supply your own.
    public var textureID: Int
    /// Particles per second. Set `isEmitting = false` to pause.
    public var emissionRate: Float
    /// Position of the emit point relative to `parent.position`. Rotated by
    /// `parent.rotation` at spawn time. The ``shape`` sample is added to
    /// this before rotation.
    public var localOffset: Vec2
    /// Region from which particles spawn. Defaults to ``EmitterShape/point``,
    /// matching the historical single-point behavior.
    public var shape: EmitterShape
    /// Random particle lifetime range (seconds).
    public var lifetimeRange: ClosedRange<Float>
    /// Random initial speed range.
    public var speedRange: ClosedRange<Float>
    /// Random spawn angle range (radians), added to `parent.rotation`.
    public var angleRange: ClosedRange<Float>
    /// Random start-scale range (scale at age = 0). Each particle picks a
    /// random uniform value from this range at spawn.
    public var scaleRange: ClosedRange<Float>
    /// Optional random end-scale range (scale at age = lifetime). When nil
    /// the particle keeps its start scale for its whole life (today's
    /// behavior). When set, each particle also picks a random value from
    /// this range at spawn and the shader lerps start→end per frame.
    public var endScaleRange: ClosedRange<Float>?
    /// Random angular velocity range (radians/sec).
    public var angularVelocityRange: ClosedRange<Float>
    /// Color at spawn (age = 0).
    public var startColor: Vec4
    /// Optional second endpoint for random start-color variation. When nil,
    /// every particle starts at `startColor` (today's behavior). When set,
    /// each particle picks a random `t` at spawn and lerps between
    /// `startColor` and this value. Same `t` is reused for `endColor` so
    /// a particle's whole life stays on a consistent gradient lane.
    public var startColorVariation: Vec4?
    /// Color at death (age = lifetime). Alpha typically fades to 0 for smooth pop-out.
    public var endColor: Vec4
    /// Optional second endpoint for random end-color variation (see
    /// ``startColorVariation``). By default the same random `t` picked for
    /// the start color is applied here — flip ``correlatedColorVariation``
    /// to `false` to make start/end rolls independent.
    public var endColorVariation: Vec4?
    /// When `true` (default), a single random `t` is used for both the
    /// start- and end-color variation lerps, so each particle stays on a
    /// consistent gradient lane through its life. Set `false` to roll
    /// two independent `t`s — particles get scrambled start/end pairings,
    /// which is often desirable for chaotic magic / spark effects.
    public var correlatedColorVariation: Bool = true
    /// Acceleration applied to every live particle each frame.
    public var gravity: Vec2
    /// Whether new particles are being spawned. Existing particles keep
    /// updating regardless.
    public var isEmitting: Bool = true

    // MARK: - State

    /// Particle pool. Public read-only so ``ParticleShader`` can iterate.
    public private(set) var particles: [Particle]
    private var timeToNextSpawn: Float = 0

    public init(
        parent: GameObj,
        maxParticles: Int,
        textureID: Int,
        emissionRate: Float = 60,
        localOffset: Vec2 = Vec2(),
        shape: EmitterShape = .point,
        lifetimeRange: ClosedRange<Float> = 0.5...1.5,
        speedRange: ClosedRange<Float> = 2...5,
        angleRange: ClosedRange<Float> = -0.3...0.3,
        scaleRange: ClosedRange<Float> = 0.5...1.0,
        endScaleRange: ClosedRange<Float>? = nil,
        angularVelocityRange: ClosedRange<Float> = 0...0,
        startColor: Vec4 = Vec4(1, 1, 1, 1),
        startColorVariation: Vec4? = nil,
        endColor: Vec4 = Vec4(1, 1, 1, 0),
        endColorVariation: Vec4? = nil,
        correlatedColorVariation: Bool = true,
        gravity: Vec2 = Vec2()
    ) {
        self.parent = parent
        self.maxParticles = maxParticles
        self.textureID = textureID
        self.emissionRate = emissionRate
        self.localOffset = localOffset
        self.shape = shape
        self.lifetimeRange = lifetimeRange
        self.speedRange = speedRange
        self.angleRange = angleRange
        self.scaleRange = scaleRange
        self.endScaleRange = endScaleRange
        self.angularVelocityRange = angularVelocityRange
        self.startColor = startColor
        self.startColorVariation = startColorVariation
        self.endColor = endColor
        self.endColorVariation = endColorVariation
        self.correlatedColorVariation = correlatedColorVariation
        self.gravity = gravity
        self.particles = Array(repeating: Particle.dead, count: maxParticles)
    }

    // MARK: - Update

    /// Advance every live particle by `dt` and spawn new particles to meet
    /// the emission rate. Scene should call this once per frame from its
    /// `update(dt:)` method.
    public func update(dt: Float) {
        for index in 0..<particles.count where particles[index].isAlive {
            particles[index].age += dt
            particles[index].velocity += gravity * dt
            particles[index].position += particles[index].velocity * dt
            particles[index].rotation += particles[index].angularVelocity * dt
        }

        guard isEmitting, emissionRate > 0 else { return }
        let spawnInterval = 1 / emissionRate
        timeToNextSpawn -= dt
        while timeToNextSpawn <= 0 {
            spawnOne()
            timeToNextSpawn += spawnInterval
        }
    }

    /// Burst: spawn `count` particles immediately, regardless of emission rate.
    public func spawn(count: Int) {
        for _ in 0..<count { spawnOne() }
    }

    // MARK: - Private

    private func spawnOne() {
        guard let index = firstDeadIndex() else { return }

        let worldPos = parent.position + rotate(localOffset + sampleShape(), angle: parent.rotation)
        let angle = Float.random(in: angleRange) + parent.rotation
        let speed = Float.random(in: speedRange)
        let startUniform = Float.random(in: scaleRange)
        let endUniform = endScaleRange.map { Float.random(in: $0) } ?? startUniform

        // Correlated mode (default): one random t used for both start and
        // end color lerps, so each particle stays on a consistent gradient
        // lane. Independent mode (correlatedColorVariation = false): two
        // independent rolls, producing scrambled start/end pairings for a
        // more chaotic look.
        let startT = Float.random(in: 0...1)
        let endT = correlatedColorVariation ? startT : Float.random(in: 0...1)
        let sColor = startColorVariation.map { lerp(startColor, $0, t: startT) } ?? startColor
        let eColor = endColorVariation.map { lerp(endColor, $0, t: endT) } ?? endColor

        var velocity = Vec2()
        velocity.set(angle: angle)
        velocity *= speed

        particles[index] = Particle(
            position: worldPos,
            velocity: velocity,
            rotation: angle,
            angularVelocity: Float.random(in: angularVelocityRange),
            startScale: Vec2(startUniform, startUniform),
            endScale: Vec2(endUniform, endUniform),
            startColor: sColor,
            endColor: eColor,
            age: 0,
            lifetime: Float.random(in: lifetimeRange))
    }

    private func lerp(_ a: Vec4, _ b: Vec4, t: Float) -> Vec4 {
        return a + (b - a) * t
    }

    private func firstDeadIndex() -> Int? {
        for index in 0..<particles.count where !particles[index].isAlive {
            return index
        }
        return nil
    }

    private func rotate(_ v: Vec2, angle: Float) -> Vec2 {
        let c = cos(angle)
        let s = sin(angle)
        return Vec2(v.x * c - v.y * s, v.x * s + v.y * c)
    }

    private func sampleShape() -> Vec2 {
        switch shape {
        case .point:
            return Vec2()
        case .line(let from, let to):
            let t = Float.random(in: 0...1)
            return from + (to - from) * t
        case .box(let halfExtents):
            return Vec2(
                Float.random(in: -halfExtents.x...halfExtents.x),
                Float.random(in: -halfExtents.y...halfExtents.y))
        case .circle(let radius):
            // Uniform disc: sqrt(random) gives uniform area distribution.
            let r = radius * sqrt(Float.random(in: 0...1))
            let theta = Float.random(in: 0...(2 * .pi))
            return Vec2(r * cos(theta), r * sin(theta))
        }
    }
}
