//
//  RigEditor.swift
//  MotionatorKit
//
//  Created by Matt Casanova on 10/6/26.
//

import Foundation
import LiquidMetal2D

public enum RigEditError: Error, CustomStringConvertible, Equatable {
    case noSuchBone(Int)
    case noSuchAttachment(Int)
    case duplicateBoneName(String)
    case cycle(bone: String, parent: String)

    public var description: String {
        switch self {
        case .noSuchBone(let index): "there is no bone \(index)"
        case .noSuchAttachment(let index): "there is no attachment \(index)"
        case .duplicateBoneName(let name): "a bone named \(name) exists"
        case .cycle(let bone, let parent): "\(parent) descends from \(bone); it cannot be its parent"
        }
    }
}

/// Edits on a rig. Each returns the new rig, validated; bones stay
/// parents-before-children, and attachments and clips follow a renamed,
/// removed or reordered bone.
public enum RigEditor {
    public static func addingBone(
        _ rig: SkeletonDefinition, named name: String, parent: Int?, length: Float, rest: RigidTransform2D
    ) throws -> SkeletonDefinition {
        guard !rig.bones.contains(where: { $0.name == name }) else { throw RigEditError.duplicateBoneName(name) }
        if let parent { try checkBone(parent, in: rig) }
        var rig = rig
        rig.bones.append(Bone(name: name, parent: parent, length: length, rest: rest))
        try rig.validate()
        return rig
    }

    /// Removes a bone. Its children move to its parent and keep their world
    /// rest pose; its attachments go; the clips lose its tracks.
    public static func removingBone(
        _ rig: SkeletonDefinition, _ index: Int, in clips: [AnimationClip]
    ) throws -> (rig: SkeletonDefinition, clips: [AnimationClip]) {
        try checkBone(index, in: rig)
        let removed = rig.bones[index]
        var rig = rig
        for child in rig.bones.indices where rig.bones[child].parent == index {
            rig.bones[child].parent = removed.parent
            rig.bones[child].rest = removed.rest.composed(with: rig.bones[child].rest)
        }
        rig.attachments.removeAll { $0.bone == index }
        rig.bones.remove(at: index)
        for bone in rig.bones.indices {
            if let parent = rig.bones[bone].parent, parent > index { rig.bones[bone].parent = parent - 1 }
        }
        for attachment in rig.attachments.indices where rig.attachments[attachment].bone > index {
            rig.attachments[attachment].bone -= 1
        }
        try rig.validate()
        var clips = clips
        for clip in clips.indices {
            clips[clip].tracks.removeAll { $0.bone == removed.name }
        }
        return (rig, clips)
    }

    /// Moves a bone under another parent (nil: a root), keeping its world
    /// rest pose. The bones are reordered if the new parent came after it.
    public static func reparenting(
        _ rig: SkeletonDefinition, _ index: Int, to parent: Int?
    ) throws -> SkeletonDefinition {
        try checkBone(index, in: rig)
        if let parent {
            try checkBone(parent, in: rig)
            var ancestor: Int? = parent
            while let current = ancestor {
                guard current != index else {
                    throw RigEditError.cycle(bone: rig.bones[index].name, parent: rig.bones[parent].name)
                }
                ancestor = rig.bones[current].parent
            }
        }
        let world = restWorld(of: rig)
        var rig = rig
        rig.bones[index].parent = parent
        rig.bones[index].rest = parent.map { world[$0].inverted.composed(with: world[index]) } ?? world[index]
        return try reordered(rig)
    }

    /// Renames a bone; the clips' tracks follow.
    public static func renamingBone(
        _ rig: SkeletonDefinition, _ index: Int, to name: String, in clips: [AnimationClip]
    ) throws -> (rig: SkeletonDefinition, clips: [AnimationClip]) {
        try checkBone(index, in: rig)
        guard !rig.bones.contains(where: { $0.name == name }) else { throw RigEditError.duplicateBoneName(name) }
        let old = rig.bones[index].name
        var rig = rig
        rig.bones[index].name = name
        var clips = clips
        for clip in clips.indices {
            for track in clips[clip].tracks.indices where clips[clip].tracks[track].bone == old {
                clips[clip].tracks[track].bone = name
            }
        }
        return (rig, clips)
    }

    public static func settingRest(
        _ rig: SkeletonDefinition, _ index: Int, _ rest: RigidTransform2D
    ) throws -> SkeletonDefinition {
        try checkBone(index, in: rig)
        var rig = rig
        rig.bones[index].rest = rest
        return rig
    }

    public static func settingLength(
        _ rig: SkeletonDefinition, _ index: Int, _ length: Float
    ) throws -> SkeletonDefinition {
        try checkBone(index, in: rig)
        var rig = rig
        rig.bones[index].length = length
        try rig.validate()
        return rig
    }

    // MARK: - Attachments

    /// A part from an image: sized from its pixels, centred on the bone,
    /// drawn on top of the others, named after the image.
    public static func addingAttachment(
        _ rig: SkeletonDefinition, image: String, pixelSize: Vec2, pixelsPerUnit: Float, bone: Int
    ) throws -> SkeletonDefinition {
        try checkBone(bone, in: rig)
        precondition(pixelsPerUnit > 0, "pixelsPerUnit must be above zero")
        var rig = rig
        var name = image
        var suffix = 2
        while rig.attachments.contains(where: { $0.name == name }) {
            name = "\(image) \(suffix)"
            suffix += 1
        }
        rig.attachments.append(Attachment(
            name: name, bone: bone, size: pixelSize / pixelsPerUnit,
            offset: Vec2(rig.bones[bone].length / 2, 0), textureName: image,
            drawOrder: (rig.attachments.map(\.drawOrder).max() ?? -1) + 1))
        try rig.validate()
        return rig
    }

    public static func settingAttachment(
        _ rig: SkeletonDefinition, _ index: Int, _ attachment: Attachment
    ) throws -> SkeletonDefinition {
        guard rig.attachments.indices.contains(index) else { throw RigEditError.noSuchAttachment(index) }
        var rig = rig
        rig.attachments[index] = attachment
        try rig.validate()
        return rig
    }

    public static func removingAttachment(_ rig: SkeletonDefinition, _ index: Int) throws -> SkeletonDefinition {
        guard rig.attachments.indices.contains(index) else { throw RigEditError.noSuchAttachment(index) }
        var rig = rig
        rig.attachments.remove(at: index)
        return rig
    }

    // MARK: - Helpers

    /// Every bone's rest transform in the rig's space.
    public static func restWorld(of rig: SkeletonDefinition) -> [RigidTransform2D] {
        var world: [RigidTransform2D] = []
        world.reserveCapacity(rig.bones.count)
        for bone in rig.bones {
            world.append(bone.parent.map { world[$0].composed(with: bone.rest) } ?? bone.rest)
        }
        return world
    }

    /// Bones in an order where every parent comes before its children
    /// (depth first from the roots), with attachments and parents remapped.
    static func reordered(_ rig: SkeletonDefinition) throws -> SkeletonDefinition {
        var order: [Int] = []
        func visit(childrenOf parent: Int?) {
            for (index, bone) in rig.bones.enumerated() where bone.parent == parent {
                order.append(index)
                visit(childrenOf: index)
            }
        }
        visit(childrenOf: nil)
        guard order.count == rig.bones.count else {
            throw RigEditError.cycle(bone: rig.bones[order.count].name, parent: "?")
        }
        var newIndex = [Int](repeating: 0, count: rig.bones.count)
        for (position, old) in order.enumerated() { newIndex[old] = position }
        var reordered = rig
        reordered.bones = order.map { old in
            var bone = rig.bones[old]
            bone.parent = bone.parent.map { newIndex[$0] }
            return bone
        }
        for attachment in reordered.attachments.indices {
            reordered.attachments[attachment].bone = newIndex[reordered.attachments[attachment].bone]
        }
        try reordered.validate()
        return reordered
    }

    private static func checkBone(_ index: Int, in rig: SkeletonDefinition) throws {
        guard rig.bones.indices.contains(index) else { throw RigEditError.noSuchBone(index) }
    }
}

public extension RigidTransform2D {
    /// The transform that undoes this one.
    var inverted: RigidTransform2D {
        let cosine = cos(-rotation)
        let sine = sin(-rotation)
        let position = Vec2(-(self.position.x * cosine - self.position.y * sine),
                            -(self.position.x * sine + self.position.y * cosine))
        return RigidTransform2D(position: position, rotation: -rotation)
    }
}
