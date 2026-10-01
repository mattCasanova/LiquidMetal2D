//
//  BezierDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/17/26.
//

import UIKit
import LiquidMetal2D

/// Cubic bezier curve demo with interactive control point dragging.
///
/// **What the user sees:** A ship smoothly follows two chained cubic bezier segments
/// (7 control points total). Green dots mark pass-through points (start, junction, end),
/// orange dots mark the "handle" control points. Touch near a control point to grab it
/// and drag to reshape the curve in real time. The ship orients along the curve's tangent.
///
/// **Engine features demonstrated:**
/// - **GameMath.cubicBezier:** Evaluates a cubic bezier curve from four control points
///   (p0, p1, p2, p3) at parameter t in [0,1]. Returns the interpolated Vec2 position.
/// - **Chained bezier segments:** Two cubic segments share a junction point (controlPoints[3]),
///   creating a continuous path. t in [0,1) maps to the first segment, [1,2) to the second.
/// - **Click-and-drag input:** `input.getWorldTouch(forZ:)` converts touch to world space.
///   On new touch, the closest control point within grab radius is selected. While touching,
///   that control point tracks the finger position.
/// - **Tangent orientation:** The ship's rotation is set by sampling a point slightly ahead
///   on the curve (t + 0.02) and computing `atan2` of the direction vector.
/// - **zOrder for draw ordering:** The ship has zOrder = -1 (closer to camera) so it draws
///   on top of the control point markers at zOrder = 0.
class BezierDemo: Scene {
    static var sceneType: any SceneType { SceneTypes.bezierDemo }

    private var sceneMgr: SceneManager!
    private var renderer: Renderer!
    private var input: InputReader!

    private var ship: GameObj!
    private var controlPointShips = [GameObj]()

    // Two chained cubic bezier segments sharing point [3]:
    // Segment 1: [0] -> [1] -> [2] -> [3]
    // Segment 2: [3] -> [4] -> [5] -> [6]
    private var controlPoints: [Vec2] = [
        Vec2(-25, -10),
        Vec2(-18, 20),
        Vec2(-5, 15),
        Vec2(0, -5),
        Vec2(5, -20),
        Vec2(18, 15),
        Vec2(25, -10)
    ]

    /// Parameter along the full chained path (0..2). 0..1 = first segment, 1..2 = second.
    private var t: Float = 0
    /// How fast t advances per second (path traversal speed)
    private let speed: Float = 0.3

    /// How close (in world units) a touch must be to a control point to grab it
    private let grabRadius: Float = 4
    /// Index of the control point currently being dragged, or nil if not dragging
    private var dragIndex: Int? = nil
    /// Whether a touch was active on the previous frame (for detecting new touches vs. drags)
    private var wasTouching = false

    private var ui: DemoSceneUI!

    /// Scene protocol: called once when the scene is created.
    func initialize(services: SceneServices) {
        self.sceneMgr = services.sceneMgr
        self.renderer = services.renderer
        self.input = services.input

        renderer.setCamera()
        renderer.setCameraRotation(angle: 0)
        renderer.setDefaultPerspective()
        renderer.setClearColor(color: TokyoNight.clearColor)

        createObjects()

        ui = DemoSceneUI(
            parentView: renderer.view, target: self,
            menuAction: #selector(onMenu))
    }

    /// Scene protocol: re-show the menu button when returning from PauseDemo.
    func resume() { ui.view.isHidden = false }

    /// Scene protocol: called on device rotation. Recalculate perspective projection.
    func resize() {
        ui.layout()
        renderer.setDefaultPerspective()
    }

    func update(dt: Float) {
        // Process touch input for dragging control points
        handleDrag()

        // Advance t along the full path. The range 0..2 maps to two cubic bezier segments.
        t += speed * dt
        if t > 2 { t -= 2 }

        // Evaluate the ship's position on the chained bezier curve
        let pos = evaluatePath(at: t)
        ship.position.set(pos.x, pos.y)

        // Orient the ship along the curve's tangent by sampling a point slightly ahead.
        // This makes the ship "look where it's going" instead of always facing right.
        let lookAhead = t + 0.02 < 2 ? t + 0.02 : t + 0.02 - 2
        let next = evaluatePath(at: lookAhead)
        let dir = next - pos
        if dir.lengthSquared > GameMath.epsilon {
            ship.rotation = atan2(dir.y, dir.x)
        }

        // Sync control point visual positions with the (possibly dragged) data
        for i in 0..<controlPoints.count {
            controlPointShips[i].position.set(controlPoints[i].x, controlPoints[i].y)
        }
    }

    func draw() {
        guard renderer.beginPass() else { return }
        renderer.usePerspective()
        renderer.submit(objects: controlPointShips + [ship!])
        renderer.endPass()
    }

    /// Scene protocol: clean up UI and GPU resources.
    func shutdown() {
        ui.removeFromSuperview()
    }

    // MARK: - Private

    /// Evaluates the chained bezier path at parameter t.
    /// t in [0,1) uses the first cubic segment (controlPoints[0..3]).
    /// t in [1,2) uses the second cubic segment (controlPoints[3..6]).
    /// GameMath.cubicBezier computes the standard cubic bezier formula:
    /// B(t) = (1-t)^3*p0 + 3(1-t)^2*t*p1 + 3(1-t)*t^2*p2 + t^3*p3
    private func evaluatePath(at t: Float) -> Vec2 {
        if t < 1 {
            return GameMath.cubicBezier(
                p0: controlPoints[0], p1: controlPoints[1],
                p2: controlPoints[2], p3: controlPoints[3], t: t)
        } else {
            return GameMath.cubicBezier(
                p0: controlPoints[3], p1: controlPoints[4],
                p2: controlPoints[5], p3: controlPoints[6], t: t - 1)
        }
    }

    /// Handles click-and-drag interaction for control points.
    /// On touch-down, find the nearest control point within grabRadius and start dragging it.
    /// While dragging, update that control point to match the touch position.
    /// On release, clear the drag state.
    private func handleDrag() {
        guard let touch = input.getWorldTouch(forZ: 0) else {
            // No touch active -- reset drag state
            wasTouching = false
            dragIndex = nil
            return
        }

        let touchPos = Vec2(touch.x, touch.y)

        if !wasTouching {
            // New touch began -- find the closest control point within grab radius.
            // Compare squared distances to avoid sqrt (a common game dev optimization).
            var bestDist: Float = grabRadius * grabRadius
            var bestIndex: Int? = nil
            for i in 0..<controlPoints.count {
                let dist = (touchPos - controlPoints[i]).lengthSquared
                if dist < bestDist {
                    bestDist = dist
                    bestIndex = i
                }
            }
            dragIndex = bestIndex
        }

        // If a control point is being dragged, move it to the touch position
        if let index = dragIndex {
            controlPoints[index] = touchPos
        }

        wasTouching = true
    }

    private func createObjects() {
        ship = GameObj()
        ship.scale.set(2, 2)
        ship.add(AlphaBlendComponent(
            parent: ship,
            textureID: GameTextures.blue,
            tintColor: TokyoNight.shipTints[0]))
        // Negative zOrder = closer to camera = drawn on top of control point markers
        ship.zOrder = -1

        controlPointShips.removeAll()
        for i in 0..<controlPoints.count {
            let cp = GameObj()
            cp.position.set(controlPoints[i].x, controlPoints[i].y)
            // Pass-through points (indices 0, 3, 6) are larger green markers.
            // Handle points (indices 1, 2, 4, 5) are smaller orange markers.
            let isPassThrough = (i == 0 || i == 3 || i == 6)
            cp.scale.set(isPassThrough ? 4 : 3, isPassThrough ? 4 : 3)
            let texIndex = isPassThrough ? 1 : 2
            cp.add(AlphaBlendComponent(
                parent: cp,
                textureID: GameTextures.all[texIndex],
                tintColor: TokyoNight.shipTints[texIndex]))
            cp.zOrder = 0
            controlPointShips.append(cp)
        }
    }

    /// Push PauseDemo on top of this scene.
    @objc func onMenu() { ui.view.isHidden = true; sceneMgr.pushScene(type: SceneTypes.pauseDemo) }

    /// Required factory method for TSceneBuilder.
    static func build() -> Scene { return BezierDemo() }
}
