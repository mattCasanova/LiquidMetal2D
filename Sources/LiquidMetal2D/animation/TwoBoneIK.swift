//
//  TwoBoneIK.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/29/26.
//

import Foundation

/// Puts the tip of a two-bone chain (upper arm and forearm, thigh and shin)
/// on a world point; the middle joint bends to fit.
///
/// Add it to ``SkeletonComponent/ikConstraints``. Building one checks the
/// bones against the rig once, so a bad pair fails here with a named error
/// rather than every frame. Move the target in place each frame
/// (`skeleton.ikConstraints[0].target = touch`); that doesn't allocate.
public struct IKConstraint: Equatable, Sendable {
    /// The first bone of the chain (upper arm, thigh).
    public let upper: Int
    /// The second bone (forearm, shin), a child of `upper`. Its tip is what
    /// reaches the target.
    public let lower: Int
    /// Where the tip of `lower` should go, in world space.
    public var target: Vec2
    /// Which way the middle joint bends, in the rig's own space (rigs face
    /// +x): `true` puts it counter-clockwise of the line from the chain's root
    /// to the target. `flipX` mirrors it with the rest of the figure, so an
    /// elbow keeps bending the same way.
    public var bendPositive: Bool
    /// How much IK overrides the animation, 0 (animation only) to 1 (IK only).
    /// In between, each bone's rotation blends the short way round.
    public var weight: Float

    /// - Throws: ``SkeletonError/ikBonesNotChained(upper:lower:)`` if `lower`'s
    ///   parent isn't `upper`; ``SkeletonError/ikBoneHasNoLength(_:)`` if either
    ///   segment is zero long.
    public init(
        upper: Int, lower: Int, in definition: SkeletonDefinition,
        target: Vec2 = Vec2(), bendPositive: Bool = true, weight: Float = 1
    ) throws {
        precondition(definition.bones.indices.contains(upper) && definition.bones.indices.contains(lower),
                     "Rig has \(definition.bones.count) bones; there is no bone \(upper) or \(lower)")
        let upperBone = definition.bones[upper]
        let lowerBone = definition.bones[lower]
        guard lowerBone.parent == upper else {
            throw SkeletonError.ikBonesNotChained(upper: upperBone.name, lower: lowerBone.name)
        }
        // The upper segment runs from the upper bone's origin to the lower bone's joint.
        guard simd_length(lowerBone.rest.position) > 0 else { throw SkeletonError.ikBoneHasNoLength(upperBone.name) }
        guard lowerBone.length > 0 else { throw SkeletonError.ikBoneHasNoLength(lowerBone.name) }

        self.upper = upper
        self.lower = lower
        self.target = target
        self.bendPositive = bendPositive
        self.weight = weight
    }

    /// The same, naming the bones.
    /// - Throws: ``SkeletonError/unknownBone(_:)`` for a name the rig lacks,
    ///   and the errors of the index form.
    public init(
        upper: String, lower: String, in definition: SkeletonDefinition,
        target: Vec2 = Vec2(), bendPositive: Bool = true, weight: Float = 1
    ) throws {
        try self.init(
            upper: try definition.boneIndex(named: upper), lower: try definition.boneIndex(named: lower),
            in: definition, target: target, bendPositive: bendPositive, weight: weight)
    }
}

/// The two-bone IK solve, in any one space. ``SkeletonComponent`` calls it
/// for each ``IKConstraint``; a posing tool can call it directly.
public enum TwoBoneIK {

    /// Angles that put the end of a two-segment chain starting at `root` on
    /// `target`: the first segment's direction, and the second's angle
    /// relative to the first. A target out of reach gets a straight chain
    /// pointing at it; one too close, the nearest point the chain can reach
    /// in its direction. Never NaN, including a target on the root.
    public static func solve(
        root: Vec2, upperLength: Float, lowerLength: Float, target: Vec2, bendPositive: Bool
    ) -> (upper: Float, lowerLocal: Float) {
        precondition(upperLength > 0 && lowerLength > 0,
                     "Two-bone IK needs segments longer than zero, got \(upperLength) and \(lowerLength)")
        let toTarget = target - root
        let distance = simd_length(toTarget)
        let direction = distance > 0 ? atan2(toTarget.y, toTarget.x) : 0

        // With equal segments the nearest reach is 0; the floor keeps the division below finite.
        let nearest = max(abs(upperLength - lowerLength), (upperLength + lowerLength) * 1e-6)
        let reach = GameMath.clamp(value: distance, low: nearest, high: upperLength + lowerLength)

        // Law of cosines: the angle at the root between the target line and the
        // first segment, and the angle inside the middle joint. Rounding can
        // push the ratios just past ±1 at full or nearest reach.
        let cosAtRoot = (upperLength * upperLength + reach * reach - lowerLength * lowerLength)
            / (2 * upperLength * reach)
        let cosAtJoint = (upperLength * upperLength + lowerLength * lowerLength - reach * reach)
            / (2 * upperLength * lowerLength)
        let atRoot = acos(GameMath.clamp(value: cosAtRoot, low: -1, high: 1))
        let atJoint = acos(GameMath.clamp(value: cosAtJoint, low: -1, high: 1))

        let side: Float = bendPositive ? 1 : -1
        return (direction + side * atRoot, -side * (GameMath.pi - atJoint))
    }
}
