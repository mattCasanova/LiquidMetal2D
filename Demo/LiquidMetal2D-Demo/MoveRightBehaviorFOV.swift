//
//  MoveRightBehaviorFOV.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/17/26.
//

import LiquidMetal2D

/// Behavior wrapper for `MoveRightStateFOV`. Moves ships right with a
/// configurable z-depth range.
class MoveRightBehaviorFOV: Behavior {
    unowned let parent: GameObj
    var current: State!

    init(parent: GameObj, getBounds: @escaping (_ zOrder: Float) -> WorldBounds,
         zRange: ClosedRange<Float>) {
        self.parent = parent
        let state = MoveRightStateFOV(
            obj: parent, getBounds: getBounds, zRange: zRange)
        setStartState(startState: state)
    }
}
