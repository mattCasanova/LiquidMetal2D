//
//  Camera2D.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

public class Camera2D {
    
    public static let defaultDistance: Float = 50
    
    public var eye             = Vec2()
    public var distance: Float = 0
    
    public init() {}
    
    public func set(point: Vec3) {
        eye.set(point.x, point.y)
        distance = point.z
    }
    
    public func set(x: Float = 0, y: Float = 0, distance: Float = Camera2D.defaultDistance) {
        eye.set(x, y)
        self.distance = distance
    }
    
    public func set(target: Vec2, distance: Float = Camera2D.defaultDistance) {
        eye.set(target.x, target.y)
        self.distance = distance
    }
    
    public func make() -> Mat4 {
        return Mat4.makeLookAt2D(Vec3(eye, distance))
    }
}
