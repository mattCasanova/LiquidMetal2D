//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

import MetalMath

public protocol InputSetter {
  func setTouch(location: Vector2D, isTouched: Bool)
}
