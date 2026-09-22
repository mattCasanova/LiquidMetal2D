//
//  RigidTransform2D.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

/// A rigid 2D transform: a position and a rotation, no scale.
///
/// Used for bones, which only ever rotate and translate. Angles are radians,
/// counter-clockwise positive, with y up.
///
/// Not a matrix. Composing two is a rotate and an add. The 4×4 matrix a sprite
/// is drawn with comes later, from `Mat4.makeTransform2D` / `setToTransform2D`.
public struct RigidTransform2D: Equatable, Codable, Sendable {
    public var position: Vec2
    public var rotation: Float

    public static let identity = RigidTransform2D()

    public init(position: Vec2 = Vec2(), rotation: Float = 0) {
        self.position = position
        self.rotation = rotation
    }

    /// Returns `self ∘ child`: the child's transform expressed in this transform's parent space.
    public func composed(with child: RigidTransform2D) -> RigidTransform2D {
        RigidTransform2D(
            position: position + child.position.rotated(by: rotation),
            rotation: rotation + child.rotation)
    }

    /// Maps a point from this transform's local space into its parent space.
    public func apply(to point: Vec2) -> Vec2 {
        position + point.rotated(by: rotation)
    }
}
