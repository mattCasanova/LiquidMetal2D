//
//  ProjectionUniform.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/23/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation

public class ProjectionUniform: UniformData {
    public var transform: Mat4 = Mat4()
    public var size: Int = ProjectionUniform.typeSize()

    public init() {}

    public func setBuffer(buffer: UnsafeMutableRawPointer, offsetIndex: Int) {
        memcpy(buffer + (offsetIndex * size), &transform, size)
    }

    public static func typeSize() -> Int {
        return MemoryLayout<Mat4>.size
    }
}
