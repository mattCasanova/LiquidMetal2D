//
//  Bounds.swift
//  
//
//  Created by Matt Casanova on 3/20/20.
//

import MetalMath

public class Bounds {
  public let maxX: Float
  public let maxY: Float
  public let minX: Float
  public let minY: Float
  
  public init(maxX: Float, minX: Float, maxY: Float, minY: Float) {
    self.maxX = maxX
    self.minX = minX
    
    self.maxY = maxY
    self.minY = minY
  }
  
}
