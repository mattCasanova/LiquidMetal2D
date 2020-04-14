//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/23/20.
//

import simd
import MetalMath

public class CircleCollider: Collider {
  private unowned let obj: GameObj
  public var radius: Float
  
  public init(obj: GameObj, radius: Float) {
    self.obj = obj
    self.radius = radius
  }
  
  public func doesCollideWith(collider: Collider) -> Bool {
    return collider.doesCollideWith(circleCenter: obj.position, radius: radius)
  }
  
  public func doesCollideWith(point: simd_float2) -> Bool {
    return Intersect.pointCircle(point: point, circle: obj.position, radius: radius)
  }
  
  public func doesCollideWith(circleCenter: simd_float2, radius: Float) -> Bool {
    return Intersect.circleCircle(center1: circleCenter, center2: obj.position, radius1: radius, radius2: self.radius)
  }
  
  public func doesCollideWith(aabbCenter: simd_float2, width: Float, height: Float) -> Bool {
    return Intersect.circleAABB(circleCenter: obj.position, radius: radius, aabbCenter: aabbCenter, width: width, height: height)
  }
}
