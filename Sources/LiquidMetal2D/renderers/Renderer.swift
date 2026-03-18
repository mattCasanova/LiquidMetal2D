//
//  Renderer.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

@MainActor
public protocol Renderer: AnyObject {
    var view: UIView { get }
    var screenHeight: Float { get }
    var screenWidth: Float { get }
    var screenAspect: Float { get }

    func resize(scale: CGFloat, layerSize: CGSize)

    func loadTexture(name: String, ext: String, isMipmaped: Bool) -> Int
    func unloadTexture(textureId: Int)

    func setPerspective(fov: Float, aspect: Float, nearZ: Float, farZ: Float)
    func setOrthographic(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float)
    func setCamera(point: Vec3)
    func setCameraRotation(angle: Float)
    func setClearColor(color: Vec3)

    func project(world: Vec3) -> Vec3
    func unproject(screen: Vec2, forWorldZ worldZ: Float) -> Vec3
    func unproject(screenWithWorldZ: Vec3) -> Vec3
    func getUnprojectRay(forScreenPoint point: Vec2) -> UnprojectRay

    func getWorldBoundsFromCamera(zOrder: Float) -> WorldBounds
    func getWorldBounds(cameraDistance: Float, zOrder: Float) -> WorldBounds

    func beginPass() -> Bool
    func usePerspective()
    func useOrthographic()
    func submit(objects: [GameObj])
    func useTexture(textureId: Int)
    func draw(uniforms: UniformData)
    func endPass()
}

public extension Renderer {
    /// Returns the default FOV in radians, adjusted for aspect ratio to keep
    /// the vertical visible area consistent across orientations.
    ///
    /// In portrait, returns the default FOV (90°). In landscape, computes the
    /// exact FOV that preserves the same vertical extent:
    /// `2 * atan(tan(portraitFOV/2) / aspectRatio)`
    func getDefaultFOV() -> Float {
        let baseFOV = GameMath.degreeToRadian(PerspectiveProjection.defaultFOV)
        if screenWidth <= screenHeight {
            return baseFOV
        }
        return 2 * atan(tan(baseFOV / 2) / screenAspect)
    }

    /// Sets the camera to the default position and configures a standard
    /// perspective projection based on the current screen orientation.
    /// Call this in `initialize()` and `resize()` for typical 2D scenes.
    func setDefaultPerspective() {
        setCamera(point: Vec3(0, 0, Camera2D.defaultDistance))
        setPerspective(
            fov: getDefaultFOV(),
            aspect: screenAspect,
            nearZ: PerspectiveProjection.defaultNearZ,
            farZ: PerspectiveProjection.defaultFarZ)
    }
}
