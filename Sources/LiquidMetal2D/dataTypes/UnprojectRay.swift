//
//  UnprojectRay.swift
//  
//
//  Created by Matt Casanova on 4/20/20.
//

import simd

public struct UnprojectRay {
    public let origin: simd_float3
    public let vector: simd_float3
    
    public init(origin: simd_float3, vector: simd_float3) {
        self.origin = origin
        self.vector = vector
    }
    
    
    public func getPoint(forWorldZ z: Float) -> simd_float3 {
        return origin + (vector * z)
    }
    
    
    
    
}
