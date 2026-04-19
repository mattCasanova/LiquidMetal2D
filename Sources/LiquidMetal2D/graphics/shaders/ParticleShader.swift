//
//  ParticleShader.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Metal

/// Renders live particles from every ``ParticleEmitterComponent`` in the
/// object list, using additive blending. Order-independent — no z-sort.
/// Batches by the emitter's `textureID` so emitters with different textures
/// split into separate instanced draws.
@MainActor
public final class ParticleShader: Shader {

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

    private let scratchUniform = ParticleUniform()

    public init(renderCore: RenderCore, maxObjects: Int) {
        self.renderCore = renderCore
        self.maxObjects = maxObjects
        self.pipelineState = ParticlePipeline.create(renderCore: renderCore)
        self.vertexBuffer = renderCore.createQuad()

        guard let sampler = renderCore.createDefaultSampler() else {
            fatalError("ParticleShader: unable to create sampler state")
        }
        self.samplerState = sampler
        self.bufferProvider = BufferProvider(
            device: renderCore.device,
            size: ParticleUniform.typeSize() * maxObjects)
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
            vertexBuffer, offset: 0, index: ParticlePipeline.vertexBufferIndex)
        encoder.setVertexBuffer(
            projectionBuffer, offset: 0, index: ParticlePipeline.projectionBufferIndex)
        encoder.setVertexBuffer(
            worldBuffer, offset: 0, index: ParticlePipeline.worldBufferIndex)
        encoder.setFragmentSamplerState(
            samplerState, index: ParticlePipeline.samplerIndex)
    }

    public func submit(objects: [GameObj]) {
        guard let contents = worldBufferContents else { return }

        for obj in objects where obj.isActive {
            guard let emitter = obj.get(ParticleEmitterComponent.self) else { continue }

            for particle in emitter.particles where particle.isAlive {
                assert(drawCount < maxObjects,
                       "ParticleShader draw count \(drawCount) exceeds maxObjects \(maxObjects)")
                guard drawCount < maxObjects else { return }

                scratchUniform.transform.setToTransform2D(
                    scale: particle.scale,
                    angle: particle.rotation,
                    translate: Vec3(particle.position, obj.zOrder))
                let t = min(particle.age / particle.lifetime, 1)
                scratchUniform.color = mix(particle.startColor, particle.endColor, t: t)
                scratchUniform.setBuffer(buffer: contents, offsetIndex: drawCount)
                appendBatch(textureId: emitter.textureID)
                drawCount += 1
            }
        }
    }

    public func flush(pass: RenderPass) {
        guard !batches.isEmpty else { return }
        let encoder = pass.encoder
        for batch in batches {
            encoder.setFragmentTexture(
                renderCore.textureManager.getTexture(id: batch.textureId),
                index: ParticlePipeline.textureIndex)
            let offset = batch.startIndex * ParticleUniform.typeSize()
            encoder.setVertexBufferOffset(
                offset, index: ParticlePipeline.worldBufferIndex)
            encoder.drawPrimitives(
                type: .triangleStrip, vertexStart: 0,
                vertexCount: 4, instanceCount: batch.count)
        }
        batches.removeAll(keepingCapacity: true)
    }

    public nonisolated func signalFrameComplete() {
        bufferProvider.signal()
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

    private func mix(_ a: Vec4, _ b: Vec4, t: Float) -> Vec4 {
        return a + (b - a) * t
    }
}
