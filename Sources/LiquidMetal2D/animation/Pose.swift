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

    /// Copies every bone from `other` in place, without reallocating.
    public mutating func copyValues(from other: Pose) {
        precondition(
            other.local.count == local.count,
            "Copying a pose of \(other.local.count) bones into one of \(local.count)")
        for index in local.indices {
            local[index] = other.local[index]
        }
    }

    /// Sets this pose part way from `a` to `b`: positions blend linearly,
    /// rotations the short way round.
    ///
    /// At `t <= 0` and `t >= 1` the ends are copied exactly, so a full-weight
    /// blend hands back a key of 4 rad as 4, not as the equivalent -2.28.
    public mutating func setBlend(from a: Pose, to b: Pose, t: Float) {
        precondition(
            a.local.count == local.count && b.local.count == local.count,
            "Blending poses of different sizes: \(a.local.count), \(b.local.count) into \(local.count)")
        if t <= 0 {
            copyValues(from: a)
            return
        }
        if t >= 1 {
            copyValues(from: b)
            return
        }
        for index in local.indices {
            local[index] = RigidTransform2D(
                position: GameMath.lerp(a: a.local[index].position, b: b.local[index].position, t: t),
                rotation: GameMath.lerpAngle(a: a.local[index].rotation, b: b.local[index].rotation, t: t))
        }
    }
}
