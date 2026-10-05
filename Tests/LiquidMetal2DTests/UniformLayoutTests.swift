import XCTest
@testable import LiquidMetal2D

/// Pins each uniform's stride and field offsets to the matching MSL struct.
/// The shaders compile at runtime, so nothing else checks that the Swift and
/// Metal sides agree; a mismatch here draws garbage from instance 1 onward.
final class UniformLayoutTests: XCTestCase {

    func testTransform2D() {
        XCTAssertEqual(MemoryLayout<Transform2D>.stride, 24)
        XCTAssertEqual(MemoryLayout<Transform2D>.offset(of: \.position), 0)
        XCTAssertEqual(MemoryLayout<Transform2D>.offset(of: \.scale), 8)
        XCTAssertEqual(MemoryLayout<Transform2D>.offset(of: \.rotation), 16)
        XCTAssertEqual(MemoryLayout<Transform2D>.offset(of: \.zOrder), 20)
    }

    func testProjectionUniform() {
        XCTAssertEqual(ProjectionUniform.stride, 64)
        XCTAssertEqual(MemoryLayout<ProjectionUniform>.offset(of: \.transform), 0)
    }

    func testAlphaBlendUniform() {
        XCTAssertEqual(AlphaBlendUniform.stride, 64)
        XCTAssertEqual(MemoryLayout<AlphaBlendUniform>.offset(of: \.texTrans), 0)
        XCTAssertEqual(MemoryLayout<AlphaBlendUniform>.offset(of: \.color), 16)
        XCTAssertEqual(MemoryLayout<AlphaBlendUniform>.offset(of: \.transform), 32)
    }

    func testParticleUniform() {
        XCTAssertEqual(ParticleUniform.stride, 48)
        XCTAssertEqual(MemoryLayout<ParticleUniform>.offset(of: \.color), 0)
        XCTAssertEqual(MemoryLayout<ParticleUniform>.offset(of: \.transform), 16)
    }

    func testLightUniform() {
        XCTAssertEqual(LightUniform.stride, 48)
        XCTAssertEqual(MemoryLayout<LightUniform>.offset(of: \.color), 0)
        XCTAssertEqual(MemoryLayout<LightUniform>.offset(of: \.center), 16)
        XCTAssertEqual(MemoryLayout<LightUniform>.offset(of: \.radius), 24)
        XCTAssertEqual(MemoryLayout<LightUniform>.offset(of: \.falloff), 28)
        XCTAssertEqual(MemoryLayout<LightUniform>.offset(of: \.direction), 32)
        XCTAssertEqual(MemoryLayout<LightUniform>.offset(of: \.cosHalfAngle), 40)
        XCTAssertEqual(MemoryLayout<LightUniform>.offset(of: \.cosInner), 44)
    }

    func testLightVertex() {
        XCTAssertEqual(LightVertex.stride, 16)
        XCTAssertEqual(MemoryLayout<LightVertex>.offset(of: \.position), 0)
        XCTAssertEqual(MemoryLayout<LightVertex>.offset(of: \.z), 8)
        XCTAssertEqual(MemoryLayout<LightVertex>.offset(of: \.light), 12)
    }

    func testWireframeUniform() {
        XCTAssertEqual(WireframeUniform.stride, 64)
        XCTAssertEqual(MemoryLayout<WireframeUniform>.offset(of: \.color), 0)
        XCTAssertEqual(MemoryLayout<WireframeUniform>.offset(of: \.params), 16)
        XCTAssertEqual(MemoryLayout<WireframeUniform>.offset(of: \.transform), 32)
    }

    func testRippleUniform() {
        XCTAssertEqual(RippleUniform.stride, 80)
        XCTAssertEqual(MemoryLayout<RippleUniform>.offset(of: \.texTrans), 0)
        XCTAssertEqual(MemoryLayout<RippleUniform>.offset(of: \.color), 16)
        XCTAssertEqual(MemoryLayout<RippleUniform>.offset(of: \.params), 32)
        XCTAssertEqual(MemoryLayout<RippleUniform>.offset(of: \.transform), 48)
    }

    func testStoreLandsAtStrideOffsets() {
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: AlphaBlendUniform.stride * 2, alignment: 16)
        defer { buffer.deallocate() }

        AlphaBlendUniform(color: Vec4(1, 2, 3, 4)).store(into: buffer, index: 0)
        AlphaBlendUniform(color: Vec4(5, 6, 7, 8)).store(into: buffer, index: 1)

        XCTAssertEqual(buffer.load(fromByteOffset: 16, as: Vec4.self), Vec4(1, 2, 3, 4))
        XCTAssertEqual(buffer.load(fromByteOffset: 64 + 16, as: Vec4.self), Vec4(5, 6, 7, 8))
    }
}
