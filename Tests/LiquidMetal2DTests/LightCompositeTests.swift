import Metal
import XCTest
@testable import LiquidMetal2D

/// The composite, through a real `DefaultRenderer` drawing into a readable
/// 64×64 target: one world unit per pixel, y up, like `OffscreenRenderTests`.
@MainActor
final class LightCompositeTests: XCTestCase {

    private static let ortho = Mat4.makeOrthographic(left: -32, right: 32, bottom: -32, top: 32, nearZ: -100, farZ: 100)

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

    /// A light above the middle lights the top of the scene, not the bottom:
    /// the composite samples the light map the right way up.
    func testCompositeKeepsTheLightMapTheRightWayUp() throws {
        let (renderer, lightMap) = try makeRenderer()
        var light = Light(position: Vec2(0, 12), radius: 8, color: Vec3(1, 1, 1))
        light.falloff = 1
        XCTAssertTrue(lightMap.begin())
        lightMap.add(light)
        lightMap.commit(viewProjection: Self.ortho)
        XCTAssertTrue(renderer.beginPass())
        renderer.useOrthographic()
        renderer.submit(objects: [Self.whiteSprite(renderer, at: Vec2(0, 0), size: Vec2(64, 64))])

        renderer.composite(lightMap)
        renderer.endPass()

        let image = try Self.readScene()
        XCTAssertGreaterThan(image.pixel(at: Vec2(0.5, 12.5)).x, 200, "under the light")
        XCTAssertEqual(image.pixel(at: Vec2(0.5, -11.5)).x, 0, "its mirror image")
    }

    /// The manual draw path keeps working across a composite: the active
    /// shader stays bound, so draws after it are flushed with the pass.
    func testManualDrawsAfterTheCompositeShow() throws {
        let (renderer, lightMap) = try makeRenderer()
        XCTAssertTrue(lightMap.begin())
        lightMap.commit(viewProjection: Self.ortho)
        XCTAssertTrue(renderer.beginPass())
        renderer.useOrthographic()
        renderer.useShader(renderer.alphaBlend)
        renderer.alphaBlend.draw(
            Transform2D(position: Vec2(-16, 0), scale: Vec2(32, 64)), textureId: renderer.defaultTextureId)
        renderer.composite(lightMap)

        renderer.alphaBlend.draw(
            Transform2D(position: Vec2(16, 0), scale: Vec2(32, 64)), textureId: renderer.defaultTextureId)
        renderer.endPass()

        let image = try Self.readScene()
        XCTAssertEqual(image.pixel(at: Vec2(-16.5, 0.5)).x, 0, "drawn before, under a black light map")
        XCTAssertEqual(image.pixel(at: Vec2(16.5, 0.5)).x, 255, "drawn after the composite")
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
