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
/// - ``BlendMode/additive`` (default): order-independent, overlapping
///   particles brighten into hotspots — glow, fire, sparks, lasers.
/// - ``BlendMode/alpha``: classic "over" compositing, back-to-front sorted
///   by each particle's `zOrder` before drawing — smoke, dust, fog.
///
/// Batches by the emitter's `textureID` so emitters with different textures
/// split into separate instanced draws.
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

    /// Scratch record used to collect particles during `submit` in alpha
    /// mode, where we need to sort by `zOrder` before writing uniforms.
    /// Additive mode writes directly and skips this buffer.
    private struct DrawItem {
        let textureId: Int
        let transform: Mat4
        let color: Vec4
        let zOrder: Float
    }
    private var alphaItems: [DrawItem] = []

    private let scratchUniform = ParticleUniform()

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
        alphaItems.removeAll(keepingCapacity: true)
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

        switch blendMode {
        case .additive:
            submitAdditive(objects: objects, contents: contents)
        case .alpha:
            submitAlpha(objects: objects, contents: contents)
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

    // MARK: - Submit implementations

    /// Additive path: sort emitters by `textureID` so particles sharing a
    /// texture form one contiguous batch even when emitters are interleaved
    /// in the object list. Addition is commutative, so reordering emitters
    /// has no visual effect — the sort is a pure batching win.
    private func submitAdditive(
        objects: [GameObj],
        contents: UnsafeMutableRawPointer
    ) {
        let pairs: [(GameObj, ParticleEmitterComponent)] = objects.compactMap { obj in
            guard obj.isActive,
                  let emitter = obj.get(ParticleEmitterComponent.self) else {
                return nil
            }
            return (obj, emitter)
        }.sorted { $0.1.textureID < $1.1.textureID }

        for (obj, emitter) in pairs {
            for particle in emitter.particles where particle.isAlive {
                assert(drawCount < maxObjects,
                       "ParticleShader draw count \(drawCount) exceeds maxObjects \(maxObjects)")
                guard drawCount < maxObjects else { return }

                let t = min(particle.age / particle.lifetime, 1)
                let scale = mix(particle.startScale, particle.endScale, t: t)
                scratchUniform.transform.setToTransform2D(
                    scale: scale,
                    angle: particle.rotation,
                    translate: Vec3(particle.position, obj.zOrder))
                scratchUniform.color = mix(particle.startColor, particle.endColor, t: t)
                scratchUniform.setBuffer(buffer: contents, offsetIndex: drawCount)
                appendBatch(textureId: emitter.textureID)
                drawCount += 1
            }
        }
    }

    /// Alpha path: collect every live particle into `alphaItems`, sort by
    /// `zOrder` back-to-front, then write uniforms + batches in the sorted
    /// order. More expensive than additive but required for correct "over"
    /// compositing.
    private func submitAlpha(
        objects: [GameObj],
        contents: UnsafeMutableRawPointer
    ) {
        for obj in objects where obj.isActive {
            guard let emitter = obj.get(ParticleEmitterComponent.self) else { continue }

            for particle in emitter.particles where particle.isAlive {
                let t = min(particle.age / particle.lifetime, 1)
                let scale = mix(particle.startScale, particle.endScale, t: t)
                var transform = Mat4()
                transform.setToTransform2D(
                    scale: scale,
                    angle: particle.rotation,
                    translate: Vec3(particle.position, obj.zOrder))
                let color = mix(particle.startColor, particle.endColor, t: t)
                alphaItems.append(DrawItem(
                    textureId: emitter.textureID,
                    transform: transform,
                    color: color,
                    zOrder: obj.zOrder))
            }
        }

        // Back-to-front: larger zOrder (farther from the camera) drawn first.
        // In this engine, zOrder ascending means closer to the camera, so we
        // sort descending for the painter's algorithm.
        alphaItems.sort { $0.zOrder > $1.zOrder }

        for item in alphaItems {
            assert(drawCount < maxObjects,
                   "ParticleShader draw count \(drawCount) exceeds maxObjects \(maxObjects)")
            guard drawCount < maxObjects else { return }

            scratchUniform.transform = item.transform
            scratchUniform.color = item.color
            scratchUniform.setBuffer(buffer: contents, offsetIndex: drawCount)
            appendBatch(textureId: item.textureId)
            drawCount += 1
        }
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
