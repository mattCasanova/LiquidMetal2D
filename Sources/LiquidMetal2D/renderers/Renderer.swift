//
//  Renderer.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

import simd
import MetalMath

public protocol Renderer: class {
    var view: UIView  { get }
    var screenHeight: Float { get }
    var screenWidth:  Float  { get }
    var screenAspect: Float { get }
    
    func resize(scale: CGFloat, layerSize: CGSize)
    
    func loadTexture(name: String, ext: String, isMipmaped: Bool) -> Int
    func unloadTexture(textureId: Int)
    
    func setPerspective(fov: Float, aspect: Float, nearZ: Float, farZ: Float)
    func setCamera(point: simd_float3)
    func setClearColor(color: simd_float3)
    
    func project(worldPoint: simd_float2) -> simd_float2
    func unProject(screenPoint: simd_float2) -> simd_float3
    
    func getWorldBoundsFromCamera(zOrder: Float) -> Bounds
    func getWorldBounds(cameraDistance: Float, zOrder: Float) -> Bounds
    
    func beginPass()
    func usePerspective()
    func useOrthographic()
    func useTexture(textureId: Int)
    func draw(uniforms: UniformData)
    func endPass()
}
