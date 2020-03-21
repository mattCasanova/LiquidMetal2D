//
//  GameObj.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/24/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import MetalMath

open class GameObj {
  public var position = Vector2D()
  public var velocity = Vector2D()
  public var scale = Vector2D()
  public var zOrder: Float = 0.0
  public var rotation: Float = 0.0
  public var textureID = 0
  
  public init() {  }
}
