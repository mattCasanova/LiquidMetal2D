//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/23/20.
//

import simd
import MetalMath

public class CircleCollider: Collider, Circle {
    private unowned let obj: GameObj
    public var radius: Float
    
    public var center: simd_float2 {
        get { obj.position }
        set { obj.position.set(newValue.x, newValue.y) }
        
    }

    public init(obj: GameObj, radius: Float) {
        self.obj = obj
        self.radius = radius
    }
    
    public func doesCollideWith(collider: Collider) -> Bool {
        return collider.doesCollideWith(circle: self)
    }
    
    public func doesCollideWith(point: simd_float2) -> Bool {
        return Intersect.pointCircle(point: point, circle: self)
    }
    
    public func doesCollideWith(circle: Circle) -> Bool {
        return Intersect.circleCircle(self, circle)
    }
    
    public func doesCollideWith(aabbCenter: simd_float2, width: Float, height: Float) -> Bool {
        return Intersect.circleAABB(circleCenter: obj.position, radius: radius, aabbCenter: aabbCenter, width: width, height: height)
    }
}
