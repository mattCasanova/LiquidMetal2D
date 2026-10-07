//
//  EditorScene.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import Foundation
import LiquidMetal2D
import MotionatorKit

/// The viewport. Setup mode shows the rig at rest; a drag edits a bone's
/// rest pose (rotate, Command moves, Option sets the length). Animate mode
/// shows the clip's pose at the playhead; a drag edits the pose (rotate,
/// Command moves, a drag on a hand or foot ring bends the chain with IK)
/// and, with auto-key on, writes keys when the button goes up. Onion skins
/// show the poses at the previous and next key times. Each drag is one undo
/// step. Pan by dragging empty space, zoom by scroll. Reads the document and
/// the session every frame. The pointer handling is in `EditorScene+Pointer`,
/// the drawing in `EditorScene+Overlay`.
final class EditorScene: DefaultScene {
    override static var sceneType: any SceneType { EditorSceneType.editor }

    enum Drag {
        case pan
        case restRotate(Int)
        case restTranslate(Int, startRest: RigidTransform2D, from: Vec2)
        case restLength(Int)
        case poseRotate(Int)
        case poseTranslate(Int, from: Vec2)
        case poseReach(IKChain, bendPositive: Bool)
    }

    /// A skeleton and the root that owns it (components hold the root unowned).
    struct Figure {
        let root: GameObj
        let skeleton: SkeletonComponent
    }

    struct CachedClip {
        let version: Int
        let name: String
        let clip: ResolvedClip
    }

    var editor: EditorServices!
    var figure: Figure?
    var ghosts: [Figure] = []
    var builtRig: SkeletonDefinition?
    var textureIDs: [String: Int] = [:]
    var gridLines: [GameObj] = []
    var boneLines: [GameObj] = []
    var jointDots: [GameObj] = []
    var reachRings: [GameObj] = []
    var reference: GameObj?
    var referenceData: Data?
    var drag: Drag?
    /// The rig as the current Setup drag has it, shown but not yet in the document.
    var draftRig: SkeletonDefinition?
    /// The pose as the current Animate drag has it, and the pose it started from.
    var draftPose: Pose?
    var dragStartPose: Pose?
    /// Edits made with auto-key off, kept until Key writes them or the playhead moves.
    var scratchPose: Pose?
    var scratchBones: Set<Int> = []
    var lastPlayhead: Float = 0
    var lastPointer: Vec2?
    var clickStack: (bones: [Int], chosen: Int)?
    var resolvedClip: CachedClip?

    override func initialize(services: SceneServices) {
        super.initialize(services: services)
        guard let editor = services as? EditorServices else {
            fatalError("EditorScene needs EditorServices; see EditorViewController")
        }
        self.editor = editor
        renderer.setClearColor(color: Vec3(0.11, 0.11, 0.13))
        buildGrid()
    }

    override func update(dt: Float) {
        let session = editor.session
        let rig = draftRig ?? editor.document.character.rig
        rebuildIfNeeded(rig)
        advancePlayhead(dt)
        if session.wantsKey { writePendingKeys() }
        let pose = currentPose(rig)
        handlePointer(rig, pose: pose)
        let shownRig = draftRig ?? editor.document.character.rig
        let shownPose = draftPose ?? currentPose(shownRig)
        figure?.skeleton.place(pose: shownPose)
        layOutGhosts(shownRig)
        layOutOverlay(shownRig, pose: shownPose)
        layOutReference()
    }

    override func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        if let reference { renderer.submit(objects: [reference]) }
        if editor.session.showGrid { renderer.submit(objects: gridLines) }
        for ghost in ghosts { renderer.submit(objects: ghost.skeleton.parts) }
        if let figure { renderer.submit(objects: figure.skeleton.parts) }
        renderer.submit(objects: boneLines)
        renderer.submit(objects: jointDots)
        renderer.submit(objects: reachRings)
        renderer.endPass()
    }

    // MARK: - Poses

    /// Rest in Setup mode; in Animate mode the clip at the playhead with the
    /// scratch edits (auto-key off) on top.
    func currentPose(_ rig: SkeletonDefinition) -> Pose {
        let session = editor.session
        var pose = Pose(restOf: rig)
        guard session.mode == .animate, let clip = session.clip(in: editor.document.character) else { return pose }
        if let resolved = resolved(clip, for: rig) {
            resolved.sample(at: session.playhead, definition: rig, into: &pose)
        }
        if let scratch = scratchPose, scratch.local.count == pose.local.count {
            for bone in scratchBones where bone < pose.local.count { pose.local[bone] = scratch.local[bone] }
        }
        return pose
    }

    func resolved(_ clip: AnimationClip, for rig: SkeletonDefinition) -> ResolvedClip? {
        let version = editor.document.version
        if let cached = resolvedClip, cached.version == version, cached.name == clip.name { return cached.clip }
        guard let resolved = try? clip.resolved(for: rig) else { return nil }
        resolvedClip = CachedClip(version: version, name: clip.name, clip: resolved)
        return resolved
    }

    private func advancePlayhead(_ dt: Float) {
        let session = editor.session
        guard session.mode == .animate, let clip = session.clip(in: editor.document.character) else { return }
        if session.isPlaying {
            var time = session.playhead + dt
            if clip.loops {
                time = GameMath.wrap(value: time, low: 0, high: clip.duration)
            } else if time >= clip.duration {
                time = clip.duration
                session.isPlaying = false
            }
            session.playhead = time
        }
        if session.playhead != lastPlayhead {
            lastPlayhead = session.playhead
            clearScratch()
        }
    }

    func clearScratch() {
        scratchPose = nil
        scratchBones = []
        if !editor.session.pendingBones.isEmpty { editor.session.pendingBones = [] }
    }

    /// The Key button: writes the scratch bones' channels at the playhead.
    private func writePendingKeys() {
        let session = editor.session
        session.wantsKey = false
        guard let scratch = scratchPose, let clip = session.clip(in: editor.document.character) else { return }
        let rig = editor.document.character.rig
        var keyed = clip
        for bone in scratchBones.sorted() {
            keyed = ClipEditor.keyingBone(keyed, bone: bone, pose: scratch, rig: rig, at: session.playhead)
        }
        replaceClip(keyed, named: "Key Pose")
        clearScratch()
    }

    func replaceClip(_ clip: AnimationClip, named name: String) {
        editor.document.apply({ character in
            var character = character
            if let index = character.clips.firstIndex(where: { $0.name == clip.name }) {
                character.clips[index] = clip
            }
            return character
        }, named: name, undoManager: editor.session.undoManager)
    }

    // MARK: - The figure

    private func rebuildIfNeeded(_ rig: SkeletonDefinition) {
        guard rig != builtRig else { return }
        let character = editor.document.character
        loadTextures(of: character)
        do {
            figure = try makeFigure(rig)
            ghosts = [try makeFigure(rig), try makeFigure(rig)]
            builtRig = rig
            resolvedClip = nil
        } catch {
            // A rig mid-edit may not validate; keep showing the last good one.
            #if DEBUG
            print("EditorScene: the rig does not draw yet: \(error)")
            #endif
        }
    }

    private func makeFigure(_ rig: SkeletonDefinition) throws -> Figure {
        let root = GameObj()
        let skeleton = try SkeletonComponent(
            parent: root, definition: rig, defaultTextureID: renderer.defaultTextureId, textureIDs: textureIDs)
        root.add(skeleton)
        return Figure(root: root, skeleton: skeleton)
    }

    /// Every texture the rig names, loaded once per image; missing images draw white.
    private func loadTextures(of character: Character) {
        guard let renderer = renderer as? DefaultRenderer else { return }
        for name in Set(character.rig.attachments.compactMap(\.textureName)) where textureIDs[name] == nil {
            if let data = character.images[name], let image = ContactSheet.decode(data),
               let id = renderer.addTexture(image) {
                textureIDs[name] = id
            } else {
                textureIDs[name] = renderer.defaultTextureId
            }
        }
    }
}
