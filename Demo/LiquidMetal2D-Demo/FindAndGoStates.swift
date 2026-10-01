//
//  FindAndGoStates.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 3/24/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import LiquidMetal2D

/// **FindState:** The first state in the Find-Rotate-Go loop.
/// Picks a random target position within the world bounds, then immediately transitions
/// to RotateState on the next frame.
///
/// This state demonstrates the "instant transition" pattern: `enter()` does the work,
/// and `update(dt:)` immediately triggers the next state. The state exists for one frame
/// only, acting as a setup step.
class FindState: State {
    /// Unowned reference to the parent Behavior for accessing shared data and triggering transitions.
    private unowned let parent: FindAndGoBehavior
    /// The world bounds within which to pick random target positions.
    private let bounds: WorldBounds

    init(parent: FindAndGoBehavior, bounds: WorldBounds) {
        self.parent = parent
        self.bounds = bounds
    }

    /// Pick a random target position within the visible world bounds.
    /// The target is stored on the parent Behavior so RotateState and GoState can read it.
    func enter() {
        parent.target.x = Float.random(in: bounds.minX...bounds.maxX)
        parent.target.y = Float.random(in: bounds.minY...bounds.maxY)
    }

    func exit() {}

    /// Immediately transition to RotateState. This state only lasts one frame.
    func update(dt: Float) {
        parent.setToRotate()
    }
}

/// **RotateState:** The second state in the Find-Rotate-Go loop.
/// Rotates the ship toward the target position using a 2D cross product to determine
/// the shortest turn direction (clockwise vs counter-clockwise).
///
/// **Key engine APIs used:**
/// - `Vec2(angle:)` -- creates a unit direction vector from a rotation angle
/// - `Vec2.cross(_:)` -- computes the z-component of the 2D cross product. The sign tells
///   us which way to turn: positive = counter-clockwise, negative = clockwise.
/// - `Vec2.angle` -- returns the angle of a vector (atan2 of its components)
/// - `GameMath.wrap(value:low:high:)` -- wraps an angle into [0, 2*pi) range to avoid
///   discontinuities when comparing angles near 0/2*pi boundary.
/// - `GameMath.isInRange(value:low:high:)` -- checks if the current rotation is close enough
///   to the target angle (within 0.1 radians) to consider the turn complete.
class RotateState: State {
    private unowned let parent: FindAndGoBehavior

    /// The target angle to rotate toward (computed in enter())
    private var rotation: Float = 0.0
    /// How fast and in which direction to rotate (sign = direction, magnitude = speed)
    private var rotationVelocity: Float = 0.0

    init(parent: FindAndGoBehavior) {
        self.parent = parent
    }

    /// Compute the target angle and turn direction using the cross product.
    func enter() {
        // Direction vector from ship to target
        let targetDirection = parent.target - parent.parent.position
        // Unit vector representing the ship's current facing direction
        let currentRotationVec = Vec2(angle: parent.parent.rotation)

        // The 2D cross product's sign tells us which way is shorter to turn:
        // positive z = target is counter-clockwise from current facing
        // negative z = target is clockwise from current facing
        let crossZ = currentRotationVec.cross(targetDirection)

        // Random rotation speed (1-3 rad/s), sign matches the turn direction
        rotationVelocity = Float.random(in: 1...3) * ((crossZ < 0) ? -1 : 1)

        // Compute the target angle and wrap it into [0, 2*pi) for consistent comparison
        rotation = targetDirection.angle
        rotation = GameMath.wrap(value: rotation, low: 0, high: GameMath.twoPi)
    }

    func exit() {}

    /// Rotate toward the target each frame. When close enough, snap to the exact angle
    /// and transition to GoState.
    func update(dt: Float) {
        // Apply rotation velocity
        parent.parent.rotation += rotationVelocity * dt
        // Keep rotation in [0, 2*pi) to avoid wraparound comparison issues
        parent.parent.rotation = GameMath.wrap(value: parent.parent.rotation, low: 0, high: GameMath.twoPi)

        // Check if we are within 0.1 radians of the target angle
        if GameMath.isInRange(value: parent.parent.rotation, low: rotation - 0.1, high: rotation + 0.1) {
            // Snap to the exact target angle to prevent drift
            parent.parent.rotation = rotation
            // Transition to GoState to start moving forward
            parent.setToGo()
        }
    }
}

/// **GoState:** The third state in the Find-Rotate-Go loop.
/// Moves the ship forward in its facing direction at a random speed. When the ship
/// reaches the target position (detected via point-in-circle), transitions back to FindState
/// to pick a new target and repeat the cycle.
///
/// **Key engine APIs used:**
/// - `Vec2(angle:)` -- creates a unit direction vector from the ship's rotation
/// - `Intersect.pointCircle(point:circle:radius:)` -- checks if a point is inside a circle.
///   Used here as a proximity test: "has the ship arrived at the target?"
class GoState: State {
    private unowned let parent: FindAndGoBehavior

    init(parent: FindAndGoBehavior) {
        self.parent = parent
    }

    /// Set the ship's velocity to its facing direction at a random speed.
    func enter() {
        // Create a unit vector from the ship's current rotation angle
        var direction = Vec2(angle: parent.parent.rotation)
        // Scale by a random speed (6-10 units/sec)
        direction *= Float.random(in: 6...10)

        parent.parent.velocity = direction
    }

    func exit() {}

    /// Move forward and check if we have reached the target.
    func update(dt: Float) {
        // Euler integration: advance position by velocity * delta time
        parent.parent.position += parent.parent.velocity * dt

        // Intersect.pointCircle checks if the target point is within a circle of radius 2
        // centered on the ship. This is a simple "close enough" arrival check.
        if Intersect.pointCircle(point: parent.target, circle: parent.parent.position, radius: 2) {
            // Arrived at target -- loop back to FindState to pick a new destination
            parent.setToFind()
        }
    }
}
