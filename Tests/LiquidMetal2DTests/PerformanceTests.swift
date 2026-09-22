import XCTest
@testable import LiquidMetal2D

/// Timing baselines for the hot paths. `measure` prints per-run timings to
/// the test log; compare them before and after a change. These are not
/// pass/fail gates. Numbers are recorded in
/// `~/workspace/LM2D/math-and-hot-path-audit.md`.
///
/// Inputs come from a fixed-seed `SeededRandom` so every run measures the same work.
@MainActor
final class PerformanceTests: XCTestCase {

    private let frameDt: Float = 1 / 60

    // MARK: - Particles

    func testEmitterUpdate10k() {
        let (parent, emitter) = makeEmitter(pool: 10_000, emissionRate: 0)
        emitter.spawn(count: 10_000)

        withExtendedLifetime(parent) {
            measure {
                for _ in 0..<60 { emitter.update(dt: frameDt) }
            }
        }
    }

    func testEmitterSpawnIntoFullPool() {
        let (parent, emitter) = makeEmitter(pool: 5000, emissionRate: 2000)
        emitter.spawn(count: 5000)

        withExtendedLifetime(parent) {
            measure {
                for _ in 0..<60 { emitter.update(dt: frameDt) }
            }
        }
    }

    // MARK: - Spatial grid

    func testSpatialGridPairs5k() {
        let bounds = WorldBounds(minX: -100, maxX: 100, minY: -100, maxY: 100)
        let grid = SpatialGrid(bounds: bounds, columns: 40, rows: 40)
        var rng = SeededRandom(seed: 1)
        let objects: [GameObj] = (0..<5000).map { _ in
            let obj = GameObj()
            obj.position = Vec2(Float.random(in: -100...100, using: &rng), Float.random(in: -100...100, using: &rng))
            return obj
        }

        var pairCount = 0
        measure {
            grid.clear()
            grid.insert(contentsOf: objects)
            grid.forEachPotentialPair { _, _ in pairCount += 1 }
        }
        XCTAssertGreaterThan(pairCount, 0)
    }

    // MARK: - Intersect

    func testIntersectCircleLine1M() {
        var rng = SeededRandom(seed: 2)
        let inputs: [(Vec2, Float, Vec2, Vec2)] = (0..<1000).map { _ in
            (Vec2(Float.random(in: -20...20, using: &rng), Float.random(in: -20...20, using: &rng)),
             Float.random(in: 0.1...5, using: &rng),
             Vec2(Float.random(in: -20...20, using: &rng), Float.random(in: -20...20, using: &rng)),
             Vec2(Float.random(in: -20...20, using: &rng), Float.random(in: -20...20, using: &rng)))
        }

        var hits = 0
        measure {
            for _ in 0..<1000 {
                for (center, radius, start, end) in inputs
                where Intersect.circleLineSegment(center: center, radius: radius, start: start, end: end) {
                    hits += 1
                }
            }
        }
        XCTAssertGreaterThan(hits, 0)
    }

    // MARK: - Shader submit ordering

    /// The sort `AlphaBlendShader.submit` runs each frame, without the GPU:
    /// filter to active objects with the component, sort by (zOrder, textureID).
    func testAlphaBlendSortOrder() {
        var rng = SeededRandom(seed: 3)
        let objects: [GameObj] = (0..<5000).map { _ in
            let obj = GameObj()
            obj.zOrder = Float(Int.random(in: 0...4, using: &rng))
            obj.add(AlphaBlendComponent(parent: obj, textureID: Int.random(in: 0...7, using: &rng)))
            return obj
        }

        var drawn = 0
        measure {
            let pairs: [(GameObj, AlphaBlendComponent)] = objects.compactMap { obj in
                guard obj.isActive, let comp = obj.get(AlphaBlendComponent.self) else { return nil }
                return (obj, comp)
            }.sorted { lhs, rhs in
                if lhs.0.zOrder != rhs.0.zOrder { return lhs.0.zOrder < rhs.0.zOrder }
                return lhs.1.textureID < rhs.1.textureID
            }
            drawn += pairs.count
        }
        XCTAssertGreaterThan(drawn, 0)
    }

    // MARK: - Helpers

    /// Returns the parent too: the emitter holds it `unowned`, so the caller
    /// must keep it alive for as long as the emitter is used.
    private func makeEmitter(pool: Int, emissionRate: Float) -> (GameObj, ParticleEmitterComponent) {
        let obj = GameObj()
        let emitter = ParticleEmitterComponent(
            parent: obj,
            maxParticles: pool,
            textureID: 0,
            emissionRate: emissionRate,
            lifetimeRange: 100...100,
            gravity: Vec2(0, -9.8))
        return (obj, emitter)
    }
}

