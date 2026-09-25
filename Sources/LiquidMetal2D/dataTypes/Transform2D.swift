//
//  Transform2D.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/25/26.
//

/// Where a sprite sits: position, scale, rotation (radians) and z. Shaders
/// get this per instance and build the matrix on the GPU (`spriteWorld` in
/// each `.metalSource`): the same matrix
/// `Mat4.makeTransform2D(scale:angle:translate:)` builds from these values.
///
/// The fields mirror `struct Transform2D` in every `.metalSource`, in order;
/// `UniformLayoutTests` pins the layout (24 bytes).
public struct Transform2D: Equatable, Sendable, BitwiseCopyable {
    public var position: Vec2
    public var scale: Vec2
    public var rotation: Float
    public var zOrder: Float

    @inlinable
    public init(position: Vec2 = Vec2(), scale: Vec2 = Vec2(1, 1), rotation: Float = 0, zOrder: Float = 0) {
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.zOrder = zOrder
    }
}
