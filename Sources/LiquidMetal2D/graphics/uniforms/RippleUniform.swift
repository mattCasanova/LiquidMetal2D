//
//  RippleUniform.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Foundation

/// Per-instance uniform for ``RippleShader``.
///
/// Layout: `transform` (Mat4, 64B), `texTrans` (Vec4, 16B), `color` (Vec4, 16B),
/// `params` (Vec4, 16B). Total 112B.
///
/// `params` fields: `(time, amplitude, frequency, speed)`. Scene advances
/// `time` per-frame; the fragment shader offsets UV samples by
/// `sin(time * speed + uv * frequency) * amplitude`.
public final class RippleUniform: UniformData {
    public var transform: Mat4 = Mat4()
    public var texTrans: Vec4 = Vec4(1, 1, 0, 0)
    public var color: Vec4 = Vec4(1, 1, 1, 1)
    public var params: Vec4 = Vec4(0, 0.02, 10, 4)
    public var size: Int = RippleUniform.typeSize()

    public init() {}

    public func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int) {
        assert(offsetIndex >= 0, "RippleUniform offsetIndex must be non-negative")

        let mtxSize = MemoryLayout<Mat4>.size
        let vecSize = MemoryLayout<Vec4>.size
        let offset = offsetIndex * size

        memcpy(buffer + offset, &transform, mtxSize)
        memcpy(buffer + offset + mtxSize, &texTrans, vecSize)
        memcpy(buffer + offset + mtxSize + vecSize, &color, vecSize)
        memcpy(buffer + offset + mtxSize + vecSize * 2, &params, vecSize)
    }

    public static func typeSize() -> Int {
        return MemoryLayout<Mat4>.size + MemoryLayout<Vec4>.size * 3
    }
}
