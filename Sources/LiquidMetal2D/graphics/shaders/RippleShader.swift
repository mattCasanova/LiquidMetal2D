//
//  RippleShader.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Metal

/// Renders textured sprites with a UV-ripple distortion effect. Filters
/// objects by ``RippleComponent``; objects without one are silently skipped.
///
/// Batches by texture, same pattern as ``AlphaBlendShader`` — scenes with
/// mixed textures get one draw call per texture bucket.
@MainActor
public final class RippleShader: Shader {

    public let maxObjects: Int

    private unowned let renderCore: RenderCore
    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer
    private let samplerState: MTLSamplerState
    let bufferProvider: BufferProvider

    private var worldBuffer: MTLBuffer?
    private var worldBufferContents: UnsafeMutableRawPointer?

    /// This frame's instances and texture runs. Readable by tests.
    private(set) var instances = InstanceBatches()
    private var drawList = DrawList<RippleComponent>()

    public init(renderCore: RenderCore, maxObjects: Int) {
        self.renderCore = renderCore
        self.maxObjects = maxObjects
        self.pipelineState = RipplePipeline.create(renderCore: renderCore)
        self.vertexBuffer = renderCore.createQuad()

        guard let sampler = renderCore.createDefaultSampler() else {
            fatalError("RippleShader: unable to create sampler state")
        }
        self.samplerState = sampler
        self.bufferProvider = BufferProvider(
            device: renderCore.device,
            size: RippleUniform.stride * maxObjects)
    }

    // MARK: - Shader protocol

    public func beginFrame() -> Bool {
        guard bufferProvider.wait() else { return false }
        let buffer = bufferProvider.nextBuffer()
        worldBuffer = buffer
        worldBufferContents = buffer.contents()
        instances.reset()
        return true
    }

    public func bind(pass: RenderPass, projectionBuffer: MTLBuffer) {
        guard let worldBuffer else { return }
        let encoder = pass.encoder
        encoder.setViewport(renderCore.viewport)
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(
            vertexBuffer, offset: 0, index: RipplePipeline.vertexBufferIndex)
        encoder.setVertexBuffer(
            projectionBuffer, offset: 0, index: RipplePipeline.projectionBufferIndex)
        encoder.setVertexBuffer(
            worldBuffer, offset: 0, index: RipplePipeline.worldBufferIndex)
        encoder.setFragmentSamplerState(
            samplerState, index: RipplePipeline.samplerIndex)
    }

    public func submit(objects: [GameObj]) {
        guard let contents = worldBufferContents else { return }

        drawList.rebuild(from: objects)
        defer { drawList.clear() }
        // Loop on a local: the stored property would pay an exclusivity check per sprite.
        var frame = InstanceBatches()
        swap(&frame, &instances)
        defer { swap(&frame, &instances) }
        for (_, comp) in drawList.pairs {
            assert(frame.count < maxObjects,
                   "RippleShader draw count \(frame.count) exceeds maxObjects \(maxObjects)")
            guard frame.count < maxObjects else { break }

            comp.makeUniform().store(into: contents, index: frame.count)
            frame.append(textureId: comp.textureID)
        }
    }

    public func flush(pass: RenderPass) {
        guard !instances.batches.isEmpty else { return }
        let encoder = pass.encoder
        for batch in instances.batches {
            encoder.setFragmentTexture(
                renderCore.textureManager.getTexture(id: batch.textureId),
                index: RipplePipeline.textureIndex)
            let offset = batch.startIndex * RippleUniform.stride
            encoder.setVertexBufferOffset(
                offset, index: RipplePipeline.worldBufferIndex)
            encoder.drawPrimitives(
                type: .triangleStrip, vertexStart: 0,
                vertexCount: 4, instanceCount: batch.count)
        }
        instances.removeDrawnBatches()
    }

    public nonisolated func signalFrameComplete() {
        bufferProvider.signal()
    }
}
