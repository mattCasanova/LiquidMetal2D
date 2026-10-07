//
//  EditorScene.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import LiquidMetal2D
import MotionatorKit

/// The viewport: the character, a grid, and the bones drawn over it. Pan
/// by dragging empty space, zoom by scroll. In Setup mode a click selects
/// the nearest bone and a drag edits its rest pose: plain drag rotates it
/// to point at the pointer, Command-drag moves it, Option-drag sets its
/// length. Each drag is one undo step, committed when the button goes up.
/// Reads the document and the session every frame.
final class EditorScene: DefaultScene {
    override static var sceneType: any SceneType { EditorSceneType.editor }

    private enum Drag {
        case pan
        case rotate(Int)
        case translate(Int, startRest: RigidTransform2D, from: Vec2)
        case length(Int)
    }

    private var editor: EditorServices!
    private var figureRoot: GameObj?
    private var figure: SkeletonComponent?
    private var builtRig: SkeletonDefinition?
    private var textureIDs: [String: Int] = [:]
    private var gridLines: [GameObj] = []
    private var boneLines: [GameObj] = []
    private var jointDots: [GameObj] = []
    private var drag: Drag?
    /// The rig as the current drag has it, shown but not yet in the document.
    private var draftRig: SkeletonDefinition?
    private var lastPointer: Vec2?

    private static let boneColour = Vec4(1, 1, 1, 0.55)
    private static let selectedColour = Vec4(1, 0.62, 0.2, 1)
    private static let jointColour = Vec4(0.6, 0.85, 1, 0.9)

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
        let rig = draftRig ?? editor.document.character.rig
        rebuildIfNeeded(rig)
        handlePointer(rig)
        let shown = draftRig ?? editor.document.character.rig
        layOutOverlay(shown)
        figure?.update(dt: 0)
    }

    override func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        if editor.session.showGrid { renderer.submit(objects: gridLines) }
        if let figure { renderer.submit(objects: figure.parts) }
        renderer.submit(objects: boneLines)
        renderer.submit(objects: jointDots)
        renderer.endPass()
    }

    // MARK: - The figure

    private func rebuildIfNeeded(_ rig: SkeletonDefinition) {
        guard rig != builtRig else { return }
        let character = editor.document.character
        loadTextures(of: character)
        let root = GameObj()
        do {
            let skeleton = try SkeletonComponent(
                parent: root, definition: rig, defaultTextureID: renderer.defaultTextureId, textureIDs: textureIDs)
            root.add(skeleton)
            figureRoot = root
            figure = skeleton
            builtRig = rig
        } catch {
            // A rig mid-edit may not validate; keep showing the last good one.
            #if DEBUG
            print("EditorScene: the rig does not draw yet: \(error)")
            #endif
        }
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

    // MARK: - Pointer

    private func handlePointer(_ rig: SkeletonDefinition) {
        let session = editor.session
        let scroll = input.pointer.scrollDelta.y
        if scroll != 0 {
            session.cameraDistance = GameMath.clamp(
                value: session.cameraDistance * pow(1.05, -scroll), low: 2, high: 400)
        }
        let world = input.pointerWorld(forZ: 0).map { Vec2($0.x, $0.y) }

        if input.isTriggered(.pointerPrimary), let point = world {
            drag = beginDrag(at: point, rig: rig)
            lastPointer = point
        } else if input.isPressed(.pointerPrimary), let point = world, let drag {
            continueDrag(drag, to: point, rig: rig)
        } else if input.isReleased(.pointerPrimary) {
            endDrag()
        }
        renderer.setCamera(point: Vec3(session.cameraCentre.x, session.cameraCentre.y, session.cameraDistance))
    }

    /// A bone under the pointer starts an edit in Setup mode; empty space pans.
    private func beginDrag(at point: Vec2, rig: SkeletonDefinition) -> Drag {
        let session = editor.session
        guard session.mode == .setup else { return .pan }
        let world = RigEditor.restWorld(of: rig)
        guard let bone = PoseSampler.bone(near: point, rig: rig, world: world, tolerance: hitTolerance) else {
            return .pan
        }
        session.selection = .bone(bone)
        if input.isPressed(.command) {
            return .translate(bone, startRest: rig.bones[bone].rest, from: point)
        }
        if input.isPressed(.option) { return .length(bone) }
        return .rotate(bone)
    }

    private func continueDrag(_ drag: Drag, to point: Vec2, rig: SkeletonDefinition) {
        let session = editor.session
        switch drag {
        case .pan:
            if let last = lastPointer {
                session.cameraCentre -= point - last
                renderer.setCamera(point: Vec3(session.cameraCentre.x, session.cameraCentre.y, session.cameraDistance))
                // After the camera moved the pointer sits on a new world point: remember that one.
                lastPointer = input.pointerWorld(forZ: 0).map { Vec2($0.x, $0.y) }
            }
        case .rotate(let bone):
            let world = RigEditor.restWorld(of: rig)
            var rest = rig.bones[bone].rest
            rest.rotation = PoseSampler.rotationPointing(bone: bone, at: point, rig: rig, world: world)
            draftRig = try? RigEditor.settingRest(rig, bone, rest)
        case .translate(let bone, let startRest, let from):
            let world = RigEditor.restWorld(of: rig)
            let parentRotation = rig.bones[bone].parent.map { world[$0].rotation } ?? 0
            let delta = point - from
            let local = Vec2(delta.x * cos(-parentRotation) - delta.y * sin(-parentRotation),
                             delta.x * sin(-parentRotation) + delta.y * cos(-parentRotation))
            var rest = startRest
            rest.position = startRest.position + local
            draftRig = try? RigEditor.settingRest(rig, bone, rest)
        case .length(let bone):
            let world = RigEditor.restWorld(of: rig)
            let length = max(0.05, simd_length(point - PoseSampler.joint(of: bone, world: world)))
            draftRig = try? RigEditor.settingLength(rig, bone, length)
        }
    }

    /// Commits the drag's rig as one undo step.
    private func endDrag() {
        defer {
            drag = nil
            draftRig = nil
            lastPointer = nil
        }
        guard let drag, let draft = draftRig, draft != editor.document.character.rig else { return }
        let name: String
        switch drag {
        case .pan: return
        case .rotate: name = "Rotate Bone"
        case .translate: name = "Move Bone"
        case .length: name = "Resize Bone"
        }
        editor.document.apply({ character in
            var character = character
            character.rig = draft
            return character
        }, named: name, undoManager: editor.session.undoManager)
    }

    /// A few pixels, in world units at the current zoom.
    private var hitTolerance: Float { editor.session.cameraDistance * 0.02 }

    // MARK: - Overlay

    /// One thin quad per bone from joint to tip and a dot at each joint,
    /// the selected bone in the accent colour. Objects are reused.
    private func layOutOverlay(_ rig: SkeletonDefinition) {
        guard let renderer = renderer as? DefaultRenderer else { return }
        let session = editor.session
        let world = RigEditor.restWorld(of: rig)
        let thickness = session.cameraDistance * 0.004
        while boneLines.count < rig.bones.count {
            let line = GameObj()
            line.add(AlphaBlendComponent(parent: line, textureID: renderer.defaultTextureId))
            boneLines.append(line)
            let dot = GameObj()
            dot.add(AlphaBlendComponent(parent: dot, textureID: renderer.defaultParticleTextureId))
            jointDots.append(dot)
        }
        for (index, line) in boneLines.enumerated() {
            let dot = jointDots[index]
            guard index < rig.bones.count else {
                line.isActive = false
                dot.isActive = false
                continue
            }
            let bone = rig.bones[index]
            let joint = world[index].position
            let tip = world[index].apply(to: Vec2(bone.length, 0))
            let selected = session.selectedBone == index
            line.isActive = true
            line.position = (joint + tip) / 2
            line.scale = Vec2(bone.length, thickness)
            line.rotation = world[index].rotation
            line.zOrder = selected ? 0.52 : 0.5
            line.get(AlphaBlendComponent.self)?.tintColor = selected ? Self.selectedColour : Self.boneColour
            dot.isActive = true
            dot.position = joint
            dot.scale = Vec2(repeating: thickness * 3.5)
            dot.zOrder = 0.55
            dot.get(AlphaBlendComponent.self)?.tintColor = selected ? Self.selectedColour : Self.jointColour
        }
    }

    // MARK: - Grid

    /// Thin quads every unit, a brighter pair through the origin.
    private func buildGrid() {
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
