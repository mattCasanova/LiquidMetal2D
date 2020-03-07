//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

import MetalMath

public class Input: InputGetter, InputSetter {
  
  private var location: Vector2D = Vector2D()
  private var isTouched: Bool = false
  
  public init() {  }
  
  public func setTouch(location: Vector2D, isTouched: Bool) {
    self.location.setX(location.x, andY: location.y)
    self.isTouched = isTouched
  }
  
  public func getTouch() -> TouchData {
    return TouchData(location: location, isTouched: isTouched)
  }
  
}
