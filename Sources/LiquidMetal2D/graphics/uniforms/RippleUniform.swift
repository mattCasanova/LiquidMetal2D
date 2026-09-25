//
//  RippleUniform.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

/// Mirrors `RippleUniform` in `RippleShader.metalSource`: `transform` (64) +
/// `texTrans` (16) + `color` (16) + `params` (16) = 112 bytes. `params` is
/// (time, amplitude, frequency, speed).
public struct RippleUniform: UniformData {
    public var transform: Mat4
    public var texTrans: Vec4
    public var color: Vec4
    public var params: Vec4

    public init(
        transform: Mat4 = Mat4(),
        texTrans: Vec4 = Vec4(1, 1, 0, 0),
        color: Vec4 = Vec4(1, 1, 1, 1),
        params: Vec4 = Vec4(0, 0.02, 10, 4)
    ) {
        self.transform = transform
        self.texTrans = texTrans
        self.color = color
        self.params = params
    }
}
