//
//  Shapes.swift
//  
//
//  Created by Matt Casanova on 4/20/20.
//

import simd

public protocol Circle {
    var center: simd_float2 { get set }
    var radius: Float { get set }
}
