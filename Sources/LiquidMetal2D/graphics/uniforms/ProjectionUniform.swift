//
//  ProjectionUniform.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/23/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

/// Mirrors `ProjectionUniform` in every `.metalSource`: one matrix, 64 bytes.
public struct ProjectionUniform: UniformData {
    public var transform: Mat4

    public init(transform: Mat4 = Mat4()) {
        self.transform = transform
    }
}
