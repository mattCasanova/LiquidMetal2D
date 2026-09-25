import XCTest
@testable import LiquidMetal2D

/// Pins each uniform's stride and field offsets to the matching MSL struct.
/// The shaders compile at runtime, so nothing else checks that the Swift and
/// Metal sides agree; a mismatch here draws garbage from instance 1 onward.
final class UniformLayoutTests: XCTestCase {

    func testProjectionUniform() {
        XCTAssertEqual(ProjectionUniform.stride, 64)
        XCTAssertEqual(MemoryLayout<ProjectionUniform>.offset(of: \.transform), 0)
    }

    func testAlphaBlendUniform() {
        XCTAssertEqual(AlphaBlendUniform.stride, 96)
        XCTAssertEqual(MemoryLayout<AlphaBlendUniform>.offset(of: \.transform), 0)
        XCTAssertEqual(MemoryLayout<AlphaBlendUniform>.offset(of: \.texTrans), 64)
        XCTAssertEqual(MemoryLayout<AlphaBlendUniform>.offset(of: \.color), 80)
    }

    func testParticleUniform() {
        XCTAssertEqual(ParticleUniform.stride, 80)
        XCTAssertEqual(MemoryLayout<ParticleUniform>.offset(of: \.transform), 0)
        XCTAssertEqual(MemoryLayout<ParticleUniform>.offset(of: \.color), 64)
    }

    func testWireframeUniform() {
        XCTAssertEqual(WireframeUniform.stride, 96)
        XCTAssertEqual(MemoryLayout<WireframeUniform>.offset(of: \.transform), 0)
        XCTAssertEqual(MemoryLayout<WireframeUniform>.offset(of: \.color), 64)
        XCTAssertEqual(MemoryLayout<WireframeUniform>.offset(of: \.params), 80)
    }

    func testRippleUniform() {
        XCTAssertEqual(RippleUniform.stride, 112)
        XCTAssertEqual(MemoryLayout<RippleUniform>.offset(of: \.transform), 0)
        XCTAssertEqual(MemoryLayout<RippleUniform>.offset(of: \.texTrans), 64)
        XCTAssertEqual(MemoryLayout<RippleUniform>.offset(of: \.color), 80)
        XCTAssertEqual(MemoryLayout<RippleUniform>.offset(of: \.params), 96)
    }

    func testStoreLandsAtStrideOffsets() {
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: AlphaBlendUniform.stride * 2, alignment: 16)
        defer { buffer.deallocate() }

        AlphaBlendUniform(color: Vec4(1, 2, 3, 4)).store(into: buffer, index: 0)
        AlphaBlendUniform(color: Vec4(5, 6, 7, 8)).store(into: buffer, index: 1)

        XCTAssertEqual(buffer.load(fromByteOffset: 80, as: Vec4.self), Vec4(1, 2, 3, 4))
        XCTAssertEqual(buffer.load(fromByteOffset: 96 + 80, as: Vec4.self), Vec4(5, 6, 7, 8))
    }
}
