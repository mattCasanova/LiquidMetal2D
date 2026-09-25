//
//  AlphaBlendUniform.swift
//
//
//  Created by Matt Casanova on 4/24/20.
//

/// Mirrors `AlphaBlendUniform` in `AlphaBlendShader.metalSource`:
/// `transform` (64) + `texTrans` (16) + `color` (16) = 96 bytes.
public struct AlphaBlendUniform: UniformData {
    public var transform: Mat4
    public var texTrans: Vec4
    public var color: Vec4

    public init(
        transform: Mat4 = Mat4(),
        texTrans: Vec4 = Vec4(1, 1, 0, 0),
        color: Vec4 = Vec4(1, 1, 1, 1)
    ) {
        self.transform = transform
        self.texTrans = texTrans
        self.color = color
    }
}
