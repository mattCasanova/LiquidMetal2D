//
//  ParticleUniform.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Foundation

/// Per-particle uniform for ``ParticleShader``. Minimal — just transform and
/// already-interpolated color (the emitter lerps start→end on the CPU during
/// uniform assembly, so the GPU just multiplies texture × color).
///
/// Layout: `transform` (Mat4, 64B) + `color` (Vec4, 16B) = 80B total.
public final class ParticleUniform: UniformData {
    public var transform: Mat4 = Mat4()
    public var color: Vec4 = Vec4(1, 1, 1, 1)
    public var size: Int = ParticleUniform.typeSize()

    public init() {}

    public func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int) {
        assert(offsetIndex >= 0, "ParticleUniform offsetIndex must be non-negative")

        let mtxSize = MemoryLayout<Mat4>.size
        let vecSize = MemoryLayout<Vec4>.size
        let offset = offsetIndex * size

        memcpy(buffer + offset, &transform, mtxSize)
        memcpy(buffer + offset + mtxSize, &color, vecSize)
    }

    public static func typeSize() -> Int {
        return MemoryLayout<Mat4>.size + MemoryLayout<Vec4>.size
    }
}
