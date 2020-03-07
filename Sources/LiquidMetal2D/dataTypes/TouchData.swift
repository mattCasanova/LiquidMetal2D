//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

import MetalMath

public class TouchData {
  
  public let location: Vector2D = Vector2D()
  public let isTouched: Bool
  
  public init(location: Vector2D, isTouched: Bool) {
    self.location.setX(location.x, andY: location.y)
    self.isTouched = isTouched
  }
}
