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
    public unowned var parent: GameObj
    public let definition: SkeletonDefinition
    public let animator: Animator
    /// One drawn object per attachment, in the rig's attachment order.
    public let parts: [GameObj]

    /// Uniform size multiplier for the whole figure.
    public var scale: Float = 1
    /// Mirrors the figure left to right about the root. Rigs face +x.
    public var flipX = false

    /// World-z step between draw orders. Small enough that perspective
    /// size changes are invisible; keep a character's parts within ±0.05 of its root.
    public static let zStep: Float = 0.001

    private var boneWorld: [RigidTransform2D]
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

    /// Advances the animation and moves every part to match.
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

    private func placeParts() {
        SkeletonSolver.solveWorld(
            definition: definition, pose: animator.pose, root: .identity, into: &boneWorld)

        for (index, attachment) in definition.attachments.enumerated() {
            let part = parts[index]
            let bone = boneWorld[attachment.bone]
            let centre = (bone.position + attachment.offset.rotated(by: bone.rotation)) * scale
            let placed = placeInWorld(RigidTransform2D(
                position: centre, rotation: bone.rotation + attachment.rotation))

            part.position = placed.position
            part.rotation = placed.rotation
            part.scale = Vec2(attachment.size.x, flipX ? -attachment.size.y : attachment.size.y) * scale
            part.zOrder = parent.zOrder + Float(attachment.drawOrder) * Self.zStep
            part.isActive = parent.isActive && visible[index]
        }
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
