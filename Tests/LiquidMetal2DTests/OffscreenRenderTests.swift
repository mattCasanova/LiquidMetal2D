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
    /// 50 % white, premultiplied.
    private static let halfWhite = SIMD4<UInt8>(128, 128, 128, 128)

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

    // MARK: - Premultiplied alpha

    /// Loaded textures are premultiplied and the shaders premultiply their
    /// tint, so every pipeline blends with a source factor of one. A
    /// half-transparent white texel over a white ground must stay white. With
    /// a sourceAlpha factor it is weighted by alpha twice and comes out grey:
    /// the dark fringe round every soft edge.
    func testAlphaBlendHalfTransparentTexelOverWhiteStaysWhite() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        renderCore.setClearColor(color: Vec3(1, 1, 1))
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 4)
        let sprite = Self.makeObject(position: Vec2(8, 4), scale: Vec2(16, 8))
        sprite.add(AlphaBlendComponent(parent: sprite, textureID: try Self.addHalfWhiteTexture(to: renderCore)))

        let image = try Self.render(shader, objects: [sprite], renderCore: renderCore)

        Self.assertPixel(image.pixel(at: Vec2(8.5, 3.5)), isNear: Self.white)
    }

    /// The same texel over black is half bright, not a quarter.
    func testAlphaBlendHalfTransparentTexelOverBlackIsHalfBright() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 4)
        let sprite = Self.makeObject(position: Vec2(8, 4), scale: Vec2(16, 8))
        sprite.add(AlphaBlendComponent(parent: sprite, textureID: try Self.addHalfWhiteTexture(to: renderCore)))

        let image = try Self.render(shader, objects: [sprite], renderCore: renderCore)

        Self.assertPixel(image.pixel(at: Vec2(8.5, 3.5)), isNear: Self.halfWhite)
    }

    /// A tint with alpha 0.5 on the opaque white texture is half bright over
    /// black: the fragment shader premultiplies the tint. Without that, a
    /// source factor of one would draw it at full brightness.
    func testAlphaBlendHalfAlphaTintIsHalfBright() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 4)
        let sprite = Self.makeObject(position: Vec2(8, 4), scale: Vec2(16, 8))
        sprite.add(AlphaBlendComponent(
            parent: sprite, textureID: renderCore.textureManager.defaultTextureId, tintColor: Vec4(1, 1, 1, 0.5)))

        let image = try Self.render(shader, objects: [sprite], renderCore: renderCore)

        Self.assertPixel(image.pixel(at: Vec2(8.5, 3.5)), isNear: Self.halfWhite)
    }

    func testRippleHalfTransparentTexelOverWhiteStaysWhite() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        renderCore.setClearColor(color: Vec3(1, 1, 1))
        let shader = RippleShader(renderCore: renderCore, maxObjects: 4)
        let sprite = Self.makeObject(position: Vec2(8, 4), scale: Vec2(16, 8))
        sprite.add(RippleComponent(
            parent: sprite, textureID: try Self.addHalfWhiteTexture(to: renderCore), amplitude: 0))

        let image = try Self.render(shader, objects: [sprite], renderCore: renderCore)

        Self.assertPixel(image.pixel(at: Vec2(8.5, 3.5)), isNear: Self.white)
    }

    /// The ring of ``testWireframeCircleDrawsARing`` in a colour with alpha 0.5.
    func testWireframeHalfAlphaColorIsHalfBright() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = WireframeShader(renderCore: renderCore, maxObjects: 4)
        let circle = Self.makeObject(position: Vec2(8, 4), scale: Vec2(1, 1))
        circle.add(CircleCollider(parent: circle, radius: 8))
        circle.add(WireframeComponent(parent: circle, color: Vec4(1, 1, 1, 0.5), thickness: 0.25))

        let image = try Self.render(shader, objects: [circle], renderCore: renderCore)

        Self.assertPixel(image.pixel(at: Vec2(14.5, 3.5)), isNear: Self.halfWhite, "on the ring")
    }

    /// One 16-wide particle on the plain white texture, colour alpha 0.5,
    /// "over" blend: half bright over black.
    func testParticleAlphaModeHalfAlphaColorIsHalfBright() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = ParticleShader(renderCore: renderCore, maxObjects: 4, blendMode: .alpha)
        let parent = Self.makeObject(position: Vec2(8, 4), scale: Vec2(1, 1))
        let emitter = ParticleEmitterComponent(
            parent: parent, maxParticles: 1, textureID: renderCore.textureManager.defaultTextureId,
            emissionRate: 0, lifetimeRange: 100...100, speedRange: 0...0, angleRange: 0...0, scaleRange: 16...16,
            startColor: Vec4(1, 1, 1, 0.5), endColor: Vec4(1, 1, 1, 0.5))
        parent.add(emitter)
        emitter.spawn(count: 1)

        let image = try Self.render(shader, objects: [parent], renderCore: renderCore)

        Self.assertPixel(image.pixel(at: Vec2(8.5, 3.5)), isNear: Self.halfWhite)
    }

    /// Additive: a half-transparent texel adds half, not a quarter.
    func testParticleAdditiveHalfTransparentTexelAddsHalf() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = ParticleShader(renderCore: renderCore, maxObjects: 4)
        let parent = Self.makeObject(position: Vec2(8, 4), scale: Vec2(1, 1))
        let emitter = ParticleEmitterComponent(
            parent: parent, maxParticles: 1, textureID: try Self.addHalfWhiteTexture(to: renderCore),
            emissionRate: 0, lifetimeRange: 100...100, speedRange: 0...0, angleRange: 0...0, scaleRange: 16...16)
        parent.add(emitter)
        emitter.spawn(count: 1)

        let image = try Self.render(shader, objects: [parent], renderCore: renderCore)

        Self.assertPixel(image.pixel(at: Vec2(8.5, 3.5)), isNear: Self.halfWhite)
    }

    // MARK: - Two draws in one frame

    func testAlphaBlendDrawsEverySubmitAcrossAFlush() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 4)
        try Self.assertDrawsAcrossAFlush(shader, renderCore: renderCore) { position in
            let sprite = Self.makeObject(position: position, scale: Vec2(8, 8))
            sprite.add(AlphaBlendComponent(parent: sprite, textureID: renderCore.textureManager.defaultTextureId))
            return sprite
        }
    }

    func testRippleDrawsEverySubmitAcrossAFlush() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = RippleShader(renderCore: renderCore, maxObjects: 4)
        try Self.assertDrawsAcrossAFlush(shader, renderCore: renderCore) { position in
            let sprite = Self.makeObject(position: position, scale: Vec2(8, 8))
            sprite.add(RippleComponent(
                parent: sprite, textureID: renderCore.textureManager.defaultTextureId, amplitude: 0))
            return sprite
        }
    }

    func testParticlesDrawEverySubmitAcrossAFlush() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = ParticleShader(renderCore: renderCore, maxObjects: 4)
        try Self.assertDrawsAcrossAFlush(shader, renderCore: renderCore) { position in
            let parent = Self.makeObject(position: position, scale: Vec2(1, 1))
            let emitter = ParticleEmitterComponent(
                parent: parent, maxParticles: 1, textureID: renderCore.textureManager.defaultParticleTextureId,
                emissionRate: 0, lifetimeRange: 100...100, speedRange: 0...0, angleRange: 0...0,
                scaleRange: 16...16)
            parent.add(emitter)
            emitter.spawn(count: 1)
            return parent
        }
    }

    /// Probes a point on each radius-6 ring (radius 3 to 6), 4.5 right of its centre.
    func testWireframeDrawsEverySubmitAcrossAFlush() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let shader = WireframeShader(renderCore: renderCore, maxObjects: 4)
        try Self.assertDrawsAcrossAFlush(shader, renderCore: renderCore, probe: Vec2(4.5, 0.5)) { position in
            let circle = Self.makeObject(position: position, scale: Vec2(1, 1))
            circle.add(CircleCollider(parent: circle, radius: 6))
            circle.add(WireframeComponent(parent: circle, color: Vec4(1, 1, 1, 1), thickness: 0.25))
            return circle
        }
    }

    // MARK: - Helpers

    private static let flushPoints = [Vec2(-16, 16), Vec2(16, 16), Vec2(0, -16)]

    /// A pass that switches shaders flushes in between, so one shader can draw
    /// twice in a frame. Draws A, flushes, then draws B and C, which start at
    /// slot 1 (a non-zero buffer offset); all three must show. The first draw
    /// reads its slot when the GPU runs, after the second submit, so a count
    /// reset or a lost offset shows up as a missing A or C. Every object sits
    /// at z 10: under this projection a reversed matrix multiply pushes that
    /// out of the clip range, where z 0 would hide it.
    private static func assertDrawsAcrossAFlush(
        _ shader: some Shader, renderCore: RenderCore, probe: Vec2 = Vec2(0.5, 0.5),
        file: StaticString = #filePath, line: UInt = #line, make: (Vec2) -> GameObj
    ) throws {
        let objects = flushPoints.map { point in
            let obj = make(point)
            obj.zOrder = 10
            return obj
        }

        let image = try render(shader, submits: [[objects[0]], [objects[1], objects[2]]], renderCore: renderCore)

        for (point, name) in zip(flushPoints, ["A, the first draw", "B, slot 1", "C, slot 2"]) {
            XCTAssertGreaterThan(image.pixel(at: point + probe).x, 200, "\(name) at \(point)", file: file, line: line)
        }
    }

    /// A 1×1 texture holding 50 % white, premultiplied: (128, 128, 128, 128).
    private static func addHalfWhiteTexture(to renderCore: RenderCore) throws -> Int {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false)
        let texture = try XCTUnwrap(renderCore.device.makeTexture(descriptor: descriptor))
        var pixel: [UInt8] = [128, 128, 128, 128]
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &pixel, bytesPerRow: 4)
        return renderCore.textureManager.addTexture(texture)
    }

    /// Equal channel by channel, within one step of 8-bit rounding.
    private static func assertPixel(
        _ pixel: SIMD4<UInt8>, isNear expected: SIMD4<UInt8>, _ message: String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for channel in 0..<4 {
            XCTAssertEqual(
                Int(pixel[channel]), Int(expected[channel]), accuracy: 1,
                "\(message) channel \(channel) of \(pixel), expected \(expected)", file: file, line: line)
        }
    }

    static func makeObject(position: Vec2, scale: Vec2, rotation: Float = 0) -> GameObj {
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
    static func render(_ shader: some Shader, objects: [GameObj], renderCore: RenderCore) throws -> Image {
        try render(shader, submits: [objects], renderCore: renderCore)
    }

    /// One frame of `shader` drawing each list of `submits` in turn, rebinding
    /// and flushing between them as a shader switch does.
    private static func render(
        _ shader: some Shader, submits: [[GameObj]], renderCore: RenderCore
    ) throws -> Image {
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
        for objects in submits {
            shader.bind(pass: pass, projectionBuffer: projectionBuffer)
            shader.submit(objects: objects)
            shader.flush(pass: pass)
        }
        pass.end()
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success, "the GPU never finished the pass")
        shader.signalFrameComplete()

        var bytes = [UInt8](repeating: 0, count: 64 * 64 * 4)
        target.getBytes(&bytes, bytesPerRow: 64 * 4, from: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0)
        return withExtendedLifetime(submits) { Image(bytes: bytes) }
    }
}

/// A render pass that draws into ``target``, a texture a test can read, instead
/// of the layer's drawable (which is still taken and presented, untouched).
@MainActor
final class OffscreenRenderPass: RenderPass {
    static var target: MTLTexture?
    /// Signalled when the most recent pass made through a renderer finishes on the GPU.
    static var lastPass: DispatchSemaphore?

    override static func createDescriptor(
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
