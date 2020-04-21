//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

import simd
import MetalMath

public protocol InputReader: class {
    func getWorldTouch(forZ z: Float) -> simd_float3?
    func getScreenTouch() -> simd_float2?
}
