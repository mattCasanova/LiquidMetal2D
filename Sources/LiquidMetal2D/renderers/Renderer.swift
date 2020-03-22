//
//  Renderer.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

import MetalMath

public protocol Renderer: class {
  var view: UIView  { get }
  var screenHeight: Float { get }
  var screenWidth:  Float  { get }
  var screenAspect: Float { get }
  
  func resize(scale: CGFloat, layerSize: CGSize)
  
  func loadTexture(name: String, ext: String, isMipmaped: Bool, shouldFlip: Bool) -> Int
  func unloadTexture(textureId: Int)
  
  func setPerspective(fov: Float, aspect: Float, nearZ: Float, farZ: Float)
  func setCamera(x: Float, y: Float, distance: Float)
  func setClearColor(clearColor: Vector3D)
  
  func project(worldCoordinate: Vector2D) -> Vector2D
  func unProject(screenCoordinate: Vector2D) -> Vector3D
  
  func getWorldBoundsFromCamera(zOrder: Float) -> Bounds
  func getWorldBounds(cameraDistance: Float, zOrder: Float) -> Bounds
  
  func beginPass()
  func usePerspective()
  func useOrthographic()
  func useTexture(textureId: Int)
  func draw(uniforms: UniformData)
  func endPass()
}
