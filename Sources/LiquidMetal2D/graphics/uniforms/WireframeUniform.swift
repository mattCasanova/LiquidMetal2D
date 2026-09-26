//
//  WireframeUniform.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

/// Mirrors `WireframeUniform` in `WireframeShader.metalSource`: `color`
/// (16) + `params` (16) + `transform` (24) = 56 bytes, 64 with padding.
/// `params.x` is the shape selector, `params.y` the outline thickness.
public struct WireframeUniform: UniformData {
    public var color: Vec4
    public var params: Vec4
    public var transform: Transform2D

    public init(
        color: Vec4 = Vec4(0, 1, 0, 1),
        params: Vec4 = Vec4(0, 0.05, 0, 0),
        transform: Transform2D = Transform2D()
    ) {
        self.color = color
        self.params = params
        self.transform = transform
    }
}
