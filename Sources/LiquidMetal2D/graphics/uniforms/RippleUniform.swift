//
//  RippleUniform.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

/// Mirrors `RippleUniform` in `RippleShader.metalSource`: `texTrans` (16) +
/// `color` (16) + `params` (16) + `transform` (24) = 72 bytes, 80 with
/// padding. `params` is (time, amplitude, frequency, speed).
public struct RippleUniform: UniformData {
    public var texTrans: Vec4
    public var color: Vec4
    public var params: Vec4
    public var transform: Transform2D

    public init(
        texTrans: Vec4 = Vec4(1, 1, 0, 0),
        color: Vec4 = Vec4(1, 1, 1, 1),
        params: Vec4 = Vec4(0, 0.02, 10, 4),
        transform: Transform2D = Transform2D()
    ) {
        self.texTrans = texTrans
        self.color = color
        self.params = params
        self.transform = transform
    }
}
