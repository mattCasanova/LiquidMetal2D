//
//  EditorScene.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import LiquidMetal2D
import MotionatorKit

/// The viewport: the character at rest (Phase B), a grid, pan by drag and
/// zoom by scroll. Rebuilds its figure whenever the document's version
/// changes; reads the session every frame.
final class EditorScene: DefaultScene {
    override static var sceneType: any SceneType { EditorSceneType.editor }

    private var editor: EditorServices!
    private var figureRoot: GameObj?
    private var figure: SkeletonComponent?
    private var textureIDs: [String: Int] = [:]
    private var builtVersion = -1
    private var gridLines: [GameObj] = []
    private var lastPointer: Vec2?

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
        rebuildIfNeeded()
        steerCamera()
        figure?.update(dt: 0)
    }

    override func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        if editor.session.showGrid { renderer.submit(objects: gridLines) }
        if let figure { renderer.submit(objects: figure.parts) }
        renderer.endPass()
    }

    // MARK: - The figure

    private func rebuildIfNeeded() {
        let document = editor.document
        guard document.version != builtVersion else { return }
        builtVersion = document.version
        let character = document.character
        loadTextures(of: character)
        let root = GameObj()
        do {
            let skeleton = try SkeletonComponent(
                parent: root, definition: character.rig, defaultTextureID: renderer.defaultTextureId,
                textureIDs: textureIDs)
            root.add(skeleton)
            figureRoot = root
            figure = skeleton
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

    // MARK: - Camera

    private func steerCamera() {
        let session = editor.session
        let scroll = input.pointer.scrollDelta.y
        if scroll != 0 {
            session.cameraDistance = GameMath.clamp(
                value: session.cameraDistance * pow(1.05, -scroll), low: 2, high: 400)
        }
        if input.isPressed(.pointerPrimary), let world = input.pointerWorld(forZ: 0) {
            let here = Vec2(world.x, world.y)
            if let last = lastPointer {
                session.cameraCentre -= here - last
            }
            lastPointer = here
        } else {
            lastPointer = nil
        }
        renderer.setCamera(point: Vec3(session.cameraCentre.x, session.cameraCentre.y, session.cameraDistance))
        if input.isPressed(.pointerPrimary), lastPointer != nil, let world = input.pointerWorld(forZ: 0) {
            // After the camera moved, the pointer sits on a new world point: remember that one.
            lastPointer = Vec2(world.x, world.y)
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
