//
//  PlayerState.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 3/20/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import LiquidMetal2D

/// A State that reads touch input and rotates the ship to face the touch position.
///
/// **Reading input in a State:**
/// The `InputReader` is passed in from the Behavior. Each frame in `update(dt:)`, we call
/// `inputReader.getWorldTouch(forZ:)` to get the touch position in world space at z=0.
/// If there is an active touch, we compute the angle from the origin to the touch using
/// `atan2` and set the ship's rotation to face that direction.
///
/// **MainActor.assumeIsolated:**
/// `getWorldTouch` is a `@MainActor`-isolated method because it reads UIKit touch state.
/// Since the game loop runs on the main thread (via CADisplayLink), we use
/// `MainActor.assumeIsolated` to tell Swift 6 concurrency that we are already on the
/// main actor, avoiding an async call.
class PlayerState: State, @unchecked Sendable {
    private unowned let obj: GameObj
    /// Unowned reference to the engine's input reader for querying touch state.
    private unowned let inputReader: InputReader

    init(obj: GameObj, inputReader: InputReader) {
        self.obj = obj
        self.inputReader = inputReader
    }

    func enter() {}
    func exit() {}

    func update(dt: Float) {
        MainActor.assumeIsolated {
            // getWorldTouch converts the screen touch position to world-space at z=0.
            // Returns nil if no touch is active.
            if let touch = inputReader.getWorldTouch(forZ: 0) {
                // atan2(y, x) computes the angle from origin to the touch point.
                // Setting obj.rotation makes the ship visually face that direction.
                obj.rotation = atan2(touch.y, touch.x)
            }
        }
    }
}
