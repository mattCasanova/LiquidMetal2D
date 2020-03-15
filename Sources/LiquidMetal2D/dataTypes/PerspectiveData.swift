//
//  PerspectiveData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import MetalMath

public class PerspectiveData {
  public static let defaultNearZ: Float = 0.1
  public static let defaultFarZ: Float = 100
  public static let defaultFOV: Float = 90
  
  public var fov:    Float = 0
  public var aspect: Float = 0
  public var nearZ:  Float = 0
  public var farZ:   Float = 0
  
  public init() {
    
  }
  
  public func set(aspect: Float, fov: Float, nearZ: Float, farZ: Float) {
    self.fov    = fov
    self.aspect = aspect
    self.nearZ  = nearZ
    self.farZ   = farZ
  }
  
  public func make() -> Transform2D {
    return Transform2D.initPerspective(fov, aspectRatio: aspect, nearZ: nearZ, farZ: farZ)
  }
}
