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
    private var drawCount: Int = 0

    private struct TextureBatch {
        let textureId: Int
        let startIndex: Int
        var count: Int
    }
    private var batches: [TextureBatch] = []

    private let scratchUniform = AlphaBlendUniform()

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
            size: AlphaBlendUniform.typeSize() * maxObjects)
    }

    // MARK: - Shader protocol

    public func beginFrame() -> Bool {
        guard bufferProvider.wait() else { return false }
        let buffer = bufferProvider.nextBuffer()
        worldBuffer = buffer
        worldBufferContents = buffer.contents()
        drawCount = 0
        batches.removeAll(keepingCapacity: true)
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

        let pairs: [(GameObj, AlphaBlendComponent)] = objects.compactMap { obj in
            guard obj.isActive, let comp = obj.get(AlphaBlendComponent.self) else {
                return nil
            }
            return (obj, comp)
        }.sorted { lhs, rhs in
            if lhs.0.zOrder != rhs.0.zOrder { return lhs.0.zOrder < rhs.0.zOrder }
            return lhs.1.textureID < rhs.1.textureID
        }

        for (_, comp) in pairs {
            assert(drawCount < maxObjects,
                   "AlphaBlendShader draw count \(drawCount) exceeds maxObjects \(maxObjects)")
            guard drawCount < maxObjects else { break }

            comp.fillUniform(scratchUniform)
            scratchUniform.setBuffer(buffer: contents, offsetIndex: drawCount)
            appendBatch(textureId: comp.textureID)
            drawCount += 1
        }
    }

    public func flush(pass: RenderPass) {
        guard !batches.isEmpty else { return }
        let encoder = pass.encoder
        for batch in batches {
            encoder.setFragmentTexture(
                renderCore.textureManager.getTexture(id: batch.textureId),
                index: AlphaBlendPipeline.textureIndex)
            let offset = batch.startIndex * AlphaBlendUniform.typeSize()
            encoder.setVertexBufferOffset(
                offset, index: AlphaBlendPipeline.worldBufferIndex)
            encoder.drawPrimitives(
                type: .triangleStrip, vertexStart: 0,
                vertexCount: 4, instanceCount: batch.count)
        }
        batches.removeAll(keepingCapacity: true)
    }

    public nonisolated func signalFrameComplete() {
        bufferProvider.signal()
    }

    // MARK: - Advanced draw path

    /// Appends a single instance to the current frame. No sort; consecutive
    /// calls with the same `textureId` batch into one instanced draw call.
    public func draw(
        transform: Mat4,
        texTrans: Vec4 = Vec4(1, 1, 0, 0),
        color: Vec4 = Vec4(1, 1, 1, 1),
        textureId: Int
    ) {
        assert(drawCount < maxObjects,
               "AlphaBlendShader draw count \(drawCount) exceeds maxObjects \(maxObjects)")
        guard drawCount < maxObjects, let contents = worldBufferContents else { return }

        scratchUniform.transform = transform
        scratchUniform.texTrans = texTrans
        scratchUniform.color = color
        scratchUniform.setBuffer(buffer: contents, offsetIndex: drawCount)
        appendBatch(textureId: textureId)
        drawCount += 1
    }

    // MARK: - Helpers

    private func appendBatch(textureId: Int) {
        if let last = batches.last, last.textureId == textureId {
            batches[batches.count - 1].count += 1
        } else {
            batches.append(TextureBatch(
                textureId: textureId, startIndex: drawCount, count: 1))
        }
    }
}
