//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/23/20.
//

import MetalMath
public protocol Collider {
  func doesCollideWith(collider: Collider) -> Bool
  func doesCollideWith(point: Vector2D) -> Bool
  func doesCollideWith(circleCenter: Vector2D, radius: Float) -> Bool
  func doesCollideWith(aabbCenter: Vector2D, width: Float, height: Float) -> Bool
}

public class NilCollider: Collider {
  
  public init() {
    
  }
  
  public func doesCollideWith(collider: Collider) -> Bool {
    return false
  }
  
  public func doesCollideWith(point: Vector2D) -> Bool {
    return false
  }
  
  public func doesCollideWith(circleCenter: Vector2D, radius: Float) -> Bool {
    return false
  }
  
  public func doesCollideWith(aabbCenter: Vector2D, width: Float, height: Float) -> Bool {
    return false
  }
  
  
}


