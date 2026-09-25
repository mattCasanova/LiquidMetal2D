import Metal
import QuartzCore
import XCTest
@testable import LiquidMetal2D

/// Draws real objects through each real shader into a 64×64 texture and reads
/// the pixels back: the only tests that check what the `.metalSource` vertex
/// and fragment code actually put on screen. The projection maps one world unit
/// to one pixel, x and y in -32…32, y up, so each check names a world point.
@MainActor
final class OffscreenRenderTests: XCTestCase {

    private static let white = SIMD4<UInt8>(255, 255, 255, 255)
    private static let clear = SIMD4<UInt8>(0, 0, 0, 0)

    /// A 16×8 sprite centred at (8, 4) covers x 0…16, y 0…8. Each check sits
    /// half a pixel inside or outside an edge.
    func testAlphaBlendSpriteCoversItsRectangle() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 4)
        let sprite = Self.makeObject(position: Vec2(8, 4), scale: Vec2(16, 8))
        sprite.add(AlphaBlendComponent(parent: sprite, textureID: renderCore.textureManager.defaultTextureId))

        let image = try Self.render(shader, objects: [sprite], renderCore: renderCore)

        Self.assertRectangle(image, xRange: 0...16, yRange: 0...8)
    }

    /// A 32×2 bar turned +45° lies along y = x: rotation is counter-clockwise
    /// in the y-up world. Clockwise would put it along y = -x.
    func testAlphaBlendRotatesCounterClockwise() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 4)
        let bar = Self.makeObject(position: Vec2(0, 0), scale: Vec2(32, 2), rotation: Float.pi / 4)
        bar.add(AlphaBlendComponent(parent: bar, textureID: renderCore.textureManager.defaultTextureId))

        let image = try Self.render(shader, objects: [bar], renderCore: renderCore)

        XCTAssertEqual(image.pixel(at: Vec2(8.5, 8.5)), Self.white)
        XCTAssertEqual(image.pixel(at: Vec2(-8.5, -8.5)), Self.white)
        XCTAssertEqual(image.pixel(at: Vec2(8.5, -8.5)), Self.clear)
        XCTAssertEqual(image.pixel(at: Vec2(-8.5, 8.5)), Self.clear)
    }

    /// With no ripple the ripple shader draws the same rectangle.
    func testRippleSpriteCoversItsRectangle() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = RippleShader(renderCore: renderCore, maxObjects: 4)
        let sprite = Self.makeObject(position: Vec2(8, 4), scale: Vec2(16, 8))
        sprite.add(RippleComponent(
            parent: sprite, textureID: renderCore.textureManager.defaultTextureId, amplitude: 0))

        let image = try Self.render(shader, objects: [sprite], renderCore: renderCore)

        Self.assertRectangle(image, xRange: 0...16, yRange: 0...8)
    }

    /// One 16-wide particle at (8, 4), additive: bright at its centre, nothing
    /// outside its quad or on the mirrored side.
    func testParticleDrawsAtItsPosition() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = ParticleShader(renderCore: renderCore, maxObjects: 4)
        let parent = Self.makeObject(position: Vec2(8, 4), scale: Vec2(1, 1))
        let emitter = ParticleEmitterComponent(
            parent: parent, maxParticles: 1, textureID: renderCore.textureManager.defaultParticleTextureId,
            emissionRate: 0, lifetimeRange: 100...100, speedRange: 0...0, angleRange: 0...0, scaleRange: 16...16)
        parent.add(emitter)
        emitter.spawn(count: 1)

        let image = try Self.render(shader, objects: [parent], renderCore: renderCore)

        XCTAssertGreaterThan(image.pixel(at: Vec2(8.5, 3.5)).x, 200, "the particle's centre")
        XCTAssertEqual(image.pixel(at: Vec2(16.5, 3.5)), Self.clear, "right of its quad")
        XCTAssertEqual(image.pixel(at: Vec2(-8.5, 3.5)), Self.clear, "the mirrored side")
    }

    /// A radius-8 circle collider outlined with thickness 0.25 (of the 16-unit
    /// quad) draws a ring from radius 4 to 8 and leaves the middle empty.
    func testWireframeCircleDrawsARing() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = WireframeShader(renderCore: renderCore, maxObjects: 4)
        let circle = Self.makeObject(position: Vec2(8, 4), scale: Vec2(1, 1))
        circle.add(CircleCollider(parent: circle, radius: 8))
        circle.add(WireframeComponent(parent: circle, color: Vec4(1, 1, 1, 1), thickness: 0.25))

        let image = try Self.render(shader, objects: [circle], renderCore: renderCore)

        XCTAssertEqual(image.pixel(at: Vec2(14.5, 3.5)), Self.white, "on the ring, 6.5 from the centre")
        XCTAssertEqual(image.pixel(at: Vec2(1.5, 4.5)), Self.white, "on the ring, left side")
        XCTAssertEqual(image.pixel(at: Vec2(8.5, 4.5)), Self.clear, "the empty middle")
        XCTAssertEqual(image.pixel(at: Vec2(17.5, 4.5)), Self.clear, "outside the circle")
    }

    // MARK: - Helpers

    private static func makeObject(position: Vec2, scale: Vec2, rotation: Float = 0) -> GameObj {
        let obj = GameObj()
        obj.position = position
        obj.scale = scale
        obj.rotation = rotation
        return obj
    }

    /// Checks the pixels half a pixel inside and outside each edge of a white rectangle.
    private static func assertRectangle(
        _ image: Image, xRange: ClosedRange<Float>, yRange: ClosedRange<Float>,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let midX = (xRange.lowerBound + xRange.upperBound) / 2 + 0.5
        let midY = (yRange.lowerBound + yRange.upperBound) / 2 - 0.5
        let inside = [Vec2(midX, midY),
                      Vec2(xRange.lowerBound + 0.5, yRange.lowerBound + 0.5),
                      Vec2(xRange.upperBound - 0.5, yRange.upperBound - 0.5),
                      Vec2(xRange.lowerBound + 0.5, yRange.upperBound - 0.5),
                      Vec2(xRange.upperBound - 0.5, yRange.lowerBound + 0.5)]
        let outside = [Vec2(xRange.lowerBound - 0.5, midY), Vec2(xRange.upperBound + 0.5, midY),
                       Vec2(midX, yRange.upperBound + 0.5), Vec2(midX, yRange.lowerBound - 0.5)]
        for point in inside {
            XCTAssertEqual(image.pixel(at: point), white, "inside at \(point)", file: file, line: line)
        }
        for point in outside {
            XCTAssertEqual(image.pixel(at: point), clear, "outside at \(point)", file: file, line: line)
        }
    }

    /// A 64×64 BGRA image, top row first.
    struct Image {
        let bytes: [UInt8]

        /// The pixel containing world point `p`, as (r, g, b, a).
        func pixel(at p: Vec2) -> SIMD4<UInt8> {
            let column = Int((p.x + 32).rounded(.down))
            let row = Int((32 - p.y).rounded(.down))
            let index = (row * 64 + column) * 4
            return SIMD4(bytes[index + 2], bytes[index + 1], bytes[index], bytes[index + 3])
        }
    }

    /// One frame of `shader` drawing `objects` into a readable 64×64 texture.
    private static func render(_ shader: some Shader, objects: [GameObj], renderCore: RenderCore) throws -> Image {
        renderCore.resize(scale: 1, layerSize: CGSize(width: 64, height: 64))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: renderCore.layer.pixelFormat, width: 64, height: 64, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let target = try XCTUnwrap(renderCore.device.makeTexture(descriptor: descriptor))
        OffscreenRenderPass.target = target
        defer { OffscreenRenderPass.target = nil }

        var projection = ProjectionUniform(transform: Mat4.makeOrthographic(
            left: -32, right: 32, bottom: -32, top: 32, nearZ: -100, farZ: 100))
        let projectionBuffer = try XCTUnwrap(renderCore.device.makeBuffer(
            bytes: &projection, length: ProjectionUniform.stride))

        XCTAssertTrue(shader.beginFrame())
        let pass = try XCTUnwrap(OffscreenRenderPass(renderCore: renderCore), "the test layer gave no drawable")
        let finished = DispatchSemaphore(value: 0)
        pass.addCompletedHandler { _ in finished.signal() }
        shader.bind(pass: pass, projectionBuffer: projectionBuffer)
        shader.submit(objects: objects)
        shader.flush(pass: pass)
        pass.end()
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success, "the GPU never finished the pass")
        shader.signalFrameComplete()

        var bytes = [UInt8](repeating: 0, count: 64 * 64 * 4)
        target.getBytes(&bytes, bytesPerRow: 64 * 4, from: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0)
        return withExtendedLifetime(objects) { Image(bytes: bytes) }
    }
}

/// A render pass that draws into ``target``, a texture a test can read, instead
/// of the layer's drawable (which is still taken and presented, untouched).
@MainActor
final class OffscreenRenderPass: RenderPass {
    static var target: MTLTexture?

    override class func createDescriptor(
        drawable: CAMetalDrawable, clearColor: MTLClearColor
    ) -> MTLRenderPassDescriptor? {
        guard let target else { return nil }
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = target
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = clearColor
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }
}
