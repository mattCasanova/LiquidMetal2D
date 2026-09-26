//
//  ParticleUniform.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

/// Mirrors `ParticleUniform` in `ParticleShader.metalSource`: already-
/// interpolated `color` (16) + `transform` (24) = 40 bytes, 48 with padding.
/// The emitter lerps start→end on the CPU, so the GPU just multiplies
/// texture × color.
public struct ParticleUniform: UniformData {
    public var color: Vec4
    public var transform: Transform2D

    public init(color: Vec4 = Vec4(1, 1, 1, 1), transform: Transform2D = Transform2D()) {
        self.color = color
        self.transform = transform
    }
}
