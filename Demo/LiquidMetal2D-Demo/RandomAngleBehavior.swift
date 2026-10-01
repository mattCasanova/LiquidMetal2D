//
//  RandomCircleBehavior.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/21/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import LiquidMetal2D

/// A single-state Behavior that spawns a ship at a dynamic position with a random angle and speed.
///
/// **How single-state Behaviors work:**
/// The engine's `Behavior` protocol is a state machine with a `current: State` property.
/// For simple objects that only need one mode of operation, you create a Behavior with a
/// single State. The Behavior never transitions -- it stays in that one state forever.
///
/// **Pattern:**
/// 1. Create your State class (here, `RandomAngleState`)
/// 2. Store it as a property
/// 3. Call `setStartState(startState:)` in init to activate it
///
/// `setStartState` calls `enter()` on the state, which randomizes the object's initial
/// properties. From then on, `update(dt:)` drives the state each frame.
///
/// **Used by:** `SpawnDemo` -- ships spawn at the touch location and fly outward in
/// random directions, respawning when they leave the visible area.
class RandomAngleBehavior: Behavior {
    unowned let parent: GameObj
    /// Required by the Behavior protocol. Holds the currently active State.
    /// The Behavior protocol manages transitions by calling exit() on the old state
    /// and enter() on the new one.
    var current: State!


    private let randomAngleState: RandomAngleState

    /// - Parameters:
    ///   - parent: The game object this behavior controls (position, velocity, scale, etc.)
    ///   - getSpawnLocation: Closure returning the current spawn position (e.g., touch location)
    ///   - getBounds: Closure returning the visible world bounds for out-of-bounds checks
    init(parent: GameObj, getSpawnLocation: @escaping () -> Vec2, getBounds: @escaping () -> WorldBounds) {
        self.parent = parent
        randomAngleState = RandomAngleState(
            obj: parent,
            getSpawnLocation: getSpawnLocation,
            getBounds: getBounds)
        // setStartState activates the state by calling its enter() method.
        // For this single-state behavior, this is the only transition that ever happens.
        setStartState(startState: randomAngleState)
    }

}
