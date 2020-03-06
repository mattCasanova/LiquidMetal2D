//
//  UniformData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/16/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Metal

public protocol UniformData {
  var size: Int { get }
  func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int)
}
