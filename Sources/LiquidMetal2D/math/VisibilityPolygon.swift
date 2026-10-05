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
public struct VisibilityPolygon {
    /// The outline from the last ``compute(from:radius:walls:direction:halfAngle:)``,
    /// counter-clockwise by angle. Closed for an all-round light; for a cone
    /// it runs from one edge to the other and the origin closes it.
    public private(set) var points: [Vec2]

    /// Angles relative to the sweep's start, in `[0, 2π)`, sorted before casting.
    private var angles: [Float]
    /// The walls within `radius` of the origin this call.
    private var wallsInRange: [LineSegment]

    private static let spokes = 48
    private static let cornerNudge: Float = 1e-4

    public init(capacity: Int = 512) {
        points = []
        points.reserveCapacity(capacity)
        angles = []
        angles.reserveCapacity(capacity)
        wallsInRange = []
        wallsInRange.reserveCapacity(64)
    }

    /// Recomputes ``points`` for a light at `origin` reaching `radius`.
    /// `direction` and `halfAngle` (radians) make it a cone; `halfAngle`
    /// `.pi`, the default, is all round. `radius` must be positive and
    /// `halfAngle` in `(0, π]`: anything else is a programmer error.
    public mutating func compute(
        from origin: Vec2, radius: Float, walls: [LineSegment], direction: Float = 0, halfAngle: Float = .pi
    ) {
        precondition(radius > 0, "VisibilityPolygon: radius must be positive, got \(radius)")
        precondition(halfAngle > 0 && halfAngle <= .pi, "VisibilityPolygon: halfAngle must be in (0, π]")
        points.removeAll(keepingCapacity: true)
        angles.removeAll(keepingCapacity: true)
        wallsInRange.removeAll(keepingCapacity: true)

        let isCone = halfAngle < .pi
        let sweepStart = isCone ? direction - halfAngle : 0
        let sweepWidth = isCone ? 2 * halfAngle : 2 * Float.pi

        for wall in walls where wall.start != wall.end && Self.isInRange(wall, origin: origin, radius: radius) {
            wallsInRange.append(wall)
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
            for wall in wallsInRange {
                if let hit = Intersect.raySegment(origin: origin, direction: ray, start: wall.start, end: wall.end),
                   hit < distance {
                    distance = hit
                }
            }
            points.append(origin + ray * distance)
        }
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
