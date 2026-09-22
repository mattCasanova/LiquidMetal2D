//
//  Pose.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

/// Each bone's local transform at one moment. One entry per bone, in the
/// same order as ``SkeletonDefinition/bones``.
///
/// Sized once from a definition; every mutating call writes in place, so
/// animating a pose each frame allocates nothing.
public struct Pose: Equatable, Sendable {
    public var local: [RigidTransform2D]

    /// A pose with every bone at its rest transform.
    public init(restOf definition: SkeletonDefinition) {
        local = definition.bones.map(\.rest)
    }

    /// Puts every bone back at its rest transform.
    public mutating func reset(to definition: SkeletonDefinition) {
        precondition(
            local.count == definition.bones.count,
            "Pose has \(local.count) bones but the definition has \(definition.bones.count)")
        for index in local.indices {
            local[index] = definition.bones[index].rest
        }
    }

    /// Sets this pose part way from `a` to `b`: positions blend linearly,
    /// rotations the short way round.
    public mutating func setBlend(from a: Pose, to b: Pose, t: Float) {
        precondition(
            a.local.count == local.count && b.local.count == local.count,
            "Blending poses of different sizes: \(a.local.count), \(b.local.count) into \(local.count)")
        for index in local.indices {
            local[index] = RigidTransform2D(
                position: GameMath.lerp(a: a.local[index].position, b: b.local[index].position, t: t),
                rotation: GameMath.lerpAngle(a: a.local[index].rotation, b: b.local[index].rotation, t: t))
        }
    }
}
