//
//  ParticleUniform.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

/// Mirrors `ParticleUniform` in `ParticleShader.metalSource`: `transform`
/// (64) + already-interpolated `color` (16) = 80 bytes. The emitter lerps
/// start→end on the CPU, so the GPU just multiplies texture × color.
public struct ParticleUniform: UniformData {
    public var transform: Mat4
    public var color: Vec4

    public init(transform: Mat4 = Mat4(), color: Vec4 = Vec4(1, 1, 1, 1)) {
        self.transform = transform
        self.color = color
    }
}
