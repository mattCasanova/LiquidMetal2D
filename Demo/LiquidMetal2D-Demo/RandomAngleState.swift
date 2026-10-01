//
//  RandomCircleState.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/21/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import LiquidMetal2D

/// The single State used by `RandomAngleBehavior`. Spawns a ship at a dynamic position
/// with a random direction, speed, and scale, then moves it each frame until it leaves
/// the visible world bounds, at which point it respawns.
///
/// **How State works in LiquidMetal2D:**
/// The `State` protocol requires three methods:
/// - `enter()` -- called when the state becomes active (initialization / reset logic)
/// - `update(dt:)` -- called every frame while the state is active
/// - `exit()` -- called when transitioning away from this state (cleanup logic)
///
/// This state uses `enter()` to randomize the object and `update(dt:)` to move it and
/// check bounds. Since there is no cleanup needed, `exit()` is empty.
///
/// **Key engine APIs used:**
/// - `GameMath.twoPi` -- convenience constant for 2 * pi
/// - `Vec2.set(angle:)` -- creates a unit direction vector from a rotation angle
/// - `GameMath.isInRange` -- checks if a value falls within [low, high]
/// - `WorldBounds` -- struct with minX, maxX, minY, maxY representing the visible area
class RandomAngleState: State {
    /// Unowned reference to the game object this state controls.
    /// Use `unowned` (not `weak`) because the object always outlives its state --
    /// the GameObj owns the Behavior which owns the State.
    private unowned let obj: GameObj

    /// Closure that returns the current spawn position (e.g., the player's touch location).
    /// Using a closure instead of a stored Vec2 allows the spawn point to change dynamically.
    private let getSpawnLocation: () -> Vec2
    /// Closure that returns the current world bounds for out-of-bounds detection.
    private let getBounds: () -> WorldBounds

    init(obj: GameObj, getSpawnLocation: @escaping () -> Vec2, getBounds: @escaping () -> WorldBounds) {
        self.obj              = obj
        self.getSpawnLocation = getSpawnLocation
        self.getBounds        = getBounds
    }

    /// Called when this state becomes active. Randomizes the object's properties.
    func enter() {
        randomize()
    }

    /// Called when transitioning away. Nothing to clean up for this state.
    func exit() {

    }

    /// Called every frame. Moves the ship and checks if it has left the visible area.
    func update(dt: Float) {
        // Simple Euler integration: position += velocity * deltaTime
        obj.position += obj.velocity * dt

        let bounds = getBounds()

        // GameMath.isInRange checks if a value is within [low, high].
        // If the ship's x or y position is outside the world bounds, respawn it.
        if !GameMath.isInRange(value: obj.position.x, low: bounds.minX, high: bounds.maxX) ||
            !GameMath.isInRange(value: obj.position.y, low: bounds.minY, high: bounds.maxY) {
            randomize()
        }
    }

    /// Resets the object at the current spawn location with random visual and motion properties.
    private func randomize() {
        let spawnLocation = getSpawnLocation()

        obj.zOrder = 0
        obj.position.x = spawnLocation.x
        obj.position.y = spawnLocation.y

        // Random scale creates visual variety and depth illusion
        let scale = Float.random(in: 0.25...1.5)
        obj.scale.set(scale, scale)

        // Random rotation in full circle using GameMath.twoPi (2 * pi)
        obj.rotation = Float.random(in: 0...GameMath.twoPi)
        // Vec2.set(angle:) creates a unit direction vector pointing at the given angle.
        // This makes the ship's velocity direction match its visual rotation.
        obj.velocity.set(angle: obj.rotation)
        // Scale velocity by 5 * scale: larger ships move faster, creating a parallax effect
        obj.velocity *= 5 * scale
        // Randomly assign one of the available textures
        let texIndex = Int.random(in: 0..<GameTextures.all.count)
        if let comp = obj.get(AlphaBlendComponent.self) {
            comp.textureID = GameTextures.all[texIndex]
            comp.tintColor = TokyoNight.shipTints[texIndex]
        }
    }

}
