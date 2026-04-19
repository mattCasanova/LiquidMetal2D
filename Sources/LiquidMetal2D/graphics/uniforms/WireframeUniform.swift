//
//  WireframeUniform.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Foundation

/// Per-instance uniform for ``WireframeShader``.
///
/// Layout: `transform` (Mat4, 64B), `color` (Vec4, 16B), `params` (Vec4, 16B).
/// Total 96B. `params.x` encodes the shape (0 = circle, 1 = AABB).
/// `params.y` is outline thickness in UV space (0..0.5).
public final class WireframeUniform: UniformData {
    public var transform: Mat4 = Mat4()
    public var color: Vec4 = Vec4(0, 1, 0, 1)
    public var params: Vec4 = Vec4(0, 0.05, 0, 0)
    public var size: Int = WireframeUniform.typeSize()

    public init() {}

    public func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int) {
        assert(offsetIndex >= 0, "WireframeUniform offsetIndex must be non-negative")

        let mtxSize = MemoryLayout<Mat4>.size
        let vecSize = MemoryLayout<Vec4>.size
        let offset = offsetIndex * size

        memcpy(buffer + offset, &transform, mtxSize)
        memcpy(buffer + offset + mtxSize, &color, vecSize)
        memcpy(buffer + offset + mtxSize + vecSize, &params, vecSize)
    }

    public static func typeSize() -> Int {
        return MemoryLayout<Mat4>.size + MemoryLayout<Vec4>.size * 2
    }
}
