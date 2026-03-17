//
//  WorldBounds.swift
//
//
//  Created by Matt Casanova on 3/20/20.
//

/// Axis-aligned bounding rectangle in world space.
public struct WorldBounds {
    public let minX: Float
    public let maxX: Float
    public let minY: Float
    public let maxY: Float

    /// Creates world bounds with the given extents.
    /// - Precondition: `minX <= maxX` and `minY <= maxY`.
    public init(minX: Float, maxX: Float, minY: Float, maxY: Float) {
        precondition(minX <= maxX, "minX (\(minX)) must be <= maxX (\(maxX))")
        precondition(minY <= maxY, "minY (\(minY)) must be <= maxY (\(maxY))")

        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
    }

    /// The horizontal size of the bounds.
    public var width: Float { maxX - minX }

    /// The vertical size of the bounds.
    public var height: Float { maxY - minY }

    /// The center point of the bounds.
    public var center: Vec2 { Vec2((minX + maxX) / 2, (minY + maxY) / 2) }

    /// Whether the given point is inside or on the edge of the bounds.
    public func contains(_ point: Vec2) -> Bool {
        return point.x >= minX && point.x <= maxX
            && point.y >= minY && point.y <= maxY
    }
}
