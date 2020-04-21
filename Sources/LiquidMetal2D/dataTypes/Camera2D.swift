//
//  CameraData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import simd
import MetalMath

public class Camera2D {
    
    public static let defaultDistance: Float = 50
    
    public var eye             = simd_float2()
    public var distance: Float = 0
    
    public init() {}
    
    public func set(point: simd_float3) {
        eye.set(point.x, point.y)
        distance = point.z
    }
    
    public func set(x: Float = 0, y: Float = 0, distance: Float = Camera2D.defaultDistance) {
        eye.set(x, y)
        self.distance = distance
    }
    
    public func set(target: simd_float2, distance: Float = Camera2D.defaultDistance) {
        eye.set(target.x, target.y)
        self.distance = distance
    }
    
    public func make() -> simd_float4x4 {
        return simd_float4x4.makeLookAt2D(simd_float3(eye, distance))
    }
}
