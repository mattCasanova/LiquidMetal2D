//
//  InputReader.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

import simd

@MainActor
public protocol InputReader: AnyObject {
    func getWorldTouch(forZ z: Float) -> simd_float3?
    func getScreenTouch() -> simd_float2?
}
