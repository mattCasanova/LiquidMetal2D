//
//  SkeletonSolver.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

/// Turns a pose's local bone transforms into world transforms.
public enum SkeletonSolver {

    /// Fills `world` with one transform per bone. `root` places the whole
    /// skeleton; a bone with no parent hangs off it.
    ///
    /// One forward loop, which relies on ``SkeletonDefinition/validate()``
    /// having checked that parents come before children.
    public static func solveWorld(
        definition: SkeletonDefinition,
        pose: Pose,
        root: RigidTransform2D,
        into world: inout [RigidTransform2D]
    ) {
        precondition(
            pose.local.count == definition.bones.count && world.count == definition.bones.count,
            "solveWorld sizes differ: \(definition.bones.count) bones, "
                + "\(pose.local.count) in the pose, \(world.count) in the output")

        for (index, bone) in definition.bones.enumerated() {
            let parentWorld = bone.parent.map { world[$0] } ?? root
            world[index] = parentWorld.composed(with: pose.local[index])
        }
    }
}
