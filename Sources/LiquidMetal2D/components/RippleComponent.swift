//
//  RippleComponent.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Foundation

/// Render state for ``RippleShader``. Renders a textured sprite with a
/// sinusoidal UV-offset distortion (water / heat-wave effect).
///
/// The scene is responsible for advancing ``time`` each frame (typically
/// `comp.time += dt`). Tweak ``amplitude``, ``frequency``, and ``speed``
/// to tune the effect.
public final class RippleComponent: TexturedComponent {
    public unowned let parent: GameObj
    // Plain values read every frame: no run-time exclusivity check (see GameObj).
    @exclusivity(unchecked) public var textureID: Int
    @exclusivity(unchecked) public var tintColor: Vec4
    @exclusivity(unchecked) public var texTrans: Vec4

    /// Scene-advanced clock. Mutate per-frame: `comp.time += dt`.
    @exclusivity(unchecked) public var time: Float = 0
    /// Max UV offset, in UV space. Typical: 0.01..0.05.
    @exclusivity(unchecked) public var amplitude: Float = 0.02
    /// Spatial frequency — number of wave cycles across the sprite.
    @exclusivity(unchecked) public var frequency: Float = 10
    /// Temporal speed multiplier.
    @exclusivity(unchecked) public var speed: Float = 4

    public init(
        parent: GameObj,
        textureID: Int,
        tintColor: Vec4 = Vec4(1, 1, 1, 1),
        texTrans: Vec4 = Vec4(1, 1, 0, 0),
        amplitude: Float = 0.02,
        frequency: Float = 10,
        speed: Float = 4
    ) {
        self.parent = parent
        self.textureID = textureID
        self.tintColor = tintColor
        self.texTrans = texTrans
        self.amplitude = amplitude
        self.frequency = frequency
        self.speed = speed
    }

    func makeUniform() -> RippleUniform {
        return RippleUniform(
            texTrans: texTrans,
            color: tintColor,
            params: Vec4(time, amplitude, frequency, speed),
            transform: parent.transform)
    }
}
