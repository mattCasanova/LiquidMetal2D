//
//  GameObj.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/24/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//


open class GameObj {
  public var position = Vec2()
  public var velocity = Vec2()
  public var scale = Vec2()
  public var zOrder: Float = 0.0
  public var rotation: Float = 0.0
  public var textureID = 0
  
  public init() {  }
}
