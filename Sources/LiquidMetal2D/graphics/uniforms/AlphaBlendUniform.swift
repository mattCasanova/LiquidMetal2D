//
//  AlphaBlendUniform.swift
//
//
//  Created by Matt Casanova on 4/24/20.
//

/// Mirrors `AlphaBlendUniform` in `AlphaBlendShader.metalSource`:
/// `texTrans` (16) + `color` (16) + `transform` (24) = 56 bytes, 64 with the
/// padding to the `float4`s' 16-byte alignment.
public struct AlphaBlendUniform: UniformData {
    public var texTrans: Vec4
    public var color: Vec4
    public var transform: Transform2D

    public init(
        texTrans: Vec4 = Vec4(1, 1, 0, 0),
        color: Vec4 = Vec4(1, 1, 1, 1),
        transform: Transform2D = Transform2D()
    ) {
        self.texTrans = texTrans
        self.color = color
        self.transform = transform
    }
}
