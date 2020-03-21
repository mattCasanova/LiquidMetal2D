//
//  CameraData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import MetalMath

public class CameraData {
  
  public static let defaultDistance: Float = 50
  
  public var eye:      Vector2D = Vector2D()
  public var distance: Float    = 0
  
  public init() {}
  
  public func set(x: Float = 0, y: Float = 0, distance: Float = CameraData.defaultDistance) {
    eye.setX(x, andY: y)
    self.distance = distance
  }
  
  public func set(target: Vector2D, _ distance: Float = CameraData.defaultDistance) {
    eye.setX(target.x, andY: target.y)
    self.distance = distance
  }
  
  public func make() -> Transform2D {
    return Transform2D.initLook(at: eye, distance: distance)
  }
}
