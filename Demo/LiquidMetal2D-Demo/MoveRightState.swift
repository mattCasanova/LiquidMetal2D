//
//  MoveRightState.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/22/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import LiquidMetal2D

/// The single State used by `MoveRightBehavior`. Moves a ship to the right and respawns it
/// at the left edge with a new random z-depth when it exits the visible area.
///
/// **Z-depth and perspective bounds:**
/// Each ship is assigned a random zOrder (0..60), which places it at a different depth in
/// the perspective projection. Ships at higher z values appear smaller (further away) and
/// have different visible bounds than ships at z=0. The `getBounds` closure recalculates
/// the world-space rectangle for each ship's specific depth, ensuring correct wrapping.
///
/// **Key engine APIs used:**
/// - `GameMath.isInRange(value:low:high:)` -- bounds checking
/// - `WorldBounds` -- struct with minX, maxX, minY, maxY for the visible rectangle at a depth
/// - `Vec2.set(_:_:)` -- sets both components of a 2D vector
class MoveRightState: State {
    /// Unowned reference to the game object. The object owns Behavior owns State,
    /// so the object always outlives the state.
    private unowned let obj: GameObj

    /// Closure that returns the visible world bounds for a given z-depth.
    /// This allows bounds to change based on how far the ship is from the camera.
    private let getBounds: (_ zOrder: Float) -> WorldBounds
    /// Cached bounds for this ship's current zOrder, recalculated on each respawn.
    private var bounds = WorldBounds(minX: 0, maxX: 0, minY: 0, maxY: 0)

    init(obj: GameObj, getBounds: @escaping (_ zOrder: Float) -> WorldBounds) {
        self.obj       = obj
        self.getBounds = getBounds
    }

    /// Called when the state becomes active. Randomizes the ship's starting properties.
    func enter() {
        randomize()
    }

    /// Nothing to clean up when exiting this state.
    func exit() {

    }

    /// Called every frame. Moves the ship right and checks if it has left the visible area.
    func update(dt: Float) {
        // Euler integration: move by velocity * delta time
        obj.position += obj.velocity * dt

        // Check if the ship has left its depth-specific visible bounds
        if !GameMath.isInRange(value: obj.position.x, low: bounds.minX, high: bounds.maxX) ||
            !GameMath.isInRange(value: obj.position.y, low: bounds.minY, high: bounds.maxY) {
            randomize()
        }
    }

    /// Respawns the ship at the left edge with a new random z-depth, y position, speed, and texture.
    private func randomize() {
        // Assign a random z-depth (0..60). Higher z = further from camera = appears smaller.
        obj.zOrder = Float.random(in: 0...60)

        // Recalculate visible bounds for this new depth. Ships at higher z have wider bounds
        // because more world space is visible at greater distances in perspective projection.
        bounds = getBounds(obj.zOrder)

        // Start at the left edge of the visible area at this depth
        obj.position.x = bounds.minX
        // Randomize y within the center half of the visible height to avoid edge clustering
        obj.position.y = Float.random(in: bounds.minY/2...bounds.maxY/2)

        obj.scale.set(1, 1)
        // rotation = 0 means facing right (along +x axis)
        obj.rotation = 0
        // Velocity is purely horizontal (rightward) with random speed
        obj.velocity.set(Float.random(in: 2...10), 0)
        let texIndex = Int.random(in: 0...2)
        if let comp = obj.get(AlphaBlendComponent.self) {
            comp.textureID = GameTextures.all[texIndex]
            comp.tintColor = TokyoNight.shipTints[texIndex]
        }
    }

}
