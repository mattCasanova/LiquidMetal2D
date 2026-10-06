//
//  VisibilityPolygon.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/5/26.
//

import Foundation

/// The area a light (or a guard's eyes) reaches before walls stop it: an
/// outline around an origin, out to `radius`, cut short wherever a
/// `LineSegment` is in the way. Pass ``points`` to a light map as the
/// light's shape and the walls cast shadows.
///
/// An angular sweep: one ray per interesting angle (each wall endpoint in
/// range, a hair either side of it so the outline sees past corners, 48
/// evenly spaced angles so the open parts follow the circle, and a cone's
/// two edges), each shortened to the nearest wall it crosses. Points come
/// out counter-clockwise. The buffers keep their capacity, so a steady
/// frame allocates nothing. Pure math, no `@MainActor`.
///
/// A light on a wall's line (a lamp on a box's edge, a guard standing
/// against a wall) sees only the wall's right side: counter-clockwise walls,
/// as ``LineSegment/appendEdges(ofCenter:width:height:to:)`` makes them,
/// keep the inside of their box dark. A lone wall is one-sided there.
public struct VisibilityPolygon {
    /// The outline from the last ``compute(from:radius:walls:direction:halfAngle:)``,
    /// counter-clockwise by angle. Closed for an all-round light; for a cone
    /// it runs from one edge to the other and the origin closes it.
    public private(set) var points: [Vec2]

    /// Angles relative to the sweep's start, in `[0, 2π)`, sorted before casting.
    private var angles: [Float]
    /// The walls within `radius` of the origin this call, not counting those it sits on.
    private var wallsInRange: [LineSegment]
    /// The walls the origin sits on: they block by their winding, not by a ray cast.
    private var touchingWalls: [TouchingWall]

    private static let spokes = 48
    private static let cornerNudge: Float = 1e-4
    /// Closer than this to a wall's line counts as on it.
    private static let touchDistance: Float = 1e-3
    /// A ray this close to running along the wall is not blocked by it:
    /// which side float noise puts it on is luck, and a sliver along the
    /// wall's face never shows.
    private static let grazing: Float = 1e-5

    private struct TouchingWall {
        /// Unit vector from start to end.
        var edge: Vec2
        var atStart: Bool
        var atEnd: Bool
    }

    public init(capacity: Int = 512) {
        points = []
        points.reserveCapacity(capacity)
        angles = []
        angles.reserveCapacity(capacity)
        wallsInRange = []
        wallsInRange.reserveCapacity(64)
        touchingWalls = []
        touchingWalls.reserveCapacity(16)
    }

    /// Recomputes ``points`` for a light at `origin` reaching `radius`.
    /// `direction` and `halfAngle` (radians) make it a cone; `halfAngle`
    /// `.pi`, the default, is all round. A `radius` of 0 is a light turned
    /// off: no points. A negative radius or a `halfAngle` outside `(0, π]`
    /// is a programmer error (an assert; no points in Release).
    public mutating func compute(
        from origin: Vec2, radius: Float, walls: [LineSegment], direction: Float = 0, halfAngle: Float = .pi
    ) {
        assert(radius >= 0, "VisibilityPolygon: radius must not be negative, got \(radius)")
        assert(halfAngle > 0 && halfAngle <= .pi, "VisibilityPolygon: halfAngle must be in (0, π], got \(halfAngle)")
        points.removeAll(keepingCapacity: true)
        angles.removeAll(keepingCapacity: true)
        wallsInRange.removeAll(keepingCapacity: true)
        touchingWalls.removeAll(keepingCapacity: true)
        guard radius > 0, halfAngle > 0, halfAngle <= .pi else { return }

        let isCone = halfAngle < .pi
        let sweepStart = isCone ? direction - halfAngle : 0
        let sweepWidth = isCone ? 2 * halfAngle : 2 * Float.pi

        for wall in walls where wall.start != wall.end && Self.isInRange(wall, origin: origin, radius: radius) {
            if let touching = Self.touch(of: wall, at: origin) {
                touchingWalls.append(touching)
            } else {
                wallsInRange.append(wall)
            }
            addCornerAngles(of: wall.start, origin: origin, radius: radius, sweepStart: sweepStart, width: sweepWidth)
            addCornerAngles(of: wall.end, origin: origin, radius: radius, sweepStart: sweepStart, width: sweepWidth)
        }
        let step = 2 * Float.pi / Float(Self.spokes)
        for spoke in 0..<Self.spokes {
            addAngle(Float(spoke) * step, sweepStart: sweepStart, width: sweepWidth)
        }
        if isCone {
            angles.append(0)
            angles.append(sweepWidth)
        }
        sortAngles()

        var previous: Float = -1
        for relative in angles where relative != previous {
            previous = relative
            let angle = sweepStart + relative
            let ray = Vec2(cos(angle), sin(angle))
            var distance = radius
            if isBlockedAtOrigin(ray) {
                distance = 0
            } else {
                for wall in wallsInRange {
                    if let hit = Intersect.raySegment(origin: origin, direction: ray, start: wall.start, end: wall.end),
                       hit < distance {
                        distance = hit
                    }
                }
            }
            points.append(origin + ray * distance)
        }
    }

    /// The wall as one the origin sits on, or nil when it doesn't. A ray
    /// cast from a point on a wall's line hits it at distance 0 whichever
    /// way it goes, so such walls block by their winding instead.
    private static func touch(of wall: LineSegment, at origin: Vec2) -> TouchingWall? {
        let edge = wall.end - wall.start
        let length = edge.length
        let along = simd_dot(origin - wall.start, edge) / length
        let fraction = min(max(along / length, 0), 1)
        let closest = wall.start + edge * fraction
        guard (origin - closest).lengthSquared <= touchDistance * touchDistance else { return nil }
        return TouchingWall(
            edge: edge / length, atStart: along <= touchDistance, atEnd: length - along <= touchDistance)
    }

    /// A wall the origin sits on blocks the rays heading to its left, the
    /// inside of a counter-clockwise box; at an endpoint only those that
    /// also head along the wall's span.
    private func isBlockedAtOrigin(_ ray: Vec2) -> Bool {
        for wall in touchingWalls where wall.edge.cross(ray) > Self.grazing {
            let along = simd_dot(ray, wall.edge)
            if wall.atStart && along <= 0 { continue }
            if wall.atEnd && along >= 0 { continue }
            return true
        }
        return false
    }

    /// In-place heapsort. The standard library's `sort()` is a merge sort
    /// that allocates a scratch buffer at this size; a light per frame must not.
    private mutating func sortAngles() {
        let count = angles.count
        guard count > 1 else { return }
        for root in stride(from: count / 2 - 1, through: 0, by: -1) {
            siftDown(from: root, until: count)
        }
        for end in stride(from: count - 1, to: 0, by: -1) {
            angles.swapAt(0, end)
            siftDown(from: 0, until: end)
        }
    }

    private mutating func siftDown(from start: Int, until end: Int) {
        var root = start
        while true {
            var largest = root
            let left = 2 * root + 1
            let right = left + 1
            if left < end && angles[left] > angles[largest] { largest = left }
            if right < end && angles[right] > angles[largest] { largest = right }
            if largest == root { return }
            angles.swapAt(root, largest)
            root = largest
        }
    }

    /// A box check: a wall whose bounding box is outside the light's can't cast a shadow in it.
    private static func isInRange(_ wall: LineSegment, origin: Vec2, radius: Float) -> Bool {
        let minimum = simd_min(wall.start, wall.end)
        let maximum = simd_max(wall.start, wall.end)
        return maximum.x >= origin.x - radius && minimum.x <= origin.x + radius
            && maximum.y >= origin.y - radius && minimum.y <= origin.y + radius
    }

    /// A wall endpoint within reach adds its own angle and one a hair either
    /// side, so one ray stops at the corner and the next slips past it.
    private mutating func addCornerAngles(
        of corner: Vec2, origin: Vec2, radius: Float, sweepStart: Float, width: Float
    ) {
        let delta = corner - origin
        guard delta.lengthSquared <= radius * radius else { return }
        let angle = delta.angle
        addAngle(angle - Self.cornerNudge, sweepStart: sweepStart, width: width)
        addAngle(angle, sweepStart: sweepStart, width: width)
        addAngle(angle + Self.cornerNudge, sweepStart: sweepStart, width: width)
    }

    /// Stores `angle` relative to the sweep's start; a cone drops angles outside its arc.
    private mutating func addAngle(_ angle: Float, sweepStart: Float, width: Float) {
        var relative = (angle - sweepStart).truncatingRemainder(dividingBy: 2 * .pi)
        if relative < 0 { relative += 2 * .pi }
        if relative >= 2 * .pi - 1e-6 { relative = 0 }
        guard relative <= width + 1e-6 else { return }
        angles.append(min(relative, width))
    }
}
