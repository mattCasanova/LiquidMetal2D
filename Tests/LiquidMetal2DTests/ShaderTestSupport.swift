import Metal
import UIKit
import XCTest
@testable import LiquidMetal2D

/// Helpers for tests that run the real shaders on the simulator's Metal
/// device. Nothing here draws: a test frame is `beginFrame`, `submit` and
/// `signalFrameComplete`, which builds every uniform into the shader's own
/// GPU buffer and stops before encoding.
@MainActor
enum ShaderTestSupport {

    /// A `RenderCore` on the system Metal device. Shaders hold it `unowned`,
    /// so the test must keep it alive while they're in use. Skips, instead
    /// of hitting `RenderCore`'s `fatalError`, on a host with no Metal device.
    static func makeRenderCore() throws -> RenderCore {
        _ = try makeDevice()
        return RenderCore(parentView: UIView())
    }

    /// The system Metal device, or a skip on a host without one.
    static func makeDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this host")
        }
        return device
    }

    /// `count` sprites with seeded position, scale and rotation, already in
    /// draw order (as a steady scene's list arrives each frame): five z
    /// levels, each split across eight textures, so 40 batches.
    static func makeSprites(count: Int, seed: UInt64) -> [GameObj] {
        var rng = SeededRandom(seed: seed)
        return (0..<count).map { index in
            let obj = GameObj()
            obj.position = Vec2(Float.random(in: -50...50, using: &rng), Float.random(in: -50...50, using: &rng))
            obj.scale = Vec2(Float.random(in: 0.5...2, using: &rng), Float.random(in: 0.5...2, using: &rng))
            obj.rotation = Float.random(in: -Float.pi...Float.pi, using: &rng)
            obj.zOrder = Float(index * 5 / count)
            obj.add(AlphaBlendComponent(parent: obj, textureID: index * 40 / count % 8))
            return obj
        }
    }

    /// An emitter holding `count` live particles with seeded, varied
    /// rotation and scale. They live 100 s, so none die during a test.
    /// Returns the parent too: the emitter holds it `unowned`.
    static func makeFullEmitter(count: Int, seed: UInt64) -> (GameObj, ParticleEmitterComponent) {
        let parent = GameObj()
        let emitter = ParticleEmitterComponent(
            parent: parent,
            maxParticles: count,
            textureID: 0,
            emissionRate: 0,
            shape: .circle(radius: 20),
            lifetimeRange: 100...100,
            angleRange: -Float.pi...Float.pi,
            endScaleRange: 0.1...0.2,
            endColor: Vec4(1, 0.5, 0, 0),
            random: SeededRandom(seed: seed))
        parent.add(emitter)
        emitter.spawn(count: count)
        return (parent, emitter)
    }

    /// A render pass on a 64×64 drawable, for tests that encode real draws.
    static func makeRenderPass(_ renderCore: RenderCore) throws -> RenderPass {
        renderCore.resize(scale: 1, layerSize: CGSize(width: 64, height: 64))
        return try XCTUnwrap(RenderPass(renderCore: renderCore), "the test layer gave no drawable")
    }

    /// `count` objects in a row, each with a circle collider outlined in `color`.
    static func makeWireframes(count: Int, color: Vec4) -> [GameObj] {
        return (0..<count).map { index in
            let obj = GameObj()
            obj.position = Vec2(Float(index) * 3, 0)
            obj.add(CircleCollider(parent: obj, radius: 1))
            obj.add(WireframeComponent(parent: obj, color: color))
            return obj
        }
    }

    /// One frame's CPU side: take this frame's buffer, write every uniform,
    /// hand the buffer back. The real engine signals when the GPU finishes;
    /// with no GPU work, the buffer is free at once.
    static func submitFrame(_ shader: some Shader, objects: [GameObj]) {
        guard shader.beginFrame() else {
            XCTFail("\(type(of: shader)).beginFrame timed out; a frame's buffer was never signalled back")
            return
        }
        shader.submit(objects: objects)
        shader.signalFrameComplete()
    }
}
