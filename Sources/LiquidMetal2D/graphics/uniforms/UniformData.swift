//
//  UniformData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/16/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

/// A per-instance GPU uniform: a plain struct whose fields mirror, in order,
/// the matching struct in the shader's `.metalSource`.
///
/// Keep every field a simd type (`Mat4`, `Vec4`, `Vec2`, `Float`) declared in
/// the same order as the MSL struct. ``stride`` then comes from Swift's own
/// layout, padding included, so it matches what the GPU indexes by. A test in
/// `UniformLayoutTests` pins each uniform's stride and offsets.
///
/// `BitwiseCopyable` makes the compiler reject a field that isn't plain bits
/// (a `String`, an array, a class reference): ``store(into:index:)`` copies
/// raw bytes, and the GPU would read pointer bits as floats.
public protocol UniformData: BitwiseCopyable {}

public extension UniformData {
    /// Bytes per instance in the GPU buffer, padding included.
    static var stride: Int { MemoryLayout<Self>.stride }

    /// Writes this uniform into instance slot `index` of `buffer` as one store.
    func store(into buffer: UnsafeMutableRawPointer, index: Int) {
        assert(index >= 0, "\(Self.self) index must be non-negative")
        buffer.storeBytes(of: self, toByteOffset: index * Self.stride, as: Self.self)
    }
}
