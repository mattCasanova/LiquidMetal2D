//
//  TransformUniformData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/23/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation
import MetalMath

public class TransformUniformData: UniformData {
  public var viewProjection: Transform2D = Transform2D()
  public var size: Int = 64
  
  public init() {
    
  }
    
  public func setBuffer(buffer: UnsafeMutableRawPointer) {
    memcpy(buffer, viewProjection.raw(), size)
  }
    
    
}
