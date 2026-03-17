//
//  PointCollider.swift
//  
//
//  Created by Matt Casanova on 3/23/20.
//


public class PointCollider: Collider {
    private unowned let obj: GameObj
    
    public init(obj: GameObj) {
        self.obj = obj
    }
    
    public func doesCollideWith(collider: Collider) -> Bool {
        return collider.doesCollideWith(point: obj.position)
    }
    
    public func doesCollideWith(point: Vec2) -> Bool {
        return simd_epsilon_equal(lhs: point, rhs: obj.position)
    }
    
    public func doesCollideWith(circle: Circle) -> Bool {
        return Intersect.pointCircle(point: obj.position, circle: circle)
    }
    
    public func doesCollideWith(aabbCenter: Vec2, width: Float, height: Float) -> Bool {
        return Intersect.pointAABB(point: obj.position, center: aabbCenter, width: width, height: height)
    }
}
