//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/23/20.
//

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
  
  public func doesCollideWith(point: Vector2D) -> Bool {
    return Intersect.point(point, vsCircle: obj.position, withRadius: radius)
  }
  
  public func doesCollideWith(circleCenter: Vector2D, radius: Float) -> Bool {
    return Intersect.circle(circleCenter, withRadius: radius, vsCircle: obj.position, withRadius: self.radius)
  }
  
  public func doesCollideWith(aabbCenter: Vector2D, width: Float, height: Float) -> Bool {
    return Intersect.circle(obj.position, withRadius: radius, vsAABB: aabbCenter, withWidth: width, andHeight: height)
  }
}
