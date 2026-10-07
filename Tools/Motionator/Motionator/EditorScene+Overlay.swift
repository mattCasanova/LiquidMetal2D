//
//  EditorScene+Overlay.swift
//  Motionator
//
//  Created by Matt Casanova on 10/8/26.
//

import CoreGraphics
import LiquidMetal2D
import MotionatorKit

/// What the viewport draws besides the character: ghosts, bone lines,
/// joint dots, IK rings, the reference image and the grid.
extension EditorScene {
    private static let boneColour = Vec4(1, 1, 1, 0.55)
    private static let selectedColour = Vec4(1, 0.62, 0.2, 1)
    private static let pendingColour = Vec4(1, 0.45, 0.1, 0.9)
    private static let jointColour = Vec4(0.6, 0.85, 1, 0.9)
    private static let reachColour = Vec4(0.3, 1, 0.9, 0.7)
    private static let ghostBefore = Vec4(1, 0.4, 0.4, 0.28)
    private static let ghostAfter = Vec4(0.4, 1, 0.5, 0.28)

    // MARK: - Onion skins

    /// The poses at the key times either side of the playhead, tinted red
    /// before and green after.
    func layOutGhosts(_ rig: SkeletonDefinition) {
        let session = editor.session
        guard session.mode == .animate, session.onionSkins, ghosts.count == 2,
              let clip = session.clip(in: editor.document.character), let resolved = resolved(clip, for: rig) else {
            for ghost in ghosts { hide(ghost, rig: rig) }
            return
        }
        let times = [ClipEditor.keyTime(in: clip, before: session.playhead),
                     ClipEditor.keyTime(in: clip, after: session.playhead)]
        let colours = [Self.ghostBefore, Self.ghostAfter]
        for (index, ghost) in ghosts.enumerated() {
            guard let time = times[index] else {
                hide(ghost, rig: rig)
                continue
            }
            ghost.root.isActive = true
            var pose = Pose(restOf: rig)
            resolved.sample(at: time, definition: rig, into: &pose)
            ghost.skeleton.place(pose: pose)
            for part in ghost.skeleton.parts {
                part.zOrder -= 0.1
                part.get(AlphaBlendComponent.self)?.tintColor = colours[index]
            }
        }
    }

    private func hide(_ ghost: Figure, rig: SkeletonDefinition) {
        guard ghost.root.isActive else { return }
        ghost.root.isActive = false
        ghost.skeleton.place(pose: Pose(restOf: rig))
    }

    // MARK: - Bones

    /// One thin quad per bone from joint to tip and a dot at each joint, the
    /// selection in orange, pending bones in a deeper orange; in Animate mode
    /// a ring at every chain tip (hands, feet, the head) for IK drags.
    func layOutOverlay(_ rig: SkeletonDefinition, pose: Pose) {
        guard let renderer = renderer as? DefaultRenderer else { return }
        let session = editor.session
        let world = session.mode == .setup
            ? RigEditor.restWorld(of: rig) : PoseSampler.worldTransforms(rig: rig, pose: pose)
        let thickness = session.cameraDistance * 0.004
        growOverlay(to: rig.bones.count, renderer: renderer)
        for index in boneLines.indices {
            guard index < rig.bones.count else {
                boneLines[index].isActive = false
                jointDots[index].isActive = false
                reachRings[index].isActive = false
                continue
            }
            let bone = rig.bones[index]
            let joint = world[index].position
            let tip = world[index].apply(to: Vec2(bone.length, 0))
            let selected = session.selectedBone == index
            let pending = session.pendingBones.contains(bone.name)

            let line = boneLines[index]
            line.isActive = true
            line.position = (joint + tip) / 2
            line.scale = Vec2(bone.length, thickness)
            line.rotation = world[index].rotation
            line.zOrder = selected ? 0.52 : 0.5
            line.get(AlphaBlendComponent.self)?.tintColor = selected ? Self.selectedColour
                : pending ? Self.pendingColour : Self.boneColour

            let dot = jointDots[index]
            dot.isActive = true
            dot.position = joint
            dot.scale = Vec2(repeating: thickness * 3.5)
            dot.zOrder = 0.55
            dot.get(AlphaBlendComponent.self)?.tintColor = selected ? Self.selectedColour : Self.jointColour

            let ring = reachRings[index]
            let isTip = session.mode == .animate && bone.parent != nil && !rig.bones.contains { $0.parent == index }
            ring.isActive = isTip
            ring.position = tip
            ring.scale = Vec2(repeating: thickness * 6)
            ring.zOrder = 0.56
            ring.get(AlphaBlendComponent.self)?.tintColor = Self.reachColour
        }
    }

    private func growOverlay(to count: Int, renderer: DefaultRenderer) {
        while boneLines.count < count {
            let line = GameObj()
            line.add(AlphaBlendComponent(parent: line, textureID: renderer.defaultTextureId))
            boneLines.append(line)
            let dot = GameObj()
            dot.add(AlphaBlendComponent(parent: dot, textureID: renderer.defaultParticleTextureId))
            jointDots.append(dot)
            let ring = GameObj()
            ring.add(AlphaBlendComponent(parent: ring, textureID: renderer.defaultParticleTextureId))
            reachRings.append(ring)
        }
    }

    // MARK: - Reference image

    /// A quad behind everything, sized by pixels per unit, at the session's opacity.
    func layOutReference() {
        guard let renderer = renderer as? DefaultRenderer else { return }
        let session = editor.session
        if session.referenceImage != referenceData {
            referenceData = session.referenceImage
            reference = nil
            if let data = referenceData, let image = ContactSheet.decode(data), let id = renderer.addTexture(image) {
                let quad = GameObj()
                quad.scale = Vec2(Float(image.width), Float(image.height)) / session.pixelsPerUnit
                quad.zOrder = -0.02
                quad.add(AlphaBlendComponent(parent: quad, textureID: id))
                reference = quad
            }
        }
        reference?.get(AlphaBlendComponent.self)?.tintColor = Vec4(1, 1, 1, session.referenceOpacity)
    }

    // MARK: - Grid

    /// Thin quads every unit, a brighter pair through the origin.
    func buildGrid() {
        guard let renderer = renderer as? DefaultRenderer else { return }
        let extent: Float = 40
        let faint = Vec4(1, 1, 1, 0.06)
        let axis = Vec4(1, 1, 1, 0.2)
        for step in -Int(extent)...Int(extent) {
            let along = Float(step)
            let vertical = GameObj()
            vertical.position = Vec2(along, 0)
            vertical.scale = Vec2(0.02, extent * 2)
            vertical.zOrder = -0.01
            vertical.add(AlphaBlendComponent(
                parent: vertical, textureID: renderer.defaultTextureId, tintColor: step == 0 ? axis : faint))
            let horizontal = GameObj()
            horizontal.position = Vec2(0, along)
            horizontal.scale = Vec2(extent * 2, 0.02)
            horizontal.zOrder = -0.01
            horizontal.add(AlphaBlendComponent(
                parent: horizontal, textureID: renderer.defaultTextureId, tintColor: step == 0 ? axis : faint))
            gridLines.append(vertical)
            gridLines.append(horizontal)
        }
    }
}
