//
//  MoveRightStateFOV.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/17/26.
//

import LiquidMetal2D

/// Variant of `MoveRightState` with a configurable z-depth range.
/// Used by the FOV demo to keep ships at a comfortable middle distance
/// so narrow FOV doesn't result in extreme close-ups.
///
/// The z range is passed at init time, unlike `MoveRightState` which
/// hardcodes 0..60.
class MoveRightStateFOV: State {
    private unowned let obj: GameObj

    private let getBounds: (_ zOrder: Float) -> WorldBounds
    private let zRange: ClosedRange<Float>
    private var bounds = WorldBounds(minX: 0, maxX: 0, minY: 0, maxY: 0)

    init(obj: GameObj, getBounds: @escaping (_ zOrder: Float) -> WorldBounds,
         zRange: ClosedRange<Float>) {
        self.obj = obj
        self.getBounds = getBounds
        self.zRange = zRange
    }

    func enter() {
        randomize()
    }

    func exit() {}

    func update(dt: Float) {
        obj.position += obj.velocity * dt

        if !GameMath.isInRange(value: obj.position.x, low: bounds.minX, high: bounds.maxX) ||
            !GameMath.isInRange(value: obj.position.y, low: bounds.minY, high: bounds.maxY) {
            randomize()
        }
    }

    private func randomize() {
        obj.zOrder = Float.random(in: zRange)
        bounds = getBounds(obj.zOrder)

        obj.position.x = bounds.minX
        obj.position.y = Float.random(in: bounds.minY / 2...bounds.maxY / 2)

        obj.scale.set(1, 1)
        obj.rotation = 0
        obj.velocity.set(Float.random(in: 2...8), 0)
        obj.get(AlphaBlendComponent.self)?.textureID = GameTextures.all.randomElement()!
    }
}
