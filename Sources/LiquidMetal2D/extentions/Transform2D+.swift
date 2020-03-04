//
//  Transform2D+.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/29/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import MetalMath

public extension Transform2D {
    static func *(lhs: Transform2D, rhs: Transform2D) -> Transform2D {
        return lhs.multiplyRight(rhs)
    }
    
    static func *=(lhs: Transform2D, rhs: Transform2D) -> Transform2D {
          return lhs.multiplyRightSelf(rhs)
    }
    
}
