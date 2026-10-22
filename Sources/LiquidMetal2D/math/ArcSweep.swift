//
//  ArcSweep.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/22/26.
//

/// The first thing a thrown or jumping box hits along its arc, and every
/// point along the way: a preview draws ``samples`` and the thing itself
/// steps along the same array, so the preview is the outcome.
///
/// The arc is stepped at a fixed ``dt`` (the struct's, never the frame's),
/// so two sweeps with the same inputs give the same points whatever the
/// frame rate. Each step is the segment `p(t) → p(t + dt)`, tested against
/// every box grown by `halfSize` (a box moving through boxes is a point
/// moving through fatter boxes) and every wall segment; the earliest hit
/// along the step wins, a tie going to the box. A start point already
/// inside a grown box is a hit at time 0 with the nearest face's normal,
/// so a caller sees it instead of tunnelling out. A step that only grazes
/// a corner counts (the box test is closed).
///
/// The buffers keep their capacity: a steady frame allocates nothing
/// (``AllocationTests`` pins it). Pure math, no `@MainActor`. What a hit
/// means (floor, wall, hazard, legal launch) stays in the game.
public struct ArcSweep {
    /// Which obstacle was hit: an index into the array passed to ``trace``.
    public enum Obstacle: Equatable, Sendable {
        case box(Int)
        case wall(Int)
    }

    public struct Hit: Equatable, Sendable {
        /// Where the moving thing's centre is when it touches.
        public var point: Vec2
        /// The unit normal of the face or wall it touches, facing the arc.
        public var normal: Vec2
        /// Seconds after launch, the fraction within the step included.
        public var time: Float
        public var obstacle: Obstacle

        public init(point: Vec2, normal: Vec2, time: Float, obstacle: Obstacle) {
            self.point = point
            self.normal = normal
            self.time = time
            self.obstacle = obstacle
        }
    }

    public enum Result: Equatable, Sendable {
        case hit(Hit)
        /// Nothing was hit before `endTime` (the step that reached `maxTime`).
        case noHit(endTime: Float)
    }

    /// Every stepped position from the start up to and including the hit
    /// point, or up to the last step before `maxTime`.
    public private(set) var samples: [Vec2]
    /// The last trace's hit, nil after a trace that hit nothing.
    public private(set) var hit: Hit?
    /// Seconds per step.
    public let dt: Float

    /// `dt` above 0; `capacity` is how many samples to make room for up front.
    public init(dt: Float = 1 / 60, capacity: Int = 256) {
        precondition(dt > 0, "ArcSweep: dt must be above 0, got \(dt)")
        self.dt = dt
        samples = []
        samples.reserveCapacity(capacity)
    }

    /// Steps the arc from `start` until it hits a box or a wall or reaches
    /// `maxTime`. `halfSize` grows every box by the moving thing's half
    /// extents. `boxes` is generic so a game passes its own box type
    /// without copying. `maxTime` above 0, `halfSize` not negative.
    @discardableResult
    public mutating func trace(
        from start: Vec2, velocity: Vec2, gravity: Vec2, halfSize: Vec2 = .zero,
        boxes: [some AABB], walls: [LineSegment] = [], maxTime: Float = 4
    ) -> Result {
        precondition(maxTime > 0, "ArcSweep.trace: maxTime must be above 0, got \(maxTime)")
        precondition(halfSize.x >= 0 && halfSize.y >= 0, "ArcSweep.trace: halfSize must not be negative")
        samples.removeAll(keepingCapacity: true)
        hit = nil
        samples.append(start)
        var point = start
        var time: Float = 0
        while time < maxTime {
            let nextTime = time + dt
            let next = Ballistics.position(start: start, velocity: velocity, gravity: gravity, at: nextTime)
            if let found = firstHit(from: point, to: next, halfSize: halfSize, boxes: boxes, walls: walls) {
                let contact = point + (next - point) * found.fraction
                samples.append(contact)
                let hit = Hit(point: contact, normal: found.normal, time: time + dt * found.fraction,
                              obstacle: found.obstacle)
                self.hit = hit
                return .hit(hit)
            }
            samples.append(next)
            point = next
            time = nextTime
        }
        return .noHit(endTime: time)
    }

    private struct StepHit {
        var fraction: Float
        var normal: Vec2
        var obstacle: Obstacle
    }

    /// The earliest hit along one step, boxes before walls at the same fraction.
    private func firstHit(
        from point: Vec2, to next: Vec2, halfSize: Vec2, boxes: [some AABB], walls: [LineSegment]
    ) -> StepHit? {
        var best: StepHit?
        var bestFraction = Float.infinity
        for index in boxes.indices {
            let box = boxes[index]
            guard let found = Intersect.segmentAABB(
                start: point, end: next, center: box.center,
                width: box.width + 2 * halfSize.x, height: box.height + 2 * halfSize.y)
            else { continue }
            if found.t < bestFraction {
                bestFraction = found.t
                best = StepHit(fraction: found.t, normal: found.normal, obstacle: .box(index))
            }
        }
        let step = LineSegment(start: point, end: next)
        for index in walls.indices {
            let wall = walls[index]
            guard let fraction = Intersect.segmentSegment(step, wall), fraction < bestFraction else { continue }
            bestFraction = fraction
            best = StepHit(fraction: fraction, normal: Self.normal(of: wall, facing: point), obstacle: .wall(index))
        }
        return best
    }

    /// The wall's unit normal on the side `point` is on.
    private static func normal(of wall: LineSegment, facing point: Vec2) -> Vec2 {
        let edge = wall.end - wall.start
        let normal = Vec2(-edge.y, edge.x).normalized
        return simd_dot(normal, point - wall.start) >= 0 ? normal : -normal
    }
}
