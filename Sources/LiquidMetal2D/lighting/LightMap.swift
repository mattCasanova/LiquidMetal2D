//
//  LightMap.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/5/26.
//

import Metal

/// The frame's lights, drawn into an offscreen float texture that the
/// renderer then multiplies over the scene.
///
/// Each frame: ``begin()``, set ``ambient``, ``add(_:outline:)`` every
/// light, ``commit(viewProjection:)``. The commit encodes and commits its
/// own command buffer before the scene's pass, and Metal orders the two on
/// the one queue. A light is a fan of triangles around its position; the
/// fragment shader does the falloff, so the fan's shape never shows. The
/// engine builds the fan when no outline is passed (a 48-gon, or an arc for
/// a cone); a ``VisibilityPolygon``'s points make the walls cast shadows.
/// `add` writes straight into this frame's buffer and allocates nothing.
/// Then, inside the scene's pass, ``Renderer/composite(_:)`` multiplies the
/// texture over everything drawn so far; what is submitted after it stays
/// bright (emissive: neon, eyes, UI).
@MainActor
public final class LightMap {
    private static let spokes = 48

    /// What the texture is cleared to each frame: the dark the lights add to.
    public var ambient = Vec3(0, 0, 0)
    public let maxLights: Int
    public let maxVertices: Int
    /// Texture size as a fraction of the drawable: half resolution softens
    /// edges for free and quarters the fill cost.
    public let resolutionScale: Float

    private unowned let renderCore: RenderCore
    private let pipelineState: MTLRenderPipelineState
    private let compositePipeline: MTLRenderPipelineState
    private let compositeSampler: MTLSamplerState
    private let bufferProvider: BufferProvider
    /// Vertices fill the front of each buffer; the lights follow.
    private let verticesSize: Int
    private var buffer: MTLBuffer?
    private var contents: UnsafeMutableRawPointer?
    /// Lights added since `begin()`; a readout for demos and tools.
    public private(set) var lightCount = 0
    /// Fan vertices written since `begin()`.
    public private(set) var vertexCount = 0
    private var hasBegun = false
    /// `commit` ran since the last `begin`: the texture holds this frame's lights.
    private var isCommitted = false
    /// The lights' texture. Tests read it back; the composite samples it.
    private(set) var texture: MTLTexture

    public init(
        renderCore: RenderCore, maxLights: Int = 64, maxVertices: Int = 18_432, resolutionScale: Float = 0.5
    ) {
        precondition(maxLights > 0 && maxVertices >= 3, "LightMap needs room for at least one light")
        precondition(resolutionScale > 0 && resolutionScale <= 1, "LightMap resolutionScale must be in (0, 1]")
        self.renderCore = renderCore
        self.maxLights = maxLights
        self.maxVertices = maxVertices
        self.resolutionScale = resolutionScale
        pipelineState = LightPipeline.createLights(renderCore: renderCore)
        compositePipeline = LightPipeline.createComposite(renderCore: renderCore)
        compositeSampler = LightPipeline.createCompositeSampler(renderCore: renderCore)
        verticesSize = LightVertex.stride * maxVertices
        bufferProvider = BufferProvider(
            device: renderCore.device, size: verticesSize + LightUniform.stride * maxLights)
        texture = Self.makeTexture(
            device: renderCore.device, size: Self.textureSize(renderCore, scale: resolutionScale))
    }

    /// Takes this frame's buffer and resizes the texture if the drawable
    /// changed. False means no buffer was free in time: skip the lights this
    /// frame, as ``Renderer/beginPass()`` does for the scene.
    public func begin() -> Bool {
        assert(!hasBegun, "LightMap.begin() twice without commit(): commit() before the scene's pass")
        // A begin() with no commit() still holds its buffer, which never
        // reached the GPU: reuse it rather than take (and leak) another.
        if !hasBegun {
            guard bufferProvider.wait() else { return false }
            let buffer = bufferProvider.nextBuffer()
            self.buffer = buffer
            contents = buffer.contents()
        }
        lightCount = 0
        vertexCount = 0
        hasBegun = true
        isCommitted = false
        let wanted = Self.textureSize(renderCore, scale: resolutionScale)
        if texture.width != wanted.width || texture.height != wanted.height {
            texture = Self.makeTexture(device: renderCore.device, size: wanted)
        }
        return true
    }

    /// Adds a light. `outline` is its shape, counter-clockwise around the
    /// light (a ``VisibilityPolygon``'s points, closed for an all-round
    /// light, open for a cone); nil draws the plain pool or cone. A light
    /// costs 3 vertices per outline point: a plain pool 144, a shadowed
    /// light 3 × (48 + 3 per wall corner in reach). Past `maxLights` or
    /// `maxVertices` the light is dropped (an assert in Debug). A `radius`
    /// of 0 is a light turned off; a negative radius, a `falloff` of 0 or
    /// less, or a `halfAngle` outside (0, π] is a programmer error.
    public func add(_ light: Light, outline: [Vec2]? = nil) {
        assert(hasBegun, "LightMap.add before begin()")
        guard hasBegun, let contents else { return }
        assert(light.radius >= 0 && light.falloff > 0 && light.halfAngle > 0 && light.halfAngle <= .pi,
               "LightMap.add: a light needs radius ≥ 0, falloff > 0 and halfAngle in (0, π]: \(light)")
        guard light.radius > 0, light.falloff > 0, light.halfAngle > 0, light.halfAngle <= .pi else { return }
        assert(lightCount < maxLights, "LightMap: more than \(maxLights) lights; raise maxLights")
        guard lightCount < maxLights else { return }

        let segments: Int
        if let outline {
            assert(outline.count >= 2, "LightMap.add: an outline needs 2 points or more; compute it first")
            segments = light.isCone ? outline.count - 1 : outline.count
        } else {
            segments = Self.fanSegments(for: light)
        }
        guard segments > 0 else { return }
        assert(vertexCount + segments * 3 <= maxVertices, "LightMap: past \(maxVertices) vertices; raise maxVertices")
        guard vertexCount + segments * 3 <= maxVertices else { return }

        let index = UInt32(lightCount)
        Self.uniform(for: light).store(into: contents + verticesSize, index: lightCount)
        lightCount += 1

        let centre = LightVertex(position: light.position, z: light.z, light: index)
        for segment in 0..<segments {
            let first: Vec2
            let second: Vec2
            if let outline {
                first = outline[segment]
                second = outline[(segment + 1) % outline.count]
            } else {
                first = Self.rimPoint(light, step: segment, of: segments)
                second = Self.rimPoint(light, step: segment + 1, of: segments)
            }
            centre.store(into: contents, index: vertexCount)
            LightVertex(position: first, z: light.z, light: index).store(into: contents, index: vertexCount + 1)
            LightVertex(position: second, z: light.z, light: index).store(into: contents, index: vertexCount + 2)
            vertexCount += 3
        }
    }

    /// Draws this frame's lights into the texture on their own command
    /// buffer and commits it. Call before the scene's pass. `viewProjection`
    /// nil uses the perspective projection and camera, as `usePerspective`
    /// does; a scene drawn with `useOrthographic` passes
    /// `renderCore.orthographic.make()`.
    public func commit(viewProjection: Mat4? = nil) {
        assert(hasBegun, "LightMap.commit before begin()")
        guard hasBegun, let buffer else { return }
        hasBegun = false
        contents = nil

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(ambient.x), green: Double(ambient.y), blue: Double(ambient.z), alpha: 1)
        descriptor.colorAttachments[0].storeAction = .store

        guard let commandBuffer = renderCore.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            assertionFailure("LightMap: Metal gave no command buffer or encoder")
            bufferProvider.signal()
            return
        }
        encoder.setViewport(MTLViewport(
            originX: 0, originY: 0, width: Double(texture.width), height: Double(texture.height), znear: 0, zfar: 1))
        if vertexCount > 0 {
            var matrix = viewProjection ?? renderCore.perspective.make() * renderCore.camera2D.make()
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(buffer, offset: 0, index: LightPipeline.vertexBufferIndex)
            encoder.setVertexBytes(
                &matrix, length: MemoryLayout<Mat4>.stride, index: LightPipeline.viewProjectionBufferIndex)
            encoder.setFragmentBuffer(buffer, offset: verticesSize, index: LightPipeline.lightsBufferIndex)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        }
        encoder.endEncoding()
        let provider = bufferProvider
        commandBuffer.addCompletedHandler { _ in provider.signal() }
        commandBuffer.commit()
        isCommitted = true
    }

    /// Multiplies this frame's light texture over what `pass` has drawn so
    /// far, with one full-screen triangle. ``Renderer/composite(_:)`` calls
    /// it after flushing the current shader; game code goes through that.
    /// Needs a ``commit(viewProjection:)`` since the last `begin()`.
    public func composite(on pass: RenderPass) {
        assert(isCommitted, "LightMap.composite before commit(): the texture holds no lights for this frame")
        guard isCommitted else { return }
        let encoder = pass.encoder
        encoder.setViewport(renderCore.viewport)
        encoder.setRenderPipelineState(compositePipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(compositeSampler, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }

    // MARK: - Shapes

    /// A pool is a 48-gon; a cone an arc of equal steps about π/48 wide (at
    /// least 4), open at the back.
    private static func fanSegments(for light: Light) -> Int {
        guard light.isCone else { return spokes }
        return max(4, Int(light.halfAngle / (Float.pi / Float(spokes))) * 2)
    }

    /// Rim corner `step` of `segments`, pushed out so the light's circle fits
    /// inside the fan; the shader's falloff ends at `radius` anyway.
    private static func rimPoint(_ light: Light, step: Int, of segments: Int) -> Vec2 {
        let span = light.isCone ? 2 * light.halfAngle : 2 * Float.pi
        let stepAngle = span / Float(segments)
        let start = light.isCone ? light.direction - light.halfAngle : 0
        let angle = start + Float(step) * stepAngle
        let reach = light.radius / cos(stepAngle / 2)
        return light.position + Vec2(cos(angle), sin(angle)) * reach
    }

    private static func uniform(for light: Light) -> LightUniform {
        // The fade needs a band below 1: with no softness the edge is a hard
        // step, and a hairline cone must still reach full brightness on its axis.
        let cosHalfAngle: Float = light.isCone ? min(cos(light.halfAngle), 1 - 2e-4) : -1
        let inner: Float = light.isCone
            ? min(max(cos(max(light.halfAngle - light.edgeSoftness, 0)), cosHalfAngle + 1e-4), 1) : 1
        return LightUniform(
            color: Vec4(light.color * light.intensity, 0),
            center: light.position, radius: light.radius, falloff: light.falloff,
            direction: Vec2(cos(light.direction), sin(light.direction)),
            cosHalfAngle: cosHalfAngle, cosInner: inner)
    }

    // MARK: - Texture

    private static func textureSize(_ renderCore: RenderCore, scale: Float) -> (width: Int, height: Int) {
        let size = renderCore.layer.drawableSize
        return (max(1, Int((Float(size.width) * scale).rounded())), max(1, Int((Float(size.height) * scale).rounded())))
    }

    private static func makeTexture(device: MTLDevice, size: (width: Int, height: Int)) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: LightPipeline.pixelFormat, width: size.width, height: size.height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("LightMap: could not create a \(size.width)×\(size.height) light texture")
        }
        return texture
    }
}
