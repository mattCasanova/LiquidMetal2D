import XCTest
@testable import LiquidMetal2D

/// What the real shaders queue for one frame (instance slots, texture runs,
/// the uniforms written), checked on the simulator's Metal device.
@MainActor
final class ShaderSubmitTests: XCTestCase {

    func testAlphaBlendQueuesOneBatchPerTextureRun() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 500)
        let sprites = ShaderTestSupport.makeSprites(count: 500, seed: 9)

        withExtendedLifetime(renderCore) {
            ShaderTestSupport.submitFrame(shader, objects: sprites)
        }

        // makeSprites: five z levels, each split across textures 0...7, in draw order.
        let batches = shader.instances.batches
        XCTAssertEqual(batches.map(\.textureId), (0..<40).map { $0 % 8 })
        XCTAssertEqual(batches.first?.startIndex, 0)
        for (previous, next) in zip(batches, batches.dropFirst()) {
            XCTAssertEqual(next.startIndex, previous.startIndex + previous.count)
        }
        XCTAssertEqual(batches.reduce(0) { $0 + $1.count }, 500)
        XCTAssertEqual(shader.instances.count, 500)
    }

    func testSecondSubmitInAFrameTakesTheNextSlots() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 200)
        let first = ShaderTestSupport.makeSprites(count: 100, seed: 10)
        let second = ShaderTestSupport.makeSprites(count: 100, seed: 11)

        withExtendedLifetime(renderCore) {
            XCTAssertTrue(shader.beginFrame())
            shader.submit(objects: first)
            shader.submit(objects: second)
            shader.signalFrameComplete()
        }

        // The first list ends on texture 7 and the second starts on 0, so no run merges.
        XCTAssertEqual(shader.instances.count, 200)
        XCTAssertEqual(shader.instances.batches.count, 80)
        XCTAssertEqual(shader.instances.batches.dropFirst(40).first?.startIndex, 100)
    }

    func testParticlesQueueOneBatchPerEmitter() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = ParticleShader(renderCore: renderCore, maxObjects: 1000)
        let (parent, _) = ShaderTestSupport.makeFullEmitter(count: 1000, seed: 12)

        withExtendedLifetime(renderCore) {
            ShaderTestSupport.submitFrame(shader, objects: [parent])
        }

        XCTAssertEqual(shader.instances.batches,
                       [InstanceBatches.Batch(textureId: 0, startIndex: 0, count: 1000)])
        XCTAssertEqual(shader.instances.count, 1000)
    }

    /// A pass that switches away from the wireframe shader and back flushes
    /// in between. The first flush's draw reads its uniforms when the GPU
    /// runs, after the second submit, so that submit must not reuse them.
    func testWireframeKeepsEarlierInstancesAcrossAFlush() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = WireframeShader(renderCore: renderCore, maxObjects: 8)
        let red = Vec4(1, 0, 0, 1)
        let blue = Vec4(0, 0, 1, 1)
        let first = ShaderTestSupport.makeWireframes(count: 3, color: red)
        let second = ShaderTestSupport.makeWireframes(count: 2, color: blue)
        let projection = try XCTUnwrap(renderCore.device.makeBuffer(length: ProjectionUniform.stride))

        try withExtendedLifetime(renderCore) {
            XCTAssertTrue(shader.beginFrame())
            let pass = try ShaderTestSupport.makeRenderPass(renderCore)
            shader.bind(pass: pass, projectionBuffer: projection)
            shader.submit(objects: first)
            shader.flush(pass: pass)
            shader.bind(pass: pass, projectionBuffer: projection)
            shader.submit(objects: second)
            shader.flush(pass: pass)
            pass.end()
            shader.signalFrameComplete()
        }

        let contents = try XCTUnwrap(shader.worldBufferContents)
        let colorOffset = try XCTUnwrap(MemoryLayout<WireframeUniform>.offset(of: \.color))
        let colors = (0..<5).map {
            contents.load(fromByteOffset: $0 * WireframeUniform.stride + colorOffset, as: Vec4.self)
        }
        XCTAssertEqual(colors, [red, red, red, blue, blue])
    }

    /// Each particle's slot holds its own position, scale, rotation, and the
    /// emitter object's z. The pixel tests draw at z 0 with rotation 0, where
    /// a dropped field would still pass.
    func testParticleUniformsCarryEachParticlesTransform() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = ParticleShader(renderCore: renderCore, maxObjects: 50)
        let (parent, emitter) = ShaderTestSupport.makeFullEmitter(count: 50, seed: 13)
        parent.zOrder = 7

        withExtendedLifetime(renderCore) {
            ShaderTestSupport.submitFrame(shader, objects: [parent])
        }

        let contents = try XCTUnwrap(shader.worldBufferContents)
        let offset = try XCTUnwrap(MemoryLayout<ParticleUniform>.offset(of: \.transform))
        let live = emitter.particles.filter(\.isAlive)
        XCTAssertEqual(live.count, 50)
        XCTAssertTrue(live.contains { $0.rotation != 0 }, "the test needs rotated particles")
        for (index, particle) in live.enumerated() {
            let t = min(particle.age / particle.lifetime, 1)
            let expected = Transform2D(
                position: particle.position, scale: mix(particle.startScale, particle.endScale, t: t),
                rotation: particle.rotation, zOrder: 7)
            let stored = contents.load(fromByteOffset: index * ParticleUniform.stride + offset, as: Transform2D.self)
            XCTAssertEqual(stored, expected, "particle \(index)")
        }
    }

    /// A wireframe slot holds the object's position and z, the collider's size
    /// as scale, and no rotation (colliders are axis-aligned).
    func testWireframeUniformsCarryTheShapeTransform() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = WireframeShader(renderCore: renderCore, maxObjects: 4)
        let objects = ShaderTestSupport.makeWireframes(count: 2, color: Vec4(1, 1, 1, 1))
        objects[0].zOrder = 5
        objects[1].zOrder = 9
        objects[1].rotation = 0.5

        withExtendedLifetime(renderCore) {
            ShaderTestSupport.submitFrame(shader, objects: objects)
        }

        let contents = try XCTUnwrap(shader.worldBufferContents)
        let offset = try XCTUnwrap(MemoryLayout<WireframeUniform>.offset(of: \.transform))
        for (index, obj) in objects.enumerated() {
            let stored = contents.load(fromByteOffset: index * WireframeUniform.stride + offset, as: Transform2D.self)
            XCTAssertEqual(stored, Transform2D(position: obj.position, scale: Vec2(2, 2), zOrder: obj.zOrder),
                           "wireframe \(index)")
        }
    }
}
