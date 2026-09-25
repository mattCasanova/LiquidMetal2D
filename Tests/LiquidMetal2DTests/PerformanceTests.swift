import XCTest
@testable import LiquidMetal2D

/// Timing baselines for the hot paths. `measure` prints per-run timings to
/// the test log; compare them before and after a change. These are not
/// pass/fail gates. Numbers are recorded in `~/workspace/LM2D/`:
/// `math-and-hot-path-audit.md`, and `gpu-sprite-transform.md` for shader submit.
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

    /// The ordering `AlphaBlendShader.submit` runs each frame, without the GPU.
    func testAlphaBlendSortOrder() {
        var rng = SeededRandom(seed: 3)
        let objects: [GameObj] = (0..<5000).map { _ in
            let obj = GameObj()
            obj.zOrder = Float(Int.random(in: 0...4, using: &rng))
            obj.add(AlphaBlendComponent(parent: obj, textureID: Int.random(in: 0...7, using: &rng)))
            return obj
        }

        var drawList = DrawList<AlphaBlendComponent>()
        var drawn = 0
        measure {
            drawList.rebuild(from: objects)
            drawn += drawList.pairs.count
        }
        XCTAssertGreaterThan(drawn, 0)
    }

    /// The steady state: objects already in draw order, as in a scene whose
    /// objects don't change z or texture. `DrawList` checks the order in one
    /// pass and skips the sort.
    func testAlphaBlendSortSteadyState() {
        var rng = SeededRandom(seed: 3)
        let shuffled: [GameObj] = (0..<5000).map { _ in
            let obj = GameObj()
            obj.zOrder = Float(Int.random(in: 0...4, using: &rng))
            obj.add(AlphaBlendComponent(parent: obj, textureID: Int.random(in: 0...7, using: &rng)))
            return obj
        }
        var drawList = DrawList<AlphaBlendComponent>()
        drawList.rebuild(from: shuffled)
        let ordered = drawList.pairs.map(\.0)

        var drawn = 0
        measure {
            drawList.rebuild(from: ordered)
            drawn += drawList.pairs.count
            drawList.clear()
        }
        XCTAssertGreaterThan(drawn, 0)
    }

    // MARK: - Shader submit (baselines for the GPU sprite transform)

    /// The real `AlphaBlendShader.submit` for 5,000 sprites already in draw
    /// order: the draw-list pass plus one uniform per sprite, written into
    /// the shader's Metal buffer. 60 frames per run.
    func testAlphaBlendSubmit5k() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 5000)
        let sprites = ShaderTestSupport.makeSprites(count: 5000, seed: 4)

        withExtendedLifetime(renderCore) {
            measureClock {
                for _ in 0..<60 { ShaderTestSupport.submitFrame(shader, objects: sprites) }
            }
        }
    }

    /// Only the per-sprite uniform build and store, the part the GPU sprite
    /// transform changes. 60 frames per run.
    func testAlphaBlendMakeUniform5k() throws {
        let sprites = ShaderTestSupport.makeSprites(count: 5000, seed: 4)
        let components = try sprites.map { try XCTUnwrap($0.get(AlphaBlendComponent.self)) }
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: AlphaBlendUniform.stride * components.count, alignment: 16)
        defer { buffer.deallocate() }

        withExtendedLifetime(sprites) {
            measureClock {
                for _ in 0..<60 {
                    for (index, comp) in components.enumerated() {
                        comp.makeUniform().store(into: buffer, index: index)
                    }
                }
            }
        }
    }

    /// The real `ParticleShader.submit` for one emitter with 10,000 live
    /// particles. It builds each particle's uniform inline, so this is the
    /// particle side of the same cost. 60 frames per run.
    func testParticleSubmit10k() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = ParticleShader(renderCore: renderCore, maxObjects: 10_000)
        let (parent, _) = ShaderTestSupport.makeFullEmitter(count: 10_000, seed: 6)
        let objects = [parent]

        withExtendedLifetime(renderCore) {
            measureClock {
                for _ in 0..<60 { ShaderTestSupport.submitFrame(shader, objects: objects) }
            }
        }
    }

    // MARK: - Helpers

    /// Wall-clock `measure` through the metrics API, 10 runs. Its spread is a
    /// few percent; plain `measure`'s first run is a ~2× outlier that pushes
    /// the spread to 20–30%. (`XCTCPUMetric` reports nothing on the simulator.)
    private func measureClock(_ block: () -> Void) {
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        measure(metrics: [XCTClockMetric()], options: options, block: block)
    }

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

