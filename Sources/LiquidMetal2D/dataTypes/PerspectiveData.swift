//
//  PerspectiveData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import MetalMath

public class PerspectiveData {
  public var fov:    Float = 0
  public var aspect: Float = 0
  public var nearZ:  Float = 0
  public var farZ:   Float = 0
    
  public init() {
    
  }
    
  public func set(_ fov: Float, _ aspect: Float, _ nearZ: Float, _ farZ: Float) {
      self.fov    = fov
      self.aspect = aspect
      self.nearZ  = nearZ
      self.farZ   = farZ
  }
    
  public func make() -> Transform2D {
      return Transform2D.makePerspective(fov, aspectRatio: aspect, nearZ: nearZ, farZ: farZ)
  }
}
