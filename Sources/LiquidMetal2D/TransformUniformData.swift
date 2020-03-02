//
//  TransformUniformData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/23/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation
import MetalMath

class TransformUniformData: UniformData {
    var viewProjection: Transform2D = Transform2D()
    var size: Int = 64
    
    func setBuffer(buffer: UnsafeMutableRawPointer) {
        memcpy(buffer, viewProjection.raw(), size)
    }
    
    
}
