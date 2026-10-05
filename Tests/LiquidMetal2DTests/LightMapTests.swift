import Metal
import XCTest
@testable import LiquidMetal2D

/// The light map on the GPU: a 64×64 light texture read back through a
/// blit, one world unit per pixel, y up, like `OffscreenRenderTests`.
@MainActor
final class LightMapTests: XCTestCase {

    private static let ortho = Mat4.makeOrthographic(left: -32, right: 32, bottom: -32, top: 32, nearZ: -100, farZ: 100)

    func testNoLightsIsTheAmbientEverywhere() throws {
        let (renderCore, lightMap) = try makeLightMap()
        lightMap.ambient = Vec3(0.1, 0.2, 0.3)
        XCTAssertTrue(lightMap.begin())
        lightMap.commit(viewProjection: Self.ortho)

        let image = try Self.readback(lightMap, renderCore: renderCore)

        for pixel in image.pixels {
            Self.assertNear(pixel, Vec3(0.1, 0.2, 0.3), 0.002)
        }
    }

    func testAPoolFallsOffLinearlyToItsRadius() throws {
        let (renderCore, lightMap) = try makeLightMap()
        lightMap.ambient = Vec3(0.1, 0.1, 0.1)
        var light = Light(position: Vec2(0, 0), radius: 16, color: Vec3(1, 1, 1))
        light.falloff = 1
        XCTAssertTrue(lightMap.begin())
        lightMap.add(light)
        lightMap.commit(viewProjection: Self.ortho)

        let image = try Self.readback(lightMap, renderCore: renderCore)

        Self.assertNear(image.pixel(at: Vec2(0.5, 0.5)), Vec3(repeating: 1 - 0.707 / 16 + 0.1), 0.03, "centre")
        Self.assertNear(image.pixel(at: Vec2(8.5, 0.5)), Vec3(repeating: 0.5 + 0.1), 0.05, "half way")
        Self.assertNear(image.pixel(at: Vec2(17.5, 0.5)), Vec3(repeating: 0.1), 0.002, "past the radius")
    }

    func testBrightnessFallsMonotonicallyInEveryDirection() throws {
        let (renderCore, lightMap) = try makeLightMap()
        XCTAssertTrue(lightMap.begin())
        lightMap.add(Light(position: Vec2(0, 0), radius: 16, color: Vec3(1, 1, 1)))
        lightMap.commit(viewProjection: Self.ortho)

        let image = try Self.readback(lightMap, renderCore: renderCore)

        for direction in [Vec2(1, 0), Vec2(0, 1), Vec2(0.7071, 0.7071)] {
            var previous: Float = 2
            for step in 0..<16 {
                let value = image.pixel(at: direction * (Float(step) + 0.5) + Vec2(0.5, 0.5) * (1 - direction)).x
                XCTAssertLessThanOrEqual(value, previous + 1e-3, "step \(step) along \(direction)")
                previous = value
            }
        }
    }

    func testOverlappingLightsAddPerChannel() throws {
        let (renderCore, lightMap) = try makeLightMap()
        var red = Light(position: Vec2(-4, 0), radius: 16, color: Vec3(1, 0, 0))
        var blue = Light(position: Vec2(4, 0), radius: 16, color: Vec3(0, 0, 1))
        red.falloff = 1
        blue.falloff = 1
        XCTAssertTrue(lightMap.begin())
        lightMap.add(red)
        lightMap.add(blue)
        lightMap.commit(viewProjection: Self.ortho)

        let pixel = try Self.readback(lightMap, renderCore: renderCore).pixel(at: Vec2(0.5, 0.5))

        XCTAssertGreaterThan(pixel.x, 0.6, "red reaches the middle: \(pixel)")
        XCTAssertGreaterThan(pixel.z, 0.6, "blue reaches the middle: \(pixel)")
        XCTAssertEqual(pixel.y, 0, accuracy: 1e-3, "nothing green: \(pixel)")
    }

    func testAConeLightsItsArcAndFadesAtTheEdge() throws {
        let (renderCore, lightMap) = try makeLightMap()
        var cone = Light(position: Vec2(0, 0), radius: 16, color: Vec3(1, 1, 1))
        cone.falloff = 1
        cone.direction = 0
        cone.halfAngle = .pi / 4
        XCTAssertTrue(lightMap.begin())
        lightMap.add(cone)
        lightMap.commit(viewProjection: Self.ortho)

        let image = try Self.readback(lightMap, renderCore: renderCore)

        XCTAssertGreaterThan(image.pixel(at: Vec2(8.5, 0.5)).x, 0.4, "down the middle")
        XCTAssertEqual(image.pixel(at: Vec2(-8.5, 0.5)).x, 0, accuracy: 1e-3, "behind")
        XCTAssertEqual(image.pixel(at: Vec2(0.5, 8.5)).x, 0, accuracy: 1e-3, "off to the side")
        // Pixel centre (6.5, 5.5) is 0.70 rad off the axis: inside the 0.12 rad
        // fade below the π/4 edge. Dimmer than the middle at the same distance, not off.
        let inTheFade = image.pixel(at: Vec2(6.5, 5.5)).x
        let middle = image.pixel(at: Vec2(8.5, 0.5)).x
        XCTAssertGreaterThan(inTheFade, 0.02, "fading, not off")
        XCTAssertLessThan(inTheFade, middle - 0.02, "fading, not full")
    }

    func testAVisibilityOutlineCastsAShadow() throws {
        let (renderCore, lightMap) = try makeLightMap()
        var lamp = Light(position: Vec2(0, 0), radius: 16, color: Vec3(1, 1, 1))
        lamp.falloff = 1
        var visibility = VisibilityPolygon()
        visibility.compute(from: lamp.position, radius: lamp.radius,
                           walls: [LineSegment(start: Vec2(5, -8), end: Vec2(5, 8))])
        XCTAssertTrue(lightMap.begin())
        lightMap.add(lamp, outline: visibility.points)
        lightMap.commit(viewProjection: Self.ortho)

        let image = try Self.readback(lightMap, renderCore: renderCore)

        XCTAssertGreaterThan(image.pixel(at: Vec2(3.5, 0.5)).x, 0.6, "in front of the wall")
        XCTAssertEqual(image.pixel(at: Vec2(8.5, 0.5)).x, 0, accuracy: 1e-3, "in its shadow")
        XCTAssertGreaterThan(image.pixel(at: Vec2(6.5, 12.5)).x, 0.05, "round the wall's end")
    }

    func testIntensityScalesTheLight() throws {
        let (renderCore, lightMap) = try makeLightMap()
        var light = Light(position: Vec2(0, 0), radius: 16, color: Vec3(1, 1, 1))
        XCTAssertTrue(lightMap.begin())
        lightMap.add(light)
        lightMap.commit(viewProjection: Self.ortho)
        let full = try Self.readback(lightMap, renderCore: renderCore).pixel(at: Vec2(4.5, 0.5)).x

        light.intensity = 0.5
        XCTAssertTrue(lightMap.begin())
        lightMap.add(light)
        lightMap.commit(viewProjection: Self.ortho)
        let half = try Self.readback(lightMap, renderCore: renderCore).pixel(at: Vec2(4.5, 0.5)).x

        XCTAssertEqual(half, full / 2, accuracy: 0.02)
    }

    func testTheTextureFollowsTheDrawableAtTheResolutionScale() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        renderCore.resize(scale: 1, layerSize: CGSize(width: 64, height: 64))
        let lightMap = LightMap(renderCore: renderCore, maxLights: 4, maxVertices: 600)
        XCTAssertEqual(lightMap.texture.width, 32, "default scale is a half")

        renderCore.resize(scale: 1, layerSize: CGSize(width: 32, height: 32))
        XCTAssertTrue(lightMap.begin())

        XCTAssertEqual(lightMap.texture.width, 16)
        XCTAssertEqual(lightMap.texture.height, 16)
        lightMap.commit(viewProjection: Self.ortho)
    }

    func testAConeWithoutAnOutlineIsOpenAtTheBack() throws {
        let (renderCore, lightMap) = try makeLightMap()
        var cone = Light(position: Vec2(0, 0), radius: 16, color: Vec3(1, 1, 1))
        cone.halfAngle = 0.6
        XCTAssertTrue(lightMap.begin())
        lightMap.add(cone)
        lightMap.commit(viewProjection: Self.ortho)

        let image = try Self.readback(lightMap, renderCore: renderCore)

        XCTAssertEqual(image.pixel(at: Vec2(-0.5, 0.5)).x, 0, accuracy: 1e-3, "just behind the light")
        XCTAssertGreaterThan(image.pixel(at: Vec2(2.5, 0.5)).x, 0.5, "just in front")
    }

    /// A cone's visibility outline is open: the engine must not close it
    /// across the mouth, which would draw that part of the cone twice.
    func testAConeOutlineIsNotClosedAcrossItsMouth() throws {
        let (renderCore, lightMap) = try makeLightMap()
        var cone = Light(position: Vec2(0, 0), radius: 16, color: Vec3(1, 1, 1))
        cone.halfAngle = 0.6
        var visibility = VisibilityPolygon()
        visibility.compute(from: cone.position, radius: cone.radius, walls: [],
                           direction: cone.direction, halfAngle: cone.halfAngle)
        XCTAssertTrue(lightMap.begin())
        lightMap.add(cone)
        lightMap.commit(viewProjection: Self.ortho)
        let plain = try Self.readback(lightMap, renderCore: renderCore).pixel(at: Vec2(6.5, 0.5)).x

        XCTAssertTrue(lightMap.begin())
        lightMap.add(cone, outline: visibility.points)
        lightMap.commit(viewProjection: Self.ortho)
        let outlined = try Self.readback(lightMap, renderCore: renderCore).pixel(at: Vec2(6.5, 0.5)).x

        XCTAssertEqual(outlined, plain, accuracy: 0.02, "the same light, drawn once either way")
        XCTAssertGreaterThan(plain, 0.3)
    }

    // MARK: - Composite, through DefaultRenderer

    func testCompositeMultipliesTheSceneByTheLightMap() throws {
        let (renderer, lightMap) = try makeRenderer()
        lightMap.ambient = Vec3(0.5, 0.5, 0.5)
        XCTAssertTrue(lightMap.begin())
        lightMap.commit(viewProjection: Self.ortho)
        XCTAssertTrue(renderer.beginPass())
        renderer.useOrthographic()
        renderer.submit(objects: [Self.whiteSprite(renderer, at: Vec2(0, 0), size: Vec2(64, 64))])

        renderer.composite(lightMap)
        renderer.endPass()

        let image = try Self.readScene()
        Self.assertByte(image.pixel(at: Vec2(0.5, 0.5)), 128, "the middle")
        Self.assertByte(image.pixel(at: Vec2(-31.5, 31.5)), 128, "a corner")
    }

    func testCompositeLightsTheMiddleAndLeavesTheCornersDark() throws {
        let (renderer, lightMap) = try makeRenderer()
        XCTAssertTrue(lightMap.begin())
        lightMap.add(Light(position: Vec2(0, 0), radius: 20, color: Vec3(1, 1, 1)))
        lightMap.commit(viewProjection: Self.ortho)
        XCTAssertTrue(renderer.beginPass())
        renderer.useOrthographic()
        renderer.submit(objects: [Self.whiteSprite(renderer, at: Vec2(0, 0), size: Vec2(64, 64))])

        renderer.composite(lightMap)
        renderer.endPass()

        let image = try Self.readScene()
        XCTAssertGreaterThan(image.pixel(at: Vec2(0.5, 0.5)).x, 200, "lit in the middle")
        XCTAssertEqual(image.pixel(at: Vec2(-31.5, 31.5)).x, 0, "dark in the corner")
    }

    func testWhatIsSubmittedAfterTheCompositeStaysBright() throws {
        let (renderer, lightMap) = try makeRenderer()
        XCTAssertTrue(lightMap.begin())
        lightMap.commit(viewProjection: Self.ortho)
        XCTAssertTrue(renderer.beginPass())
        renderer.useOrthographic()
        renderer.submit(objects: [Self.whiteSprite(renderer, at: Vec2(-16, 0), size: Vec2(32, 64))])
        renderer.composite(lightMap)

        renderer.submit(objects: [Self.whiteSprite(renderer, at: Vec2(16, 0), size: Vec2(32, 64))])
        renderer.endPass()

        let image = try Self.readScene()
        XCTAssertEqual(image.pixel(at: Vec2(-16.5, 0.5)).x, 0, "the scene, under a black light map")
        XCTAssertEqual(image.pixel(at: Vec2(16.5, 0.5)).x, 255, "emissive: drawn after the composite")
    }

    // MARK: - Helpers

    /// A 64×64 render core and a full-resolution light map on it.
    private func makeLightMap() throws -> (RenderCore, LightMap) {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        renderCore.resize(scale: 1, layerSize: CGSize(width: 64, height: 64))
        return (renderCore, LightMap(renderCore: renderCore, maxLights: 8, maxVertices: 1200, resolutionScale: 1))
    }

    /// A `DefaultRenderer` drawing into a readable 64×64 target, with an
    /// orthographic projection of one world unit per pixel, and a
    /// full-resolution light map on it.
    private func makeRenderer() throws -> (DefaultRenderer, LightMap) {
        _ = try ShaderTestSupport.makeDevice()
        let renderer = OffscreenRenderer(parentView: PlatformView(), maxObjects: 4)
        renderer.renderCore.resize(scale: 1, layerSize: CGSize(width: 64, height: 64))
        renderer.setOrthographic(left: -32, right: 32, bottom: -32, top: 32, nearZ: -100, farZ: 100)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: renderer.renderCore.layer.pixelFormat, width: 64, height: 64, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let target = try XCTUnwrap(renderer.renderCore.device.makeTexture(descriptor: descriptor))
        OffscreenRenderPass.target = target
        let lightMap = renderer.makeLightMap(maxLights: 8, maxVertices: 1200, resolutionScale: 1)
        return (renderer, lightMap)
    }

    private static func whiteSprite(_ renderer: DefaultRenderer, at position: Vec2, size: Vec2) -> GameObj {
        let sprite = GameObj()
        sprite.position = position
        sprite.scale = size
        sprite.add(AlphaBlendComponent(parent: sprite, textureID: renderer.defaultTextureId))
        return sprite
    }

    /// Waits for the GPU, then reads the scene target back as bytes.
    private static func readScene() throws -> OffscreenRenderTests.Image {
        defer { OffscreenRenderPass.target = nil }
        let target = try XCTUnwrap(OffscreenRenderPass.target, "no target was set")
        let finished = try XCTUnwrap(OffscreenRenderPass.lastPass, "no pass was begun")
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success, "the GPU never finished the pass")
        var bytes = [UInt8](repeating: 0, count: 64 * 64 * 4)
        target.getBytes(&bytes, bytesPerRow: 64 * 4, from: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0)
        return OffscreenRenderTests.Image(bytes: bytes)
    }

    private static func assertByte(
        _ pixel: SIMD4<UInt8>, _ expected: Int, _ message: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        for channel in 0..<3 {
            XCTAssertEqual(Int(pixel[channel]), expected, accuracy: 1, "\(message): \(pixel)", file: file, line: line)
        }
    }

    /// Copies the light texture into a shared buffer and unpacks its halves.
    static func readback(_ lightMap: LightMap, renderCore: RenderCore) throws -> LightImage {
        let texture = lightMap.texture
        let bytesPerRow = texture.width * 8
        let buffer = try XCTUnwrap(renderCore.device.makeBuffer(
            length: bytesPerRow * texture.height, options: .storageModeShared))
        let commandBuffer = try XCTUnwrap(renderCore.commandQueue.makeCommandBuffer())
        let blit = try XCTUnwrap(commandBuffer.makeBlitCommandEncoder())
        blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                  to: buffer, destinationOffset: 0, destinationBytesPerRow: bytesPerRow,
                  destinationBytesPerImage: bytesPerRow * texture.height)
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let count = texture.width * texture.height * 4
        let halves = buffer.contents().bindMemory(to: Float16.self, capacity: count)
        let values = (0..<count).map { Float(halves[$0]) }
        return LightImage(width: texture.width, height: texture.height, values: values)
    }

    static func assertNear(
        _ pixel: Vec3, _ expected: Vec3, _ accuracy: Float, _ message: String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for channel in 0..<3 {
            XCTAssertEqual(pixel[channel], expected[channel], accuracy: accuracy,
                           "\(message) channel \(channel) of \(pixel)", file: file, line: line)
        }
    }
}

/// A light texture read back as floats, top row first.
struct LightImage {
    let width: Int
    let height: Int
    let values: [Float]

    var pixels: [Vec3] { (0..<(width * height)).map { Vec3(values[$0 * 4], values[$0 * 4 + 1], values[$0 * 4 + 2]) } }

    /// The pixel containing world point `p`, with one unit per pixel and the origin in the middle.
    func pixel(at p: Vec2) -> Vec3 {
        let column = Int((p.x + Float(width) / 2).rounded(.down))
        let row = Int((Float(height) / 2 - p.y).rounded(.down))
        let index = (row * width + column) * 4
        return Vec3(values[index], values[index + 1], values[index + 2])
    }
}

/// A renderer whose passes draw into `OffscreenRenderPass.target`.
@MainActor
private final class OffscreenRenderer: DefaultRenderer {
    override func makeRenderPass() -> RenderPass? {
        guard let pass = OffscreenRenderPass(renderCore: renderCore) else { return nil }
        let finished = DispatchSemaphore(value: 0)
        pass.addCompletedHandler { _ in finished.signal() }
        OffscreenRenderPass.lastPass = finished
        return pass
    }
}
