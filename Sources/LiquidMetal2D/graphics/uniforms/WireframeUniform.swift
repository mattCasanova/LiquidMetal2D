//
//  WireframeUniform.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

/// Mirrors `WireframeUniform` in `WireframeShader.metalSource`: `transform`
/// (64) + `color` (16) + `params` (16) = 96 bytes. `params.x` is the shape
/// selector, `params.y` the outline thickness.
public struct WireframeUniform: UniformData {
    public var transform: Mat4
    public var color: Vec4
    public var params: Vec4

    public init(
        transform: Mat4 = Mat4(),
        color: Vec4 = Vec4(0, 1, 0, 1),
        params: Vec4 = Vec4(0, 0.05, 0, 0)
    ) {
        self.transform = transform
        self.color = color
        self.params = params
    }
}
