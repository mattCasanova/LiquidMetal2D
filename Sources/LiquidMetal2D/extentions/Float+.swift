//
//  Float+.swift
//  
//
//  Created by Matt Casanova on 3/24/20.
//

import MetalMath

public extension Float {
  func toVector2D() -> Vector2D {
    return Vector2D(rotation: self)
  }
}
