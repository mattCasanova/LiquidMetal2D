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
  public var transform: Transform2D = Transform2D()
  public var size: Int = TransformUniformData.typeSize()
  
  public init() {  }
    
  public func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int) {
    memcpy(buffer + (offsetIndex * size), transform.raw(), size)
  }
    
  public static func typeSize() -> Int {
    return 64
  }
    
}
