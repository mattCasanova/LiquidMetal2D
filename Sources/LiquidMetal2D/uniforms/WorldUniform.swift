//
//  WorldUniform.swift
//  
//
//  Created by Matt Casanova on 4/24/20.
//

import Foundation
import simd


public class WorldUniform: UniformData {
    public var transform: simd_float4x4 = simd_float4x4()
    public var texTrans: simd_float4 = simd_float4(1, 1, 0, 0)
    public var size: Int = WorldUniform.typeSize()
    
    public init() {  }
    
    public func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int) {
        let mtxSize = MemoryLayout<simd_float4x4>.size
        let texSize = MemoryLayout<simd_float4>.size
        
        memcpy(buffer + (offsetIndex * size), &transform, mtxSize)
        memcpy(buffer + (offsetIndex * size + mtxSize), &texTrans, texSize)
    }
    
    public static func typeSize() -> Int {
        return MemoryLayout<simd_float4x4>.size + MemoryLayout<simd_float4>.size
    }
    
}
