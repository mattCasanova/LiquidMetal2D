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
public final class RippleComponent: Component {
    public unowned var parent: GameObj
    public var textureID: Int
    public var tintColor: Vec4
    public var texTrans: Vec4

    /// Scene-advanced clock. Mutate per-frame: `comp.time += dt`.
    public var time: Float = 0
    /// Max UV offset, in UV space. Typical: 0.01..0.05.
    public var amplitude: Float = 0.02
    /// Spatial frequency — number of wave cycles across the sprite.
    public var frequency: Float = 10
    /// Temporal speed multiplier.
    public var speed: Float = 4

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

    func fillUniform(_ uniform: RippleUniform) {
        uniform.transform.setToTransform2D(
            scale: parent.scale,
            angle: parent.rotation,
            translate: Vec3(parent.position, parent.zOrder))
        uniform.texTrans = texTrans
        uniform.color = tintColor
        uniform.params = Vec4(time, amplitude, frequency, speed)
    }
}
