//
//  Camera2D.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

/// 2D camera with position, distance (zoom), and rotation.
///
/// The camera produces a view matrix via ``make()``. The view matrix undoes
/// the camera's placement: it first moves the world by `-eye` (and back by
/// `distance`), then rotates it by `-rotation` around the Z axis. Because the
/// move comes first, the world spins around the camera's position, not the
/// world origin. Useful for screen shake, tilt effects, or smooth rotation
/// transitions.
public class Camera2D {

    public static let defaultDistance: Float = 50

    public var eye             = Vec2()
    public var distance: Float = 0

    /// Rotation angle in radians around the Z axis.
    public var rotation: Float = 0

    public init() {}

    public func set(point: Vec3) {
        eye.set(point.x, point.y)
        distance = point.z
    }

    public func set(x: Float = 0, y: Float = 0, distance: Float = Camera2D.defaultDistance, rotation: Float = 0) {
        eye.set(x, y)
        self.distance = distance
        self.rotation = rotation
    }

    public func set(target: Vec2, distance: Float = Camera2D.defaultDistance) {
        eye.set(target.x, target.y)
        self.distance = distance
    }

    /// Builds the view matrix: move the world by `-eye`, then rotate it around
    /// the camera. Written `rotate * translate` because matrices apply right to
    /// left. Swapping the order would spin the world around (0, 0) instead.
    public func make() -> Mat4 {
        if GameMath.isFloatEqual(rotation, 0) {
            return Mat4.makeLookAt2D(Vec3(eye, distance))
        }
        return Mat4.makeRotate2D(-rotation) * Mat4.makeLookAt2D(Vec3(eye, distance))
    }
}
