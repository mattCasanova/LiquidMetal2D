//
//  Float+.swift
//  
//
//  Created by Matt Casanova on 3/24/20.
//

import MetalTypes

public extension Float {
  func toVector2D() -> Vector2D {
    return Vector2D(angle: self)
  }
}
