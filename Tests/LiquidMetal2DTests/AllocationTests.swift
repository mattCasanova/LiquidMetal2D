import XCTest
@testable import LiquidMetal2D

/// Proves the hot paths that claim "no allocation per frame" actually make
/// none, once warmed up. Each test runs the path once to reach steady state,
/// then counts heap allocations across a second run.
///
/// The zero-allocation tests only mean something in an optimized build:
/// unoptimized code allocates in places the optimizer removes (for example
/// the particle update allocates once per pool slot per frame at -Onone and
/// never at -O). They skip in Debug. Run them with:
///
///     xcodebuild … -configuration Release ENABLE_TESTABILITY=YES test \
///       -only-testing:LiquidMetal2DTests/AllocationTests
///
/// The two positive controls run in every configuration.
@MainActor
final class AllocationTests: XCTestCase {

    /// Components hold their parent `unowned`; keep every test object alive.
    private var keepAlive: [GameObj] = []

    // MARK: - Positive control

    func testCounterSeesAllocations() {
        var sink: [Int] = []
        let count = AllocationCounter.count {
            sink = Array(repeating: 7, count: 100)
        }
        XCTAssertGreaterThanOrEqual(count, 1, "counter missed a known allocation")
        XCTAssertEqual(sink.count, 100)
    }

    func testCounterSeesTheArrayQueryReturns() {
        let grid = makeGrid()
        var found = 0
        let count = AllocationCounter.count {
            found = grid.query(near: Vec2(0, 0)).count
        }
        XCTAssertGreaterThanOrEqual(count, 1, "query(near:) builds an array; the counter must see it")
        XCTAssertGreaterThan(found, 0)
    }

    // MARK: - Spatial grid

    func testForEachPotentialPairAllocatesNothing() throws {
        try requireOptimizedBuild()
        let grid = makeGrid()
        var pairs = 0
        grid.forEachPotentialPair { _, _ in pairs += 1 }

        pairs = 0
        let count = AllocationCounter.count {
            grid.forEachPotentialPair { _, _ in pairs += 1 }
        }

        XCTAssertGreaterThan(pairs, 0)
        XCTAssertEqual(count, 0)
    }

    func testForEachNearAllocatesNothing() throws {
        try requireOptimizedBuild()
        let grid = makeGrid()
        var near = 0
        grid.forEachNear(Vec2(0, 0)) { _ in near += 1 }

        near = 0
        let count = AllocationCounter.count {
            for x in stride(from: Float(-90), through: 90, by: 30) {
                grid.forEachNear(Vec2(x, x)) { _ in near += 1 }
            }
        }

        XCTAssertGreaterThan(near, 0)
        XCTAssertEqual(count, 0)
    }

    func testRebuildingTheGridEachFrameAllocatesNothing() throws {
        try requireOptimizedBuild()
        let grid = makeGrid()
        let objects = keepAlive
        grid.clear()
        grid.insert(contentsOf: objects)

        let count = AllocationCounter.count {
            grid.clear()
            grid.insert(contentsOf: objects)
        }

        XCTAssertEqual(count, 0)
    }

    // MARK: - Draw list

    func testSteadyDrawListRebuildAllocatesNothing() throws {
        try requireOptimizedBuild()
        let objects: [GameObj] = (0..<500).map { index in
            let obj = GameObj()
            obj.zOrder = Float(index % 5)
            obj.add(AlphaBlendComponent(parent: obj, textureID: index % 3))
            return obj
        }
        keepAlive += objects
        var list = DrawList<AlphaBlendComponent>()
        list.rebuild(from: objects)
        let ordered = list.pairs.map(\.0)       // the steady scene: objects already in draw order
        list.clear()
        list.rebuild(from: ordered)
        list.clear()

        let count = AllocationCounter.count {
            list.rebuild(from: ordered)
            list.clear()
        }

        XCTAssertEqual(count, 0)
    }

    // MARK: - Particles

    func testEmitterUpdateAndSpawnAllocateNothing() throws {
        try requireOptimizedBuild()
        let parent = GameObj()
        keepAlive.append(parent)
        let emitter = ParticleEmitterComponent(
            parent: parent,
            maxParticles: 1000,
            textureID: 0,
            emissionRate: 600,
            shape: .circle(radius: 2),
            lifetimeRange: 0.1...0.5,
            endScaleRange: 0.1...0.2,
            startColorVariation: Vec4(1, 0, 0, 1),
            gravity: Vec2(0, -9.8))
        for _ in 0..<120 { emitter.update(dt: 1 / 60) }     // spawn and kill particles until steady

        let count = AllocationCounter.count {
            for _ in 0..<60 { emitter.update(dt: 1 / 60) }
        }

        XCTAssertEqual(count, 0)
    }

    // MARK: - Helpers

    private func requireOptimizedBuild() throws {
        #if DEBUG
        throw XCTSkip("Allocation counts are only meaningful in an optimized build; run with -configuration Release")
        #endif
    }

    private func makeGrid() -> SpatialGrid {
        let bounds = WorldBounds(minX: -100, maxX: 100, minY: -100, maxY: 100)
        let grid = SpatialGrid(bounds: bounds, columns: 20, rows: 20)
        var rng = SeededRandom(seed: 5)
        for _ in 0..<500 {
            let obj = GameObj()
            obj.position = Vec2(Float.random(in: -100...100, using: &rng), Float.random(in: -100...100, using: &rng))
            keepAlive.append(obj)
            grid.insert(obj)
        }
        return grid
    }
}
