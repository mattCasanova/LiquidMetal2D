//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/23/20.
//

import simd
import MetalMath

public protocol Collider {
  func doesCollideWith(collider: Collider) -> Bool
  func doesCollideWith(point: simd_float2) -> Bool
  func doesCollideWith(circleCenter: simd_float2, radius: Float) -> Bool
  func doesCollideWith(aabbCenter: simd_float2, width: Float, height: Float) -> Bool
}

public class NilCollider: Collider {
  
  public init() {
    
  }
  
  public func doesCollideWith(collider: Collider) -> Bool {
    return false
  }
  
  public func doesCollideWith(point: simd_float2) -> Bool {
    return false
  }
  
  public func doesCollideWith(circleCenter: simd_float2, radius: Float) -> Bool {
    return false
  }
  
  public func doesCollideWith(aabbCenter: simd_float2, width: Float, height: Float) -> Bool {
    return false
  }
  
  
}


