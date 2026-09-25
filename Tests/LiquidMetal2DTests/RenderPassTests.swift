import Metal
import QuartzCore
import XCTest
@testable import LiquidMetal2D

@MainActor
final class RenderPassTests: XCTestCase {

    /// `createDescriptor` is `open` so a subclass can change the attachments;
    /// the pass must build its encoder from the subclass's version.
    func testSubclassBuildsTheDescriptor() throws {
        let renderCore = try ShaderTestSupport.makeRenderCore()
        renderCore.resize(scale: 1, layerSize: CGSize(width: 64, height: 64))
        CountingRenderPass.calls = 0

        let pass = try XCTUnwrap(CountingRenderPass(renderCore: renderCore), "the test layer gave no drawable")
        pass.end()

        XCTAssertEqual(CountingRenderPass.calls, 1)
    }
}

@MainActor
private final class CountingRenderPass: RenderPass {
    static var calls = 0

    override class func createDescriptor(
        drawable: CAMetalDrawable, clearColor: MTLClearColor
    ) -> MTLRenderPassDescriptor? {
        calls += 1
        return super.createDescriptor(drawable: drawable, clearColor: clearColor)
    }
}
