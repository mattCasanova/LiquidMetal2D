//
//  TransformUniformData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/23/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation
import simd
import MetalMath


public class TransformUniformData: UniformData {
    public var transform: simd_float4x4 = simd_float4x4()
    public var size: Int = TransformUniformData.typeSize()
    
    public init() {  }
    
    public func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int) {
        memcpy(buffer + (offsetIndex * size), &transform, size)
    }
    
    public static func typeSize() -> Int {
        return MemoryLayout<simd_float4x4>.size
    }
    
}
