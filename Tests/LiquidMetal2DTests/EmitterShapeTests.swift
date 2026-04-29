import XCTest
@testable import LiquidMetal2D

@MainActor
private func makeEmitter(
    at parentPos: Vec2 = Vec2(),
    rotation: Float = 0,
    localOffset: Vec2 = Vec2(),
    shape: EmitterShape,
    pool: Int = 200
) -> (parent: GameObj, emitter: ParticleEmitterComponent) {
    let obj = GameObj()
    obj.position = parentPos
    obj.rotation = rotation
    let emitter = ParticleEmitterComponent(
        parent: obj,
        maxParticles: pool,
        textureID: 0,
        localOffset: localOffset,
        shape: shape,
        speedRange: 0...0,
        angleRange: 0...0)
    return (obj, emitter)
}

@MainActor
final class EmitterShapeTests: XCTestCase {

    // MARK: - .point — preserves historical behavior

    func testPointSpawnsAtParentPlusLocalOffset() {
        let (parent, emitter) = makeEmitter(
            at: Vec2(10, 20),
            localOffset: Vec2(3, 4),
            shape: .point)
        _ = parent  // keep parent alive (unowned ref from emitter)

        emitter.spawn(count: 50)

        for particle in emitter.particles where particle.isAlive {
            XCTAssertEqual(particle.position.x, 13, accuracy: 1e-5)
            XCTAssertEqual(particle.position.y, 24, accuracy: 1e-5)
        }
    }

    // MARK: - .line — samples on segment

    func testLineSamplesLieOnSegment() {
        // Horizontal line from (-3, 0) to (3, 0), no localOffset, no rotation.
        let (parent, emitter) = makeEmitter(
            shape: .line(from: Vec2(-3, 0), to: Vec2(3, 0)))
        _ = parent

        emitter.spawn(count: 200)

        for particle in emitter.particles where particle.isAlive {
            XCTAssertGreaterThanOrEqual(particle.position.x, -3 - 1e-5)
            XCTAssertLessThanOrEqual(particle.position.x, 3 + 1e-5)
            XCTAssertEqual(particle.position.y, 0, accuracy: 1e-5)
        }
    }

    func testLineRespectsLocalOffset() {
        // Line offset by (0, 5): segment lives along y = 5.
        let (parent, emitter) = makeEmitter(
            localOffset: Vec2(0, 5),
            shape: .line(from: Vec2(-3, 0), to: Vec2(3, 0)))
        _ = parent

        emitter.spawn(count: 200)

        for particle in emitter.particles where particle.isAlive {
            XCTAssertGreaterThanOrEqual(particle.position.x, -3 - 1e-5)
            XCTAssertLessThanOrEqual(particle.position.x, 3 + 1e-5)
            XCTAssertEqual(particle.position.y, 5, accuracy: 1e-5)
        }
    }

    // MARK: - .box — samples inside rectangle

    func testBoxSamplesStayInsideHalfExtents() {
        let (parent, emitter) = makeEmitter(
            shape: .box(halfExtents: Vec2(2, 1)))
        _ = parent

        emitter.spawn(count: 200)

        for particle in emitter.particles where particle.isAlive {
            XCTAssertGreaterThanOrEqual(particle.position.x, -2 - 1e-5)
            XCTAssertLessThanOrEqual(particle.position.x, 2 + 1e-5)
            XCTAssertGreaterThanOrEqual(particle.position.y, -1 - 1e-5)
            XCTAssertLessThanOrEqual(particle.position.y, 1 + 1e-5)
        }
    }

    // MARK: - .circle — samples inside disc

    func testCircleSamplesStayInsideRadius() {
        let radius: Float = 4
        let (parent, emitter) = makeEmitter(
            shape: .circle(radius: radius))
        _ = parent

        emitter.spawn(count: 500)

        for particle in emitter.particles where particle.isAlive {
            let distance = sqrt(
                particle.position.x * particle.position.x +
                particle.position.y * particle.position.y)
            XCTAssertLessThanOrEqual(distance, radius + 1e-4)
        }
    }

    // MARK: - Parent rotation also rotates the shape sample

    func testShapeRotatesWithParent() {
        // Horizontal line + 90° parent rotation → samples land along the
        // y-axis (rotated by π/2: (x, 0) → (0, x)).
        let (parent, emitter) = makeEmitter(
            rotation: .pi / 2,
            shape: .line(from: Vec2(-3, 0), to: Vec2(3, 0)))
        _ = parent

        emitter.spawn(count: 200)

        for particle in emitter.particles where particle.isAlive {
            XCTAssertEqual(particle.position.x, 0, accuracy: 1e-4)
            XCTAssertGreaterThanOrEqual(particle.position.y, -3 - 1e-4)
            XCTAssertLessThanOrEqual(particle.position.y, 3 + 1e-4)
        }
    }
}

// MARK: - Codable round-trip

final class EmitterShapeCodableTests: XCTestCase {

    private func roundTrip(_ shape: EmitterShape) throws -> EmitterShape {
        let data = try JSONEncoder().encode(shape)
        return try JSONDecoder().decode(EmitterShape.self, from: data)
    }

    func testPointRoundTrips() throws {
        let result = try roundTrip(.point)
        guard case .point = result else {
            return XCTFail("expected .point, got \(result)")
        }
    }

    func testLineRoundTrips() throws {
        let original = EmitterShape.line(from: Vec2(-3, 1), to: Vec2(3, 1))
        let result = try roundTrip(original)
        guard case let .line(from, to) = result else {
            return XCTFail("expected .line, got \(result)")
        }
        XCTAssertEqual(from.x, -3); XCTAssertEqual(from.y, 1)
        XCTAssertEqual(to.x, 3); XCTAssertEqual(to.y, 1)
    }

    func testBoxRoundTrips() throws {
        let result = try roundTrip(.box(halfExtents: Vec2(2, 1.5)))
        guard case let .box(halfExtents) = result else {
            return XCTFail("expected .box, got \(result)")
        }
        XCTAssertEqual(halfExtents.x, 2)
        XCTAssertEqual(halfExtents.y, 1.5)
    }

    func testCircleRoundTrips() throws {
        let result = try roundTrip(.circle(radius: 4.25))
        guard case let .circle(radius) = result else {
            return XCTFail("expected .circle, got \(result)")
        }
        XCTAssertEqual(radius, 4.25)
    }
}
