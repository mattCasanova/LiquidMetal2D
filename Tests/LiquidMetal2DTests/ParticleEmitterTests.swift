import XCTest
@testable import LiquidMetal2D

private extension ParticleEmitterComponent {
    var aliveCount: Int { particles.filter(\.isAlive).count }
}

@MainActor
final class ParticleEmitterTests: XCTestCase {

    private let frameDt: Float = 1 / 60

    /// The emitter holds its parent `unowned`, so the test case keeps every
    /// parent alive until teardown.
    private var parents: [GameObj] = []

    private func makeEmitter(
        pool: Int,
        emissionRate: Float = 0,
        lifetime: Float = 100,
        gravity: Vec2 = Vec2()
    ) -> ParticleEmitterComponent {
        let parent = GameObj()
        parents.append(parent)
        return ParticleEmitterComponent(
            parent: parent,
            maxParticles: pool,
            textureID: 0,
            emissionRate: emissionRate,
            lifetimeRange: lifetime...lifetime,
            speedRange: 1...1,
            angleRange: 0...0,
            gravity: gravity)
    }

    // MARK: - Spawning

    func testSpawnCountMatchesRateOverOneSecond() {
        let emitter = makeEmitter(pool: 1000, emissionRate: 60)

        for _ in 0..<60 { emitter.update(dt: frameDt) }

        XCTAssertTrue((59...61).contains(emitter.aliveCount), "spawned \(emitter.aliveCount)")
    }

    func testSpawnTimingFollowsInterval() {
        // Rate 0.5/s: one spawn at t = 0, the next at t = 2, then t = 4.
        let emitter = makeEmitter(pool: 100, emissionRate: 0.5)

        emitter.update(dt: 1)
        XCTAssertEqual(emitter.aliveCount, 1)
        emitter.update(dt: 1)
        XCTAssertEqual(emitter.aliveCount, 2)
        emitter.update(dt: 1)
        XCTAssertEqual(emitter.aliveCount, 2)
    }

    func testBurstCapsAtPoolSize() {
        let emitter = makeEmitter(pool: 10)

        emitter.spawn(count: 25)

        XCTAssertEqual(emitter.aliveCount, 10)
    }

    func testBurstFillsSlotsFromTheFront() {
        let emitter = makeEmitter(pool: 4)

        emitter.spawn(count: 2)

        XCTAssertTrue(emitter.particles[0].isAlive)
        XCTAssertTrue(emitter.particles[1].isAlive)
        XCTAssertFalse(emitter.particles[2].isAlive)
    }

    func testFullPoolSpawnsNothingMore() {
        let emitter = makeEmitter(pool: 5, emissionRate: 1000)

        emitter.update(dt: 1)
        emitter.update(dt: 1)

        XCTAssertEqual(emitter.aliveCount, 5)
    }

    func testFullPoolDropsBacklogInsteadOfBursting() {
        let emitter = makeEmitter(pool: 100, emissionRate: 1000, lifetime: 1)
        emitter.update(dt: 1)                       // fills the pool; ~0.9 s of spawns dropped
        XCTAssertEqual(emitter.aliveCount, 100)

        emitter.isEmitting = false
        emitter.update(dt: 2)                       // everything dies, nothing spawns
        XCTAssertEqual(emitter.aliveCount, 0)

        emitter.isEmitting = true
        emitter.update(dt: frameDt)                 // one frame's worth, not the backlog

        XCTAssertTrue((16...18).contains(emitter.aliveCount), "spawned \(emitter.aliveCount)")
    }

    func testFreedSlotIsReused() {
        let emitter = makeEmitter(pool: 1, lifetime: 0.5)
        emitter.spawn(count: 1)
        XCTAssertEqual(emitter.aliveCount, 1)

        emitter.update(dt: 0.6)
        XCTAssertEqual(emitter.aliveCount, 0)

        emitter.spawn(count: 1)
        XCTAssertEqual(emitter.aliveCount, 1)
    }

    func testEverySlotComesBackAfterAFullCycle() {
        let emitter = makeEmitter(pool: 50, lifetime: 1)

        for _ in 0..<3 {
            emitter.spawn(count: 50)
            XCTAssertEqual(emitter.aliveCount, 50)
            emitter.update(dt: 2)
            XCTAssertEqual(emitter.aliveCount, 0)
        }
    }

    func testZeroLifetimeDoesNotLeakSlots() {
        let emitter = makeEmitter(pool: 3, lifetime: 0)

        emitter.spawn(count: 3)
        emitter.spawn(count: 3)
        XCTAssertEqual(emitter.aliveCount, 0)

        // The slots must still be usable for particles that live.
        emitter.lifetimeRange = 1...1
        emitter.spawn(count: 3)
        XCTAssertEqual(emitter.aliveCount, 3)
    }

    // MARK: - Seeded randomness

    private func makeRandomizedEmitter(seed: UInt64) -> ParticleEmitterComponent {
        let parent = GameObj()
        parents.append(parent)
        return ParticleEmitterComponent(
            parent: parent,
            maxParticles: 10,
            textureID: 0,
            shape: .circle(radius: 3),
            lifetimeRange: 0.5...2,
            speedRange: 1...5,
            angleRange: -1...1,
            scaleRange: 0.5...1.5,
            angularVelocityRange: -1...1,
            startColorVariation: Vec4(1, 0, 0, 1),
            random: SeededRandom(seed: seed))
    }

    func testSameSeedSpawnsIdenticalParticles() {
        let a = makeRandomizedEmitter(seed: 99)
        let b = makeRandomizedEmitter(seed: 99)

        a.spawn(count: 10)
        b.spawn(count: 10)

        for index in 0..<10 {
            XCTAssertEqual(a.particles[index].position, b.particles[index].position)
            XCTAssertEqual(a.particles[index].velocity, b.particles[index].velocity)
            XCTAssertEqual(a.particles[index].lifetime, b.particles[index].lifetime)
            XCTAssertEqual(a.particles[index].startColor, b.particles[index].startColor)
        }
    }

    func testDifferentSeedsSpawnDifferentParticles() {
        let a = makeRandomizedEmitter(seed: 1)
        let b = makeRandomizedEmitter(seed: 2)

        a.spawn(count: 1)
        b.spawn(count: 1)

        XCTAssertNotEqual(a.particles[0].velocity, b.particles[0].velocity)
    }

    // MARK: - Update

    func testParticleDiesAtLifetime() {
        let emitter = makeEmitter(pool: 1, lifetime: 1)
        emitter.spawn(count: 1)

        emitter.update(dt: 0.99)
        XCTAssertEqual(emitter.aliveCount, 1)

        emitter.update(dt: 0.02)
        XCTAssertEqual(emitter.aliveCount, 0)
    }

    func testGravityIntegratesVelocity() {
        let emitter = makeEmitter(pool: 1, gravity: Vec2(0, -10))
        emitter.spawn(count: 1)
        let startVelocity = emitter.particles[0].velocity

        emitter.update(dt: 0.5)

        XCTAssertEqual(emitter.particles[0].velocity.y, startVelocity.y - 5, accuracy: 0.0001)
    }

    func testVelocityMovesPosition() {
        // angleRange 0...0 and parent rotation 0: velocity is +x at speed 1.
        let emitter = makeEmitter(pool: 1)
        emitter.spawn(count: 1)
        let start = emitter.particles[0].position

        emitter.update(dt: 0.5)

        XCTAssertEqual(emitter.particles[0].position.x, start.x + 0.5, accuracy: 0.0001)
        XCTAssertEqual(emitter.particles[0].position.y, start.y, accuracy: 0.0001)
    }

    func testNotEmittingStopsSpawningButKeepsUpdating() {
        let emitter = makeEmitter(pool: 10, emissionRate: 60, lifetime: 1)
        emitter.spawn(count: 1)
        emitter.isEmitting = false

        emitter.update(dt: 0.5)
        XCTAssertEqual(emitter.aliveCount, 1)
        XCTAssertEqual(emitter.particles[0].age, 0.5, accuracy: 0.0001)

        emitter.update(dt: 0.6)
        XCTAssertEqual(emitter.aliveCount, 0)
    }
}
