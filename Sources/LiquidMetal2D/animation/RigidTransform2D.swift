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
/// Not a matrix. Composing two is a rotate and an add. A sprite drawn at a
/// bone takes its place from ``Transform2D/init(_:scale:zOrder:)``, which adds
/// the size; the vertex shader builds the matrix.
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

extension RigidTransform2D {
    private enum CodingKeys: String, CodingKey { case position, rotation }

    /// A file may leave out either field; it is zero, as in code (``AnimationFiles``).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            position: try container.decodeIfPresent(Vec2.self, forKey: .position) ?? Vec2(),
            rotation: try container.decodeIfPresent(Float.self, forKey: .rotation) ?? 0)
    }
}
