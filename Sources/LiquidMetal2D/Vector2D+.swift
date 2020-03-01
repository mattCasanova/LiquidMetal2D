//
//  Vector2D+.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/29/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

extension Vector2D {
    static func +(lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        return lhs.add(rhs)
    }
    
    static func -(lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        return lhs.subtract(rhs)
    }
    
    static prefix func -(lhs: Vector2D) -> Vector2D {
        return lhs.negate()
    }
    
    static func *(lhs: Vector2D, scalar: Float) -> Vector2D {
        return lhs.scale(scalar)
    }
    
    static func /(lhs: Vector2D, scalar: Float) -> Vector2D {
        return lhs.scale( 1 / scalar)
    }
    
    static func +=(lhs: inout Vector2D, rhs: Vector2D) {
        lhs.add(toSelf: rhs)
    }
    
    static func -=(lhs: inout Vector2D, rhs: Vector2D) {
        lhs.subtract(fromSelf: rhs)
    }
    
    static func *=(lhs: inout Vector2D, scalar: Float) {
        lhs.scaleSelf(scalar)
    }
    
    static func /=(lhs: inout Vector2D, scalar: Float) {
        lhs.scaleSelf(1 / scalar)
    }
    
    static func ==(lhs: Vector2D, rhs: Vector2D) -> Bool {
        return lhs.isVectorEqual(rhs)
    }
    
    static func !=(lhs: Vector2D, rhs: Vector2D) -> Bool {
        return lhs.isVectorNotEqual(rhs)
    }
    
}
