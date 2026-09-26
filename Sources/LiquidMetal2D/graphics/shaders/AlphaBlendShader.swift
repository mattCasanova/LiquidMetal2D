//
//  AlphaBlendShader.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Metal

/// The built-in shader for alpha-blended textured sprites. Filters objects by
/// ``AlphaBlendComponent``; objects without one are silently skipped.
///
/// Batching: within a ``submit(objects:)`` call, objects are sorted by
/// `(zOrder, textureID)` and rendered via instanced draws per texture.
@MainActor
public final class AlphaBlendShader: Shader {

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
    private var drawList = DrawList<AlphaBlendComponent>()

    public init(renderCore: RenderCore, maxObjects: Int) {
        self.renderCore = renderCore
        self.maxObjects = maxObjects
        self.pipelineState = AlphaBlendPipeline.create(renderCore: renderCore)
        self.vertexBuffer = renderCore.createQuad()

        guard let sampler = renderCore.createDefaultSampler() else {
            fatalError("AlphaBlendShader: unable to create sampler state")
        }
        self.samplerState = sampler
        self.bufferProvider = BufferProvider(
            device: renderCore.device,
            size: AlphaBlendUniform.stride * maxObjects)
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
            vertexBuffer, offset: 0, index: AlphaBlendPipeline.vertexBufferIndex)
        encoder.setVertexBuffer(
            projectionBuffer, offset: 0, index: AlphaBlendPipeline.projectionBufferIndex)
        encoder.setVertexBuffer(
            worldBuffer, offset: 0, index: AlphaBlendPipeline.worldBufferIndex)
        encoder.setFragmentSamplerState(
            samplerState, index: AlphaBlendPipeline.samplerIndex)
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
                   "AlphaBlendShader draw count \(frame.count) exceeds maxObjects \(maxObjects)")
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
                index: AlphaBlendPipeline.textureIndex)
            let offset = batch.startIndex * AlphaBlendUniform.stride
            encoder.setVertexBufferOffset(
                offset, index: AlphaBlendPipeline.worldBufferIndex)
            encoder.drawPrimitives(
                type: .triangleStrip, vertexStart: 0,
                vertexCount: 4, instanceCount: batch.count)
        }
        instances.removeDrawnBatches()
    }

    public nonisolated func signalFrameComplete() {
        bufferProvider.signal()
    }

    // MARK: - Advanced draw path

    /// Appends a single instance to the current frame. No sort; consecutive
    /// calls with the same `textureId` batch into one instanced draw call.
    /// Pass `obj.transform` to draw a ``GameObj`` where it stands.
    public func draw(
        _ transform: Transform2D,
        texTrans: Vec4 = Vec4(1, 1, 0, 0),
        color: Vec4 = Vec4(1, 1, 1, 1),
        textureId: Int
    ) {
        assert(instances.count < maxObjects,
               "AlphaBlendShader draw count \(instances.count) exceeds maxObjects \(maxObjects)")
        guard instances.count < maxObjects, let contents = worldBufferContents else { return }

        AlphaBlendUniform(texTrans: texTrans, color: color, transform: transform)
            .store(into: contents, index: instances.count)
        instances.append(textureId: textureId)
    }
}
