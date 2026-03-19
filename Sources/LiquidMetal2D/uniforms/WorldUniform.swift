//
//  WorldUniform.swift
//
//
//  Created by Matt Casanova on 4/24/20.
//

import Foundation

public class WorldUniform: UniformData {
    public var transform: Mat4 = Mat4()
    public var texTrans: Vec4 = Vec4(1, 1, 0, 0)
    public var color: Vec4 = Vec4(1, 1, 1, 1)
    public var size: Int = WorldUniform.typeSize()

    public init() {}

    public func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int) {
        assert(offsetIndex >= 0, "WorldUniform offsetIndex must be non-negative")

        let mtxSize = MemoryLayout<Mat4>.size
        let vecSize = MemoryLayout<Vec4>.size
        let offset = offsetIndex * size

        memcpy(buffer + offset, &transform, mtxSize)
        memcpy(buffer + offset + mtxSize, &texTrans, vecSize)
        memcpy(buffer + offset + mtxSize + vecSize, &color, vecSize)
    }

    public static func typeSize() -> Int {
        return MemoryLayout<Mat4>.size + MemoryLayout<Vec4>.size * 2
    }
}
