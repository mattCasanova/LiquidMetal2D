//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/23/20.
//

import MetalMath

public class PointCollider: Collider {
  private unowned let obj: GameObj
  
  public init(obj: GameObj) {
    self.obj = obj
  }
  
  public func doesCollideWith(collider: Collider) -> Bool {
    return collider.doesCollideWith(point: obj.position)
  }
  
  public func doesCollideWith(point: Vector2D) -> Bool {
    return point.isVectorEqual(obj.position)
  }
  
  public func doesCollideWith(circleCenter: Vector2D, radius: Float) -> Bool {
    return Intersect.point(obj.position, vsCircle: circleCenter, withRadius: radius)
  }
  
  public func doesCollideWith(aabbCenter: Vector2D, width: Float, height: Float) -> Bool {
    return Intersect.point(obj.position, vsAABB: aabbCenter, withWidth: width, andHeight: height)
  }
}
