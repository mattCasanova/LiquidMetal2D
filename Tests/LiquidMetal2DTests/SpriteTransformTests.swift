import Metal
import XCTest
@testable import LiquidMetal2D

/// The sprite transform the shaders build on the GPU (`spriteWorld`, one copy
/// in each `.metalSource`) against the matrix the CPU builds with
/// `Mat4.makeTransform2D`. The GPU half compiles each shader's source with a
/// small compute kernel added, and runs it on the simulator's Metal device.
@MainActor
final class SpriteTransformTests: XCTestCase {

    private struct Case {
        let vertex: Vec3
        let transform: Transform2D
    }

    private static let shaders = ["AlphaBlendShader", "ParticleShader", "RippleShader", "WireframeShader"]

    /// The formula each shader's `spriteWorld` implements, written out in Swift.
    private static func reference(_ c: Case) -> Vec4 {
        let t = c.transform
        let cosine = cos(t.rotation)
        let sine = sin(t.rotation)
        let p = Vec2(c.vertex.x, c.vertex.y) * t.scale
        return Vec4(p.x * cosine - p.y * sine + t.position.x,
                    p.x * sine + p.y * cosine + t.position.y,
                    c.vertex.z + t.zOrder, 1)
    }

    /// Points on and inside the quad, anywhere a sprite goes, flipped or not
    /// (the skeleton flips with negative scale), turned more than a full circle.
    private static func makeCases(count: Int, seed: UInt64) -> [Case] {
        var rng = SeededRandom(seed: seed)
        func signed(_ range: ClosedRange<Float>) -> Float {
            let magnitude = Float.random(in: range, using: &rng)
            return Bool.random(using: &rng) ? magnitude : -magnitude
        }
        return (0..<count).map { _ in
            Case(vertex: Vec3(Float.random(in: -0.5...0.5, using: &rng),
                              Float.random(in: -0.5...0.5, using: &rng),
                              Float.random(in: -1...1, using: &rng)),
                 transform: Transform2D(
                    position: Vec2(Float.random(in: -50...50, using: &rng), Float.random(in: -50...50, using: &rng)),
                    scale: Vec2(signed(0.1...3), signed(0.1...3)),
                    rotation: Float.random(in: -2 * Float.pi...2 * Float.pi, using: &rng),
                    zOrder: Float.random(in: 0...60, using: &rng)))
        }
    }

    /// Largest difference in any component, relative to the expected size (at least 1).
    private static func error(_ actual: Vec4, _ expected: Vec4) -> Float {
        return simd_abs(actual - expected).max() / max(1, simd_abs(expected).max())
    }

    func testReferenceMatchesMakeTransform2D() throws {
        let cases = Self.makeCases(count: 1000, seed: 21)
        let errors = cases.map { c in
            let t = c.transform
            let matrix = Mat4.makeTransform2D(scale: t.scale, angle: t.rotation, translate: Vec3(t.position, t.zOrder))
            return Self.error(Self.reference(c), matrix * Vec4(c.vertex, 1))
        }
        let worst = try XCTUnwrap(errors.indices.max { errors[$0] < errors[$1] })
        XCTAssertLessThanOrEqual(errors[worst], 1e-5, "case \(worst): \(cases[worst])")
    }

    /// Each shader reads Swift `Transform2D` values straight from a buffer, so
    /// this also checks that the Swift and MSL structs lay out the same.
    func testEveryShadersSpriteWorldMatchesTheReference() throws {
        let device = try ShaderTestSupport.makeDevice()
        let cases = Self.makeCases(count: 1024, seed: 22)

        for shader in Self.shaders {
            let results = try Self.runSpriteWorld(of: shader, cases: cases, device: device)
            let errors = zip(results, cases).map { Self.error($0, Self.reference($1)) }
            let worst = try XCTUnwrap(errors.indices.max { errors[$0] < errors[$1] })
            // The GPU's sin/cos are fast-math; a wrong sign or a swapped term is off by far more.
            XCTAssertLessThanOrEqual(errors[worst], 1e-4,
                                     "\(shader): case \(worst) \(cases[worst]) gave \(results[worst])")
        }
    }

    // MARK: - GPU

    private static let kernel = """

        kernel void testSpriteWorld(device const float4* corners [[ buffer(0) ]],
                                    device const Transform2D* transforms [[ buffer(1) ]],
                                    device float4* results [[ buffer(2) ]],
                                    uint id [[ thread_position_in_grid ]]) {
            results[id] = spriteWorld(corners[id].xyz, transforms[id]);
        }
        """

    /// Compiles `shader`'s own source (with the engine's compile options) plus
    /// a kernel that calls its `spriteWorld` once per case, and runs it.
    private static func runSpriteWorld(of shader: String, cases: [Case], device: MTLDevice) throws -> [Vec4] {
        let threadsPerGroup = 64
        XCTAssertEqual(cases.count % threadsPerGroup, 0, "the kernel has no bounds check")

        let source = RenderCore.shaderSource(resource: shader, withExtension: "metalSource") + kernel
        let library = try device.makeLibrary(source: source, options: nil)
        let function = try XCTUnwrap(library.makeFunction(name: "testSpriteWorld"))
        let pipeline = try device.makeComputePipelineState(function: function)

        let corners = cases.map { Vec4($0.vertex, 0) }
        let transforms = cases.map(\.transform)
        let cornerBuffer = try XCTUnwrap(device.makeBuffer(
            bytes: corners, length: corners.count * MemoryLayout<Vec4>.stride))
        let transformBuffer = try XCTUnwrap(device.makeBuffer(
            bytes: transforms, length: transforms.count * MemoryLayout<Transform2D>.stride))
        let resultBuffer = try XCTUnwrap(device.makeBuffer(length: cases.count * MemoryLayout<Vec4>.stride))

        let queue = try XCTUnwrap(device.makeCommandQueue())
        let commands = try XCTUnwrap(queue.makeCommandBuffer())
        let encoder = try XCTUnwrap(commands.makeComputeCommandEncoder())
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(cornerBuffer, offset: 0, index: 0)
        encoder.setBuffer(transformBuffer, offset: 0, index: 1)
        encoder.setBuffer(resultBuffer, offset: 0, index: 2)
        encoder.dispatchThreadgroups(
            MTLSize(width: cases.count / threadsPerGroup, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadsPerGroup, height: 1, depth: 1))
        encoder.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()
        XCTAssertNil(commands.error, "\(shader): the kernel failed")

        let results = resultBuffer.contents().bindMemory(to: Vec4.self, capacity: cases.count)
        return Array(UnsafeBufferPointer(start: results, count: cases.count))
    }
}
