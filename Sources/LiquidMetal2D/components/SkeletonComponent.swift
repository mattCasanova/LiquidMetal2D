//
//  SkeletonComponent.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

import Foundation

/// Puts an animated skeleton on a ``GameObj``.
///
/// The object this is attached to is the skeleton's root: its `position`,
/// `rotation`, `zOrder` and `isActive` place the whole figure. It is never
/// drawn itself. Each ``Attachment`` in the rig becomes one ordinary
/// ``GameObj`` in ``parts``, carrying an ``AlphaBlendComponent``; every
/// ``update(dt:)`` writes those parts' position, rotation, scale and zOrder.
/// Submit the parts with the rest of the scene:
///
/// ```swift
/// skeleton.update(dt: dt)
/// renderer.submit(objects: world + skeleton.parts)
/// ```
///
/// Size the figure with ``scale``, not the root object's `scale` — a fresh
/// `GameObj` has a scale of (0, 0), and the root is not drawn anyway.
public final class SkeletonComponent: Component {
    public unowned let parent: GameObj
    public let definition: SkeletonDefinition
    public let animator: Animator
    /// One drawn object per attachment, in the rig's attachment order.
    public let parts: [GameObj]

    /// Uniform size multiplier for the whole figure.
    public var scale: Float = 1
    /// Mirrors the figure left to right about the root. Rigs face +x.
    public var flipX = false
    /// Two-bone IK chains, applied in order on top of the animation every
    /// ``update(dt:)``. The animator's own pose is left as the clips made it.
    /// Move a target in place (`ikConstraints[0].target = touch`); that
    /// doesn't allocate.
    public var ikConstraints: [IKConstraint] = []

    /// World-z step between draw orders. Small enough that perspective
    /// size changes are invisible; keep a character's parts within ±0.05 of its root.
    public static let zStep: Float = 0.001

    private var boneWorld: [RigidTransform2D]
    /// The animated pose with IK applied. Only used while there are constraints.
    private var ikPose: Pose
    /// One flag per attachment. Hiding a part only stops it drawing; the bones keep animating.
    private var visible: [Bool]

    /// - Parameters:
    ///   - defaultTextureID: Used for attachments with no `textureName` —
    ///     normally `renderer.defaultTextureId`, the 1×1 white texture.
    ///   - textureIDs: Texture ID for each `textureName` the rig uses.
    ///   - layerCount: Animator layers; 2 covers a base clip plus one override.
    /// - Throws: ``SkeletonError`` if the rig is invalid or names a texture
    ///   missing from `textureIDs`.
    public init(
        parent: GameObj,
        definition: SkeletonDefinition,
        defaultTextureID: Int,
        textureIDs: [String: Int] = [:],
        layerCount: Int = 2
    ) throws {
        try definition.validate()

        self.parent = parent
        self.definition = definition
        self.animator = Animator(definition: definition, layerCount: layerCount)
        self.boneWorld = Array(repeating: .identity, count: definition.bones.count)
        self.ikPose = Pose(restOf: definition)
        self.visible = Array(repeating: true, count: definition.attachments.count)

        self.parts = try definition.attachments.map { attachment in
            let textureID: Int
            if let name = attachment.textureName {
                guard let id = textureIDs[name] else { throw SkeletonError.unknownTexture(name) }
                textureID = id
            } else {
                textureID = defaultTextureID
            }

            let part = GameObj()
            part.add(AlphaBlendComponent(
                parent: part, textureID: textureID,
                tintColor: attachment.tint, texTrans: attachment.region))
            return part
        }

        placeParts()
    }

    /// Advances the animation, applies ``ikConstraints``, and moves every part to match.
    public func update(dt: Float) {
        animator.update(dt: dt)
        placeParts()
    }

    /// Where bone `index` is in the world after the last update, with scale,
    /// flip and the root applied. The bone's tip is `apply(to: Vec2(length * scale, 0))`.
    /// Use it for muzzle points, hit tests, or placing an object in a hand.
    public func worldTransform(ofBone index: Int) -> RigidTransform2D {
        precondition(boneWorld.indices.contains(index),
                     "Rig has \(boneWorld.count) bones; there is no bone \(index)")
        return placeInWorld(RigidTransform2D(
            position: boneWorld[index].position * scale,
            rotation: boneWorld[index].rotation))
    }

    // MARK: - Visibility

    /// Shows or hides one part — a sword that has been thrown, a sheathed weapon.
    /// Takes effect at once. The part still follows its bone while hidden.
    public func setVisible(_ isVisible: Bool, attachment index: Int) {
        precondition(visible.indices.contains(index),
                     "Rig has \(visible.count) attachments; there is no attachment \(index)")
        visible[index] = isVisible
        parts[index].isActive = parent.isActive && isVisible
    }

    /// Shows or hides one part by attachment name.
    public func setVisible(_ isVisible: Bool, attachment name: String) throws {
        setVisible(isVisible, attachment: try definition.attachmentIndex(named: name))
    }

    public func isVisible(attachment index: Int) -> Bool {
        precondition(visible.indices.contains(index),
                     "Rig has \(visible.count) attachments; there is no attachment \(index)")
        return visible[index]
    }

    // MARK: - Placement

    /// Places the parts from `pose` right now, bypassing the animator and
    /// the IK constraints: for a tool that samples or edits poses itself.
    /// The next ``update(dt:)`` places them from the animator again.
    public func place(pose: Pose) {
        precondition(pose.local.count == definition.bones.count,
                     "Pose has \(pose.local.count) bones; the rig has \(definition.bones.count)")
        SkeletonSolver.solveWorld(definition: definition, pose: pose, root: .identity, into: &boneWorld)
        layOutParts()
    }

    private func placeParts() {
        if ikConstraints.isEmpty {
            SkeletonSolver.solveWorld(
                definition: definition, pose: animator.pose, root: .identity, into: &boneWorld)
        } else {
            solveWithIK()
        }
        layOutParts()
    }

    /// Every part at its bone's place in `boneWorld`.
    private func layOutParts() {
        for (index, attachment) in definition.attachments.enumerated() {
            let part = parts[index]
            let bone = boneWorld[attachment.bone]
            let centre = (bone.position + attachment.offset.rotated(by: bone.rotation)) * scale
            let placed = placeInWorld(RigidTransform2D(
                position: centre, rotation: bone.rotation + attachment.rotation))

            part.transform = Transform2D(
                placed,
                scale: Vec2(attachment.size.x, flipX ? -attachment.size.y : attachment.size.y) * scale,
                zOrder: parent.zOrder + Float(attachment.drawOrder) * Self.zStep)
            part.isActive = parent.isActive && visible[index]
        }
    }

    // MARK: - IK

    /// Solves the bones once per constraint, since each chain starts where the
    /// chains before it left its parent, then once more for the parts. A
    /// dozen bones per solve: nothing next to drawing them.
    private func solveWithIK() {
        ikPose.copyValues(from: animator.pose)
        for constraint in ikConstraints {
            SkeletonSolver.solveWorld(definition: definition, pose: ikPose, root: .identity, into: &boneWorld)
            apply(constraint)
        }
        SkeletonSolver.solveWorld(definition: definition, pose: ikPose, root: .identity, into: &boneWorld)
    }

    /// Rotates the chain's two bones in ``ikPose``, working in skeleton space
    /// (unscaled, unflipped, root at the origin) like the rest of the solve.
    private func apply(_ constraint: IKConstraint) {
        guard constraint.weight > 0 else { return }
        precondition(boneWorld.indices.contains(constraint.upper) && boneWorld.indices.contains(constraint.lower),
                     "IK constraint on bones \(constraint.upper) and \(constraint.lower); "
                        + "this rig has \(boneWorld.count). Was it built for another rig?")

        // The lower bone's joint, in the upper bone's space. It usually sits at
        // (upper length, 0); if it sits off that axis, turn the upper bone so
        // the joint still lands on the solved line.
        let joint = ikPose.local[constraint.lower].position
        let jointAngle = atan2(joint.y, joint.x)
        let solved = TwoBoneIK.solve(
            root: boneWorld[constraint.upper].position,
            upperLength: simd_length(joint),
            lowerLength: definition.bones[constraint.lower].length,
            target: skeletonSpace(constraint.target),
            bendPositive: constraint.bendPositive)
        let parentRotation = definition.bones[constraint.upper].parent.map { boneWorld[$0].rotation } ?? 0

        blend(bone: constraint.upper, to: solved.upper - jointAngle - parentRotation, weight: constraint.weight)
        blend(bone: constraint.lower, to: solved.lowerLocal + jointAngle, weight: constraint.weight)
    }

    private func blend(bone: Int, to rotation: Float, weight: Float) {
        let animated = ikPose.local[bone].rotation
        ikPose.local[bone].rotation = weight >= 1
            ? rotation
            : GameMath.lerpAngle(a: animated, b: rotation, t: weight)
    }

    /// World to skeleton space, the inverse of ``placeInWorld(_:)``: undo the
    /// root, mirror back if flipped, undo the scale.
    private func skeletonSpace(_ world: Vec2) -> Vec2 {
        precondition(scale != 0, "IK can't map a target onto a skeleton of scale 0")
        var local = (world - parent.position).rotated(by: -parent.rotation)
        if flipX {
            local.x = -local.x
        }
        return local / scale
    }

    /// Skeleton space to world: mirror if flipped, then the root's rotation and position.
    ///
    /// Mirroring a quad drawn with rotation θ and scale (sx, sy) gives rotation
    /// π − θ with scale (sx, −sy); ``placeParts()`` negates the y scale.
    private func placeInWorld(_ local: RigidTransform2D) -> RigidTransform2D {
        var position = local.position
        var rotation = local.rotation
        if flipX {
            position.x = -position.x
            rotation = GameMath.pi - rotation
        }
        return RigidTransform2D(
            position: parent.position + position.rotated(by: parent.rotation),
            rotation: rotation + parent.rotation)
    }
}
