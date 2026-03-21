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

    func shutdown()
    /// A 1x1 white texture always available for tinting. Use with
    /// `GameObj.tintColor` to render solid-colored quads without loading a file.
    var defaultTextureId: Int { get }
    func loadTextures(
        _ items: [TextureDescriptor],
        completion: (() -> Void)?
    ) -> [Int]
    func unloadTexture(textureId: Int)
    func unloadAllTextures()

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

    /// Configures the standard perspective projection based on the current
    /// screen orientation. Call this in `initialize()` and `resize()`.
    func setDefaultPerspective() {
        setPerspective(
            fov: getDefaultFOV(),
            aspect: screenAspect,
            nearZ: PerspectiveProjection.defaultNearZ,
            farZ: PerspectiveProjection.defaultFarZ)
    }

    /// Resets the camera to the origin at the default distance.
    func setCamera() {
        setCamera(point: Vec3(0, 0, Camera2D.defaultDistance))
    }
}
