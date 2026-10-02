//
//  CameraPanDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 9/21/26.
//

import Foundation
import LiquidMetal2D

/// Camera pan demo. The camera drifts over a fixed grid of ships while three things
/// prove that rendering, unprojection and visible bounds all agree about where the camera is.
///
/// **What to look for:**
/// - **The grid scrolls.** The ships never move; only `renderer.setCamera(point:)` changes.
///   The large blue ship marks world (0, 0).
/// - **Parallax.** The dim ships sit farther from the camera (`zOrder = -30`), so they
///   scroll slower than the grid. Perspective projection gives this for free.
/// - **Centre marker stays centred.** Each frame the yellow square is placed at
///   `renderer.unproject(screen:forWorldZ:)` of the screen's centre point. If unproject
///   matches the view matrix, it never drifts.
/// - **Corner markers stay in the corners.** The red squares are placed from
///   `renderer.getVisibleBounds(zOrder:)`, pulled in by `cornerMargin` so the device's
///   rounded corners don't hide them. If the bounds follow the camera, they stay put.
/// - **Touch lands under the finger.** Touch and drag: the orange ship sits at
///   `input.getWorldTouch(forZ:)` and the grid ships turn to face it, while the camera moves.
///
/// Visible bounds ignore camera rotation, so this demo keeps the rotation at 0.
class CameraPanDemo: Scene {
    static var sceneType: any SceneType { SceneTypes.cameraPanDemo }

    private var sceneMgr: SceneManager!
    private var renderer: Renderer!
    private var input: InputReader!

    /// How far the camera drifts from the origin on each axis, in world units
    private let panExtent = Vec2(30, 18)
    /// Drift speed per axis in radians per second. Unequal speeds trace a Lissajous curve.
    private let panSpeed = Vec2(0.5, 0.8)
    private let gridSpacing: Float = 15
    private let gridHalfCount = 5
    private let farLayerZ: Float = -30
    private let markerSize: Float = 4
    /// World-unit gap between a corner marker and the screen edge, to clear the rounded corners
    private let cornerMargin: Float = 5

    private var time: Float = 0

    private var gridShips = [GameObj]()
    private var farShips = [GameObj]()
    private var cornerMarkers = [GameObj]()
    private var centreMarker: GameObj!
    private var touchShip: GameObj!
    private var isTouching = false

    func initialize(services: SceneServices) {
        self.sceneMgr = services.sceneMgr
        self.renderer = services.renderer
        self.input = services.input

        renderer.setCamera()
        renderer.setCameraRotation(angle: 0)
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        createObjects()
    }

    func resume() {}

    func resize() {
        renderer.setDefaultPerspective()
    }

    func update(dt: Float) {
        time += dt

        let eye = Vec2(sin(time * panSpeed.x) * panExtent.x, sin(time * panSpeed.y) * panExtent.y)
        renderer.setCamera(point: Vec3(eye.x, eye.y, Camera2D.defaultDistance))

        // Both markers are recomputed after the camera moves, so they describe this frame's view.
        placeCentreMarker()
        placeCornerMarkers()

        isTouching = false
        if let touch = input.getWorldTouch(forZ: 0) {
            isTouching = true
            touchShip.position.set(touch.x, touch.y)

            for ship in gridShips {
                let dir = touchShip.position - ship.position
                ship.rotation = atan2(dir.y, dir.x)
            }
        }
    }

    func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()

        var objects = farShips + gridShips + cornerMarkers + [centreMarker!]
        if isTouching { objects.append(touchShip) }
        renderer.submit(objects: objects)

        renderer.endPass()
    }

    func shutdown() {
    }

    // MARK: - Markers

    private func placeCentreMarker() {
        let size = renderer.view.bounds.size
        let screenCentre = Vec2(Float(size.width) * 0.5, Float(size.height) * 0.5)
        let world = renderer.unproject(screen: screenCentre, forWorldZ: 0)
        centreMarker.position.set(world.x, world.y)
    }

    private func placeCornerMarkers() {
        let bounds = renderer.getVisibleBounds(zOrder: 0)
        let inset = markerSize * 0.5 + cornerMargin

        let corners: [(Float, Float)] = [
            (bounds.minX + inset, bounds.maxY - inset),
            (bounds.maxX - inset, bounds.maxY - inset),
            (bounds.minX + inset, bounds.minY + inset),
            (bounds.maxX - inset, bounds.minY + inset)
        ]

        for (marker, corner) in zip(cornerMarkers, corners) {
            marker.position.set(corner.0, corner.1)
        }
    }

    // MARK: - Setup

    private func createObjects() {
        for row in -gridHalfCount...gridHalfCount {
            for col in -gridHalfCount...gridHalfCount {
                let isOrigin = row == 0 && col == 0
                let position = Vec2(Float(col) * gridSpacing, Float(row) * gridSpacing)

                gridShips.append(makeShip(
                    at: position, scale: isOrigin ? 9 : 4, zOrder: 0,
                    textureID: isOrigin ? GameTextures.blue : GameTextures.green,
                    tint: isOrigin ? TokyoNight.blue : TokyoNight.green))

                farShips.append(makeShip(
                    at: position + Vec2(gridSpacing * 0.5, gridSpacing * 0.5), scale: 4, zOrder: farLayerZ,
                    textureID: GameTextures.green, tint: TokyoNight.darker))
            }
        }

        for _ in 0..<4 {
            cornerMarkers.append(makeMarker(tint: TokyoNight.red))
        }
        centreMarker = makeMarker(tint: TokyoNight.yellow)

        touchShip = makeShip(
            at: Vec2(), scale: 7, zOrder: 2,
            textureID: GameTextures.orange, tint: TokyoNight.orange)
    }

    private func makeShip(at position: Vec2, scale: Float, zOrder: Float, textureID: Int, tint: Vec4) -> GameObj {
        let ship = GameObj()
        ship.position.set(position.x, position.y)
        ship.scale.set(scale, scale)
        ship.zOrder = zOrder
        ship.add(AlphaBlendComponent(parent: ship, textureID: textureID, tintColor: tint))
        return ship
    }

    /// Solid squares: the engine's built-in 1×1 white texture, colored by the tint.
    private func makeMarker(tint: Vec4) -> GameObj {
        let marker = GameObj()
        marker.scale.set(markerSize, markerSize)
        marker.zOrder = 1
        marker.add(AlphaBlendComponent(parent: marker, textureID: renderer.defaultTextureId, tintColor: tint))
        return marker
    }

    static func build() -> Scene { return CameraPanDemo() }
}
