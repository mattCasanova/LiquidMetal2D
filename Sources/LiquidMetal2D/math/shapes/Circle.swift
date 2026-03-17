//
//  Circle.swift
//
//
//  Created by Matt Casanova on 4/20/20.
//

/// Read-only circle. Used by Intersect methods which only need to read geometry.
public protocol Circle {
    var center: Vec2 { get }
    var radius: Float { get }
}

/// Mutable circle. For types that need to modify center/radius (e.g., CircleCollider).
public protocol MutableCircle: Circle {
    var center: Vec2 { get set }
    var radius: Float { get set }
}
