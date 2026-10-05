//
//  LineSegment.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/5/26.
//

/// A wall for the lighting math: a straight edge from `start` to `end`.
public struct LineSegment: Equatable, Sendable {
    public var start: Vec2
    public var end: Vec2

    public init(start: Vec2, end: Vec2) {
        self.start = start
        self.end = end
    }

    /// Appends the four edges of an axis-aligned box, counter-clockwise from
    /// its bottom-left corner.
    public static func appendEdges(
        ofCenter center: Vec2, width: Float, height: Float, to segments: inout [LineSegment]
    ) {
        let half = Vec2(width / 2, height / 2)
        let bottomLeft = center - half
        let bottomRight = Vec2(center.x + half.x, center.y - half.y)
        let topRight = center + half
        let topLeft = Vec2(center.x - half.x, center.y + half.y)
        segments.append(LineSegment(start: bottomLeft, end: bottomRight))
        segments.append(LineSegment(start: bottomRight, end: topRight))
        segments.append(LineSegment(start: topRight, end: topLeft))
        segments.append(LineSegment(start: topLeft, end: bottomLeft))
    }
}
