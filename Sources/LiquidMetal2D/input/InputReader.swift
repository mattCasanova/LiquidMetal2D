//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

import MetalMath

public protocol InputReader: class {
  func getWorldTouch() -> Vector2D?
  func getScreenTouch() -> Vector2D?
}
