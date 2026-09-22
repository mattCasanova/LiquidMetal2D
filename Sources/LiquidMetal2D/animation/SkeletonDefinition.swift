//
//  SkeletonDefinition.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

/// One bone in a ``SkeletonDefinition``.
///
/// A bone points along its own +x axis. `rest.position` is measured in the
/// parent bone's space from the parent's origin, so a child hung off the tip
/// of its parent has `rest.position == Vec2(parentLength, 0)`.
public struct Bone: Codable, Equatable, Sendable {
    public var name: String
    /// Index of the parent bone in ``SkeletonDefinition/bones``, or `nil` for a root.
    /// Must be lower than this bone's own index.
    public var parent: Int?
    public var length: Float
    /// The bone's local transform in the rest pose.
    public var rest: RigidTransform2D

    public init(name: String, parent: Int?, length: Float, rest: RigidTransform2D) {
        self.name = name
        self.parent = parent
        self.length = length
        self.rest = rest
    }
}

/// A drawn quad pinned to a bone.
public struct Attachment: Codable, Equatable, Sendable {
    public var name: String
    /// Index of the bone this quad follows.
    public var bone: Int
    /// Quad size in world units, before the skeleton's scale.
    public var size: Vec2
    /// Quad centre in bone space. A box that runs along the bone uses `Vec2(length / 2, 0)`.
    public var offset: Vec2
    /// Extra rotation relative to the bone, usually 0.
    public var rotation: Float
    /// Texture to draw with; `nil` means the engine's default white texture.
    public var textureName: String?
    /// Texture region as `texTrans` (scaleU, scaleV, offsetU, offsetV). The whole texture is `(1, 1, 0, 0)`.
    public var region: Vec4
    public var tint: Vec4
    /// Higher draws later, on top.
    public var drawOrder: Int

    public init(
        name: String,
        bone: Int,
        size: Vec2,
        offset: Vec2,
        rotation: Float = 0,
        textureName: String? = nil,
        region: Vec4 = Vec4(1, 1, 0, 0),
        tint: Vec4 = Vec4(1, 1, 1, 1),
        drawOrder: Int = 0
    ) {
        self.name = name
        self.bone = bone
        self.size = size
        self.offset = offset
        self.rotation = rotation
        self.textureName = textureName
        self.region = region
        self.tint = tint
        self.drawOrder = drawOrder
    }
}

/// Everything that goes wrong with a rig or a clip, by name.
public enum SkeletonError: Error, Equatable {
    case noBones
    case parentNotBeforeChild(bone: String)
    case duplicateBoneName(String)
    case unknownBone(String)
    case attachmentBoneOutOfRange(attachment: String)
    case keysNotSorted(bone: String)
    case invalidDuration(clip: String)
    case unknownTexture(String)
    case duplicateAttachmentName(String)
    case unknownAttachment(String)
}

/// A rig: bones stored parents-before-children, plus the quads drawn on them.
///
/// Pure data. Load it, call ``validate()``, then hand it to the solver or a component.
public struct SkeletonDefinition: Codable, Equatable, Sendable {
    public var bones: [Bone]
    public var attachments: [Attachment]

    public init(bones: [Bone], attachments: [Attachment]) {
        self.bones = bones
        self.attachments = attachments
    }

    /// Throws the first problem found. A valid rig can be solved in one forward pass.
    public func validate() throws {
        guard !bones.isEmpty else { throw SkeletonError.noBones }

        var seenNames = Set<String>()
        for (index, bone) in bones.enumerated() {
            guard seenNames.insert(bone.name).inserted else {
                throw SkeletonError.duplicateBoneName(bone.name)
            }
            if let parent = bone.parent, !(0..<index).contains(parent) {
                throw SkeletonError.parentNotBeforeChild(bone: bone.name)
            }
        }

        var seenAttachments = Set<String>()
        for attachment in attachments {
            guard bones.indices.contains(attachment.bone) else {
                throw SkeletonError.attachmentBoneOutOfRange(attachment: attachment.name)
            }
            guard seenAttachments.insert(attachment.name).inserted else {
                throw SkeletonError.duplicateAttachmentName(attachment.name)
            }
        }
    }

    /// Looks up an attachment by name.
    public func attachmentIndex(named name: String) throws -> Int {
        guard let index = attachments.firstIndex(where: { $0.name == name }) else {
            throw SkeletonError.unknownAttachment(name)
        }
        return index
    }

    /// Looks up a bone by name. Files refer to bones by name; runtime code by index.
    public func boneIndex(named name: String) throws -> Int {
        guard let index = bones.firstIndex(where: { $0.name == name }) else {
            throw SkeletonError.unknownBone(name)
        }
        return index
    }
}
