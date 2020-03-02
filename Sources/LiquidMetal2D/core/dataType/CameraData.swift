//
//  CameraData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import MetalMath

class CameraData {
    var eye:      Vector2D = Vector2D()
    var distance: Float    = 0
    
    func set(_ x: Float, _ y: Float, _ distance: Float) {
        eye.setX(x, andY: y)
        self.distance = distance
    }
    
    func make() -> Transform2D {
        return Transform2D.makeLook(at: eye, distance: distance)
    }
}
