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
    func setCamera(point: Vec3)
    func setClearColor(color: Vec3)

    func project(world: Vec3) -> Vec3
    func unproject(screen: Vec2, forWorldZ worldZ: Float) -> Vec3
    func unproject(screenWithWorldZ: Vec3) -> Vec3
    func getUnprojectRay(forScreenPoint point: Vec2) -> UnprojectRay

    func getWorldBoundsFromCamera(zOrder: Float) -> WorldBounds
    func getWorldBounds(cameraDistance: Float, zOrder: Float) -> WorldBounds

    func beginPass()
    func usePerspective()
    func useOrthographic()
    func useTexture(textureId: Int)
    func draw(uniforms: UniformData)
    func endPass()
}
