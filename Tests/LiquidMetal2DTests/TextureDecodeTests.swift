import XCTest
@testable import LiquidMetal2D

/// A real PNG through the engine's own decode, upload and draw, read back
/// from the GPU on whichever platform runs the tests. Added 2026-10-05 when
/// the Mac demo drew every ship as the error texture (a demo loader bug in
/// the end, but nothing had pinned this path on the Mac).
@MainActor
final class TextureDecodeTests: XCTestCase {

    /// The demo's orange ship, decoded by the engine's own path and drawn at
    /// 48×64, comes out orange, channels in the PNG's order, on this platform.
    /// Two body texels are read back and compared with the file.
    func testPngTextureKeepsItsColorsOnThisPlatform() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let png = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Demo/LiquidMetal2D-Demo/playerShip1_orange.png")
        let cgImage = try XCTUnwrap(Texture.loadCGImage(path: png.path), "the demo's ship PNG")
        let texture = try XCTUnwrap(Texture.makeTexture(
            from: cgImage, isMipmapped: false, device: renderCore.device, commandQueue: renderCore.commandQueue))
        let textureID = renderCore.textureManager.addTexture(texture)
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 4)
        let ship = OffscreenRenderTests.makeObject(position: Vec2(0, 0), scale: Vec2(48, 64))
        ship.add(AlphaBlendComponent(parent: ship, textureID: textureID))

        let image = try OffscreenRenderTests.render(shader, objects: [ship], renderCore: renderCore)

        // Texel (column, row) of the 75×99 file → the world point the quad maps it to.
        func point(_ column: Float, _ row: Float) -> Vec2 {
            Vec2(-24 + (column + 0.5) / 75 * 48, 32 - (row + 0.5) / 99 * 64)
        }
        for (texel, expected) in [(point(20, 70), SIMD4<UInt8>(222, 83, 44, 255)),
                                  (point(37, 20), SIMD4<UInt8>(181, 69, 37, 255))] {
            let pixel = image.pixel(at: texel)
            for channel in 0..<4 {
                XCTAssertEqual(Int(pixel[channel]), Int(expected[channel]), accuracy: 40,
                               "channel \(channel) at \(texel): \(pixel), file says \(expected)")
            }
            XCTAssertTrue(pixel.x > pixel.y && pixel.y > pixel.z, "orange is r > g > b, got \(pixel)")
        }
    }

    /// The same ship loaded mipmapped (as the demo loads it) and drawn at a
    /// quarter of its size, so the sampler reads a generated mip level.
    func testMipmappedPngTextureKeepsItsColorsWhenSmall() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        let png = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Demo/LiquidMetal2D-Demo/playerShip1_orange.png")
        let cgImage = try XCTUnwrap(Texture.loadCGImage(path: png.path))
        let texture = try XCTUnwrap(Texture.makeTexture(
            from: cgImage, isMipmapped: true, device: renderCore.device, commandQueue: renderCore.commandQueue))
        let textureID = renderCore.textureManager.addTexture(texture)
        let shader = AlphaBlendShader(renderCore: renderCore, maxObjects: 4)
        let ship = OffscreenRenderTests.makeObject(position: Vec2(0, 0), scale: Vec2(18, 24))
        ship.add(AlphaBlendComponent(parent: ship, textureID: textureID))

        let image = try OffscreenRenderTests.render(shader, objects: [ship], renderCore: renderCore)

        let body = image.pixel(at: Vec2(-9 + (20.5 / 75) * 18, 12 - (70.5 / 99) * 24))
        XCTAssertGreaterThan(body.w, 200, "opaque body, got \(body)")
        XCTAssertTrue(body.x > 120 && body.x > body.y + 40 && body.y > body.z, "orange, got \(body)")
    }
}
