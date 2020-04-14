//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/23/20.
//

import simd
import MetalMath

public class PointCollider: Collider {
  private unowned let obj: GameObj
  
  public init(obj: GameObj) {
    self.obj = obj
  }
  
  public func doesCollideWith(collider: Collider) -> Bool {
    return collider.doesCollideWith(point: obj.position)
  }
  
  public func doesCollideWith(point: simd_float2) -> Bool {
    return simd_epsilon_equal(lhs: point, rhs: obj.position)
  }
  
  public func doesCollideWith(circleCenter: simd_float2, radius: Float) -> Bool {
    return Intersect.pointCircle(point: obj.position, circle: circleCenter, radius: radius)
  }
  
  public func doesCollideWith(aabbCenter: simd_float2, width: Float, height: Float) -> Bool {
    return Intersect.pointAABB(point: obj.position, center: aabbCenter, width: width, height: height)
  }
}
