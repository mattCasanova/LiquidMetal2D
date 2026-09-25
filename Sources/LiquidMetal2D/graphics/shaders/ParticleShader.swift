//
//  ParticleShader.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Metal

/// Renders live particles from every ``ParticleEmitterComponent`` in the
/// object list. Supports two blend modes:
///
/// - ``BlendMode/additive`` (default): overlapping particles brighten into
///   hotspots — glow, fire, sparks, lasers.
/// - ``BlendMode/alpha``: classic "over" compositing — smoke, dust, fog.
///
/// Both modes walk emitters in ``DrawList`` order: ascending `zOrder`
/// (far to near, which "over" compositing needs) and then by texture, so
/// particles sharing a texture form one instanced draw. Every particle of an
/// emitter shares its `zOrder`, so sorting the emitters orders the particles.
///
/// Additive mode doesn't need the z sort: addition (clamped at 1) gives the
/// same pixel in any order, and z only affects each particle's transform.
/// The cost is at most one extra instanced draw per emitter when emitters at
/// different z alternate textures. Kept for one code path; if a scene ever
/// has many additive emitters sharing few textures, give additive mode a
/// texture-only sort key.
@MainActor
public final class ParticleShader: Shader {

    public enum BlendMode: Sendable {
        case additive
        case alpha
    }

    public let maxObjects: Int
    public let blendMode: BlendMode

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
    private var drawList = DrawList<ParticleEmitterComponent>()

    public init(
        renderCore: RenderCore,
        maxObjects: Int,
        blendMode: BlendMode = .additive
    ) {
        self.renderCore = renderCore
        self.maxObjects = maxObjects
        self.blendMode = blendMode
        self.pipelineState = ParticlePipeline.create(
            renderCore: renderCore, blendMode: blendMode)
        self.vertexBuffer = renderCore.createQuad()

        guard let sampler = renderCore.createDefaultSampler() else {
            fatalError("ParticleShader: unable to create sampler state")
        }
        self.samplerState = sampler
        self.bufferProvider = BufferProvider(
            device: renderCore.device,
            size: ParticleUniform.stride * maxObjects)
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

        drawList.rebuild(from: objects)
        defer { drawList.clear() }
        for (obj, emitter) in drawList.pairs {
            for particle in emitter.particles where particle.isAlive {
                assert(drawCount < maxObjects,
                       "ParticleShader draw count \(drawCount) exceeds maxObjects \(maxObjects)")
                guard drawCount < maxObjects else { return }

                let t = min(particle.age / particle.lifetime, 1)
                ParticleUniform(
                    transform: Mat4.makeTransform2D(
                        scale: mix(particle.startScale, particle.endScale, t: t),
                        angle: particle.rotation,
                        translate: Vec3(particle.position, obj.zOrder)),
                    color: mix(particle.startColor, particle.endColor, t: t))
                    .store(into: contents, index: drawCount)
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
            let offset = batch.startIndex * ParticleUniform.stride
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

    private func mix(_ a: Vec2, _ b: Vec2, t: Float) -> Vec2 {
        return a + (b - a) * t
    }
}
