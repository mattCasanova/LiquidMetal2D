//
//  PoseSampler.swift
//  MotionatorKit
//
//  Created by Matt Casanova on 10/6/26.
//

import Foundation
import LiquidMetal2D

/// A two-bone chain for IK: a hand is `lower`'s tip.
public struct IKChain: Hashable, Sendable {
    public var upper: Int
    public var lower: Int

    public init(upper: Int, lower: Int) {
        self.upper = upper
        self.lower = lower
    }
}

/// What the viewport and the timeline need from a pose: joints in the rig's
/// space, hit tests, and the IK solve as plain functions.
public enum PoseSampler {
    /// Every bone's transform in the rig's space (root at the origin).
    public static func worldTransforms(rig: SkeletonDefinition, pose: Pose) -> [RigidTransform2D] {
        var world = [RigidTransform2D](repeating: .identity, count: rig.bones.count)
        SkeletonSolver.solveWorld(definition: rig, pose: pose, root: .identity, into: &world)
        return world
    }

    public static func joint(of bone: Int, world: [RigidTransform2D]) -> Vec2 { world[bone].position }

    public static func tip(of bone: Int, rig: SkeletonDefinition, world: [RigidTransform2D]) -> Vec2 {
        world[bone].apply(to: Vec2(rig.bones[bone].length, 0))
    }

    /// The bone whose segment is nearest `point`, within `tolerance`. Where
    /// two lie on top of each other (the near and far legs at rest), the one
    /// drawn on top wins: it is the one the user sees.
    public static func bone(
        near point: Vec2, rig: SkeletonDefinition, world: [RigidTransform2D], tolerance: Float
    ) -> Int? {
        bones(near: point, rig: rig, world: world, tolerance: tolerance).first
    }

    /// Every bone within `tolerance` of `point`, nearest first, the one
    /// drawn on top first among equals: what a click can cycle through.
    public static func bones(
        near point: Vec2, rig: SkeletonDefinition, world: [RigidTransform2D], tolerance: Float
    ) -> [Int] {
        var hits: [(index: Int, distance: Float)] = []
        for index in rig.bones.indices {
            let distance = distanceToSegment(
                point, joint(of: index, world: world), tip(of: index, rig: rig, world: world))
            if distance <= tolerance { hits.append((index, distance)) }
        }
        hits.sort { isNearer($0.distance, $0.index, than: $1.distance, $1.index, rig: rig) }
        return hits.map(\.index)
    }

    /// A chain whose tip (a hand, a foot, the top of the head) is within
    /// `tolerance` of `point`: a bone with a parent and no children.
    public static func chainTip(
        near point: Vec2, rig: SkeletonDefinition, world: [RigidTransform2D], tolerance: Float
    ) -> IKChain? {
        var best: (chain: IKChain, distance: Float)?
        for (index, bone) in rig.bones.enumerated() {
            guard let parent = bone.parent, !rig.bones.contains(where: { $0.parent == index }) else { continue }
            let distance = simd_length(tip(of: index, rig: rig, world: world) - point)
            guard distance <= tolerance else { continue }
            if let current = best, !isNearer(distance, index, than: current.distance, current.chain.lower, rig: rig) {
                continue
            }
            best = (IKChain(upper: parent, lower: index), distance)
        }
        return best?.chain
    }

    /// Closer wins; at the same distance the bone whose parts draw later wins.
    private static func isNearer(
        _ distance: Float, _ bone: Int, than otherDistance: Float, _ other: Int, rig: SkeletonDefinition
    ) -> Bool {
        if abs(distance - otherDistance) > 1e-5 { return distance < otherDistance }
        return drawRank(of: bone, rig: rig) > drawRank(of: other, rig: rig)
    }

    /// The highest draw order of the bone's parts; -1 for a bone with none.
    static func drawRank(of bone: Int, rig: SkeletonDefinition) -> Int {
        var rank = -1
        for attachment in rig.attachments where attachment.bone == bone {
            rank = max(rank, attachment.drawOrder)
        }
        return rank
    }

    /// Local rotations for the chain's two bones that put the tip on
    /// `target` (or as near as the chain reaches), the same arithmetic as
    /// `SkeletonComponent`'s IK constraints.
    public static func rotationsReaching(
        _ target: Vec2, chain: IKChain, rig: SkeletonDefinition, pose: Pose, bendPositive: Bool
    ) -> (upper: Float, lower: Float) {
        let world = worldTransforms(rig: rig, pose: pose)
        let joint = pose.local[chain.lower].position
        let jointAngle = atan2(joint.y, joint.x)
        let solved = TwoBoneIK.solve(
            root: world[chain.upper].position,
            upperLength: simd_length(joint),
            lowerLength: rig.bones[chain.lower].length,
            target: target,
            bendPositive: bendPositive)
        let parentRotation = rig.bones[chain.upper].parent.map { world[$0].rotation } ?? 0
        return (solved.upper - jointAngle - parentRotation, solved.lowerLocal + jointAngle)
    }

    /// The local rotation that points `bone` from its joint at `point`.
    public static func rotationPointing(
        bone: Int, at point: Vec2, rig: SkeletonDefinition, world: [RigidTransform2D]
    ) -> Float {
        let toPoint = point - joint(of: bone, world: world)
        let parentRotation = rig.bones[bone].parent.map { world[$0].rotation } ?? 0
        return atan2(toPoint.y, toPoint.x) - parentRotation
    }

    /// Whether the chain bends the positive way in `pose`, so a drag keeps
    /// the elbow or knee on the side it is.
    public static func bendsPositive(chain: IKChain, rig: SkeletonDefinition, pose: Pose) -> Bool {
        pose.local[chain.lower].rotation >= 0
    }

    static func distanceToSegment(_ point: Vec2, _ start: Vec2, _ end: Vec2) -> Float {
        let edge = end - start
        let lengthSquared = simd_length_squared(edge)
        guard lengthSquared > 0 else { return simd_length(point - start) }
        let fraction = GameMath.clamp(value: simd_dot(point - start, edge) / lengthSquared, low: 0, high: 1)
        return simd_length(point - (start + edge * fraction))
    }
}
