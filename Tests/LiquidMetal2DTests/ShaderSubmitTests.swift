import XCTest
@testable import LiquidMetal2D

/// What the real shaders queue for one frame (instance slots and texture
/// runs), checked on the simulator's Metal device without drawing.
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
        XCTAssertEqual(shader.instances.batches[40].startIndex, 100)
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
}
