//
//  Renderer.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

import MetalMath

protocol Renderer {
    var view: UIView  { get }
    var screenHeight: Float { get }
    var screenWidth:  Float  { get }
    var screenAspect: Float { get }
    
    func resize(scale: CGFloat, layerSize: CGSize)
    
    func load(name: String, ext: String, isMipmaped: Bool, shouldFlip: Bool) -> Int
    
    func setPerspective(fov: Float, aspect: Float, nearZ: Float, farZ: Float)
    func setCamera(x: Float, y: Float, distance: Float)
    func setClearColor(clearColor: Vector3D)
    
    
    func beginRenderPass()
    func renderPerspective()
    func setTexture(textureId: Int)
    func renderOrthographic()
    func draw(transform: Transform2D)
    func endRenderPass()
}
