//
//  FindAndGoBehavior.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 3/24/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import LiquidMetal2D

/// A multi-state AI Behavior: Find a random target, Rotate toward it, Move to it, Repeat.
///
/// **Multi-state Behavior pattern:**
/// Unlike single-state Behaviors (RandomAngleBehavior, MoveRightBehavior), this Behavior
/// has three States that form a loop:
///
/// ```
/// FindState --> RotateState --> GoState --> FindState (repeat)
/// ```
///
/// The Behavior owns all three State instances and provides `setToFind()`, `setToRotate()`,
/// and `setToGo()` methods that the States call to trigger transitions. Each transition
/// calls the engine's `setNext(next:)` method, which will call `exit()` on the current state
/// and `enter()` on the next state at the start of the next `update(dt:)` call.
///
/// **Shared state via parent reference:**
/// The `target` property is shared between all three states through their `parent` reference
/// back to this Behavior. `FindState` sets the target, `RotateState` and `GoState` read it.
/// This is a clean way to share data between states without global variables.
///
/// **Used by:** `CollisionDemo` -- ships autonomously wander by repeatedly picking random
/// targets, turning toward them, and moving to them.
class FindAndGoBehavior: Behavior {
    /// Unowned reference to the game object this behavior controls.
    unowned let parent: GameObj

    /// Required by the Behavior protocol. The engine calls current.update(dt:) each frame.
    var current: State!
    /// The target position shared between states. FindState writes it, RotateState and GoState read it.
    var target = Vec2()

    private var findState: FindState!
    private var rotateState: RotateState!
    private var goState: GoState!

    /// - Parameters:
    ///   - parent: The game object to control
    ///   - bounds: The visible world bounds used by FindState to pick random targets
    init(parent: GameObj, bounds: WorldBounds) {
        self.parent = parent

        // Start the ship at a random position within the visible world
        parent.position.x = Float.random(in: bounds.minX...bounds.maxX)
        parent.position.y = Float.random(in: bounds.minY...bounds.maxY)

        // Create all three states upfront. They hold an unowned reference back to this
        // Behavior (as `parent`) so they can access `obj`, `target`, and transition methods.
        findState = FindState(parent: self, bounds: bounds)
        rotateState = RotateState(parent: self)
        goState = GoState(parent: self)

        // Start the AI loop in the Find state
        self.setStartState(startState: findState)
    }

    /// Transition to FindState (pick a new random target).
    /// Called by GoState when the ship reaches its target.
    func setToFind() {
        setNext(next: findState)
    }

    /// Transition to RotateState (turn toward the target).
    /// Called by FindState immediately after picking a target.
    func setToRotate() {
        setNext(next: rotateState)
    }

    /// Transition to GoState (move forward to the target).
    /// Called by RotateState when the ship is facing the target.
    func setToGo() {
        setNext(next: goState)
    }
}
