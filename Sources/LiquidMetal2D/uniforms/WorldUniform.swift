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
    public var size: Int = WorldUniform.typeSize()

    public init() {}

    public func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int) {
        assert(offsetIndex >= 0, "WorldUniform offsetIndex must be non-negative")

        let mtxSize = MemoryLayout<Mat4>.size
        let texSize = MemoryLayout<Vec4>.size

        memcpy(buffer + (offsetIndex * size), &transform, mtxSize)
        memcpy(buffer + (offsetIndex * size + mtxSize), &texTrans, texSize)
    }

    public static func typeSize() -> Int {
        return MemoryLayout<Mat4>.size + MemoryLayout<Vec4>.size
    }
}
