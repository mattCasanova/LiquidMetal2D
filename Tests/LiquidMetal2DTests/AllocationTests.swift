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

    // MARK: - Input

    func testInputFrameAllocatesNothing() throws {
        try requireOptimizedBuild()
        let input = InputSystem(devices: [.pointer, .keyboard], unproject: { $0 })
        let feed = {
            input.enqueue(.down(.leftShift))
            input.enqueue(.down(.a))
            input.enqueue(.pointerMoved(Vec2(10, 20)))
            input.enqueue(.scroll(Vec2(0, 1)))
            input.enqueue(.touchBegan(id: 1, Vec2(5, 5)))
            input.enqueue(.touchBegan(id: 2, Vec2(9, 9)))
            input.enqueue(.touchMoved(id: 2, Vec2(8, 8)))
            _ = input.beginFrame()
            input.enqueue(.up(.a))
            input.enqueue(.up(.leftShift))
            input.enqueue(.touchEnded(id: 1))
            input.enqueue(.touchEnded(id: 2))
            input.enqueue(.focusLost)
            _ = input.beginFrame()
        }
        feed()

        let count = AllocationCounter.count(feed)

        XCTAssertEqual(count, 0)
    }

    func testInputSetQueriesAllocateNothing() throws {
        try requireOptimizedBuild()
        let system = InputSystem(devices: [.pointer, .keyboard], unproject: { $0 })
        let input: InputReader = system   // scenes hold the existential
        let jump: [InputCode] = [.space, .w, .gamepadA, .pointerPrimary]
        let undo: [InputCode] = [.command, .z]
        system.enqueue(.down(.leftCommand))
        system.beginFrame()
        system.enqueue(.down(.z))
        system.beginFrame()
        var hits = 0
        let query = {
            if input.isTriggered(anyOf: jump) { hits += 1 }
            if input.isPressed(anyOf: jump) { hits += 1 }
            if input.isPressed(allOf: undo) { hits += 1 }
            if input.isReleased(anyOf: jump) { hits += 1 }
            if input.isComboTriggered(undo) { hits += 1 }
        }
        query()

        hits = 0
        let count = AllocationCounter.count(query)

        XCTAssertEqual(hits, 2, "allOf and the combo")
        XCTAssertEqual(count, 0)
    }

    func testActionLookupsAllocateNothing() throws {
        try requireOptimizedBuild()
        let system = InputSystem(devices: [.pointer, .keyboard], unproject: { $0 })
        let input: InputReader = system
        let bindings = InputBindings<AllocationAction>(defaults: [
            .jump: [.space, .w, .gamepadA], .left: [.a, .arrowLeft], .right: [.d, .arrowRight]
        ])
        system.enqueue(.down(.space))
        system.enqueue(.down(.d))
        system.beginFrame()
        var total: Float = 0
        let query = {
            if input.isTriggered(.jump, in: bindings) { total += 1 }
            if input.isPressed(.left, in: bindings) { total += 10 }
            total += input.axis(negative: .left, positive: .right, in: bindings)
            if input.firstTriggeredCode() != nil { total += 100 }
        }
        query()

        total = 0
        let count = AllocationCounter.count(query)

        XCTAssertEqual(total, 102)
        XCTAssertEqual(count, 0)
    }

    // MARK: - Spatial grid

    func testVisibilityPolygonComputeAllocatesNothing() throws {
        try requireOptimizedBuild()
        var walls: [LineSegment] = []
        for i in 0..<5 {
            let center = Vec2(Float(i) * 6 - 12, Float(i % 2) * 4)
            LineSegment.appendEdges(ofCenter: center, width: 3, height: 2, to: &walls)
        }
        var polygon = VisibilityPolygon()
        polygon.compute(from: Vec2(0, 1), radius: 20, walls: walls)

        let count = AllocationCounter.count {
            for frame in 0..<50 {
                polygon.compute(from: Vec2(Float(frame % 7) - 3, 1), radius: 20, walls: walls)
            }
        }

        XCTAssertEqual(count, 0)
        XCTAssertGreaterThan(polygon.points.count, 48, "the walls were in range")
    }

    func testLightMapAddAllocatesNothing() throws {
        try requireOptimizedBuild()
        let renderCore = try ShaderTestSupport.makeRenderCore()
        renderCore.resize(scale: 1, layerSize: CGSize(width: 64, height: 64))
        let lightMap = LightMap(renderCore: renderCore, maxLights: 16, maxVertices: 2000, resolutionScale: 1)
        var lights: [Light] = []
        for i in 0..<10 {
            var light = Light(position: Vec2(Float(i) * 3 - 15, 0), radius: 8, color: Vec3(1, 0.5, 0.2))
            if i % 2 == 0 { light.halfAngle = 0.5 }
            lights.append(light)
        }
        var total = 0

        for _ in 0..<3 {
            XCTAssertTrue(lightMap.begin())
            total += withExtendedLifetime(renderCore) {
                AllocationCounter.count {
                    for light in lights { lightMap.add(light) }
                }
            }
            lightMap.commit(viewProjection: Mat4.makeOrthographic(
                left: -32, right: 32, bottom: -32, top: 32, nearZ: -100, farZ: 100))
        }

        XCTAssertEqual(total, 0)
    }

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

    // MARK: - Shader submit

    func testSteadyAlphaBlendSubmitAllocatesNothing() throws {
        try requireOptimizedBuild()
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 500)
        let sprites = ShaderTestSupport.makeSprites(count: 500, seed: 7)
        keepAlive += sprites
        ShaderTestSupport.submitFrame(shader, objects: sprites)     // grow the draw list and batches once

        let count = withExtendedLifetime(renderCore) {
            AllocationCounter.count { ShaderTestSupport.submitFrame(shader, objects: sprites) }
        }

        XCTAssertEqual(count, 0)
    }

    func testParticleSubmitAllocatesNothing() throws {
        try requireOptimizedBuild()
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = ParticleShader(renderCore: renderCore, maxObjects: 1000)
        let (parent, _) = ShaderTestSupport.makeFullEmitter(count: 1000, seed: 8)
        keepAlive.append(parent)
        let objects = [parent]
        ShaderTestSupport.submitFrame(shader, objects: objects)

        let count = withExtendedLifetime(renderCore) {
            AllocationCounter.count { ShaderTestSupport.submitFrame(shader, objects: objects) }
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

    // MARK: - Skeleton

    /// An IK chain whose target moves every frame: the working pose and the
    /// bone transforms are reused, and moving the target in place allocates nothing.
    func testSkeletonUpdateWithIKAllocatesNothing() throws {
        try requireOptimizedBuild()
        let rig = SkeletonDefinition(
            bones: [Bone(name: "upper", parent: nil, length: 2, rest: RigidTransform2D()),
                    Bone(name: "lower", parent: 0, length: 1.5, rest: RigidTransform2D(position: Vec2(2, 0)))],
            attachments: [Attachment(name: "forearm", bone: 1, size: Vec2(1.5, 0.3), offset: Vec2(0.75, 0))])
        let root = GameObj()
        keepAlive.append(root)
        let skeleton = try SkeletonComponent(parent: root, definition: rig, defaultTextureID: 0)
        skeleton.ikConstraints = [try IKConstraint(upper: 0, lower: 1, in: rig, target: Vec2(1, 2))]
        skeleton.update(dt: 1 / 60)

        let count = AllocationCounter.count {
            for frame in 0..<60 {
                skeleton.ikConstraints[0].target = Vec2(1, 2).rotated(by: Float(frame) * 0.05)
                skeleton.update(dt: 1 / 60)
            }
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

private enum AllocationAction: String, InputAction {
    case jump, left, right
}
