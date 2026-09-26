//
//  WireframeShader.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Metal

/// Renders outlines of collider shapes (circle, AABB) for debug visualization.
/// Filters objects by ``WireframeComponent`` presence and reads the attached
/// ``Collider`` to determine shape + size.
///
/// Unlike ``AlphaBlendShader``, there is no texture batching — the instances
/// submitted since the last flush issue in one instanced draw call, with
/// color/shape/thickness per instance.
@MainActor
public final class WireframeShader: Shader {

    private static let shapeCircle: Float = 0
    private static let shapeAABB: Float = 1

    public let maxObjects: Int

    private unowned let renderCore: RenderCore
    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer
    let bufferProvider: BufferProvider

    private var worldBuffer: MTLBuffer?
    /// This frame's uniforms. Readable by tests.
    private(set) var worldBufferContents: UnsafeMutableRawPointer?
    /// Instances written this frame.
    private var drawCount: Int = 0
    /// Instances already encoded by an earlier ``flush(pass:)`` this frame.
    private var drawnCount: Int = 0

    public init(renderCore: RenderCore, maxObjects: Int) {
        self.renderCore = renderCore
        self.maxObjects = maxObjects
        self.pipelineState = WireframePipeline.create(renderCore: renderCore)
        self.vertexBuffer = renderCore.createQuad()
        self.bufferProvider = BufferProvider(
            device: renderCore.device,
            size: WireframeUniform.stride * maxObjects)
    }

    // MARK: - Shader protocol

    public func beginFrame() -> Bool {
        guard bufferProvider.wait() else { return false }
        let buffer = bufferProvider.nextBuffer()
        worldBuffer = buffer
        worldBufferContents = buffer.contents()
        drawCount = 0
        drawnCount = 0
        return true
    }

    public func bind(pass: RenderPass, projectionBuffer: MTLBuffer) {
        guard let worldBuffer else { return }
        let encoder = pass.encoder
        encoder.setViewport(renderCore.viewport)
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(
            vertexBuffer, offset: 0, index: WireframePipeline.vertexBufferIndex)
        encoder.setVertexBuffer(
            projectionBuffer, offset: 0, index: WireframePipeline.projectionBufferIndex)
        encoder.setVertexBuffer(
            worldBuffer, offset: 0, index: WireframePipeline.worldBufferIndex)
    }

    public func submit(objects: [GameObj]) {
        guard let contents = worldBufferContents else { return }

        // Count in a local: the stored property would pay an exclusivity check per object.
        var count = drawCount
        defer { drawCount = count }
        for obj in objects where obj.isActive {
            guard let wire = obj.get(WireframeComponent.self) else { continue }

            let shapeParam: Float
            let shapeScale: Vec2

            if let circle = obj.get(CircleCollider.self) {
                shapeParam = Self.shapeCircle
                let diameter = circle.radius * 2
                shapeScale = Vec2(diameter, diameter)
            } else if let aabb = obj.get(AABBCollider.self) {
                shapeParam = Self.shapeAABB
                shapeScale = Vec2(aabb.width, aabb.height)
            } else {
                continue
            }

            assert(count < maxObjects,
                   "WireframeShader draw count \(count) exceeds maxObjects \(maxObjects)")
            guard count < maxObjects else { break }

            WireframeUniform(
                color: wire.color,
                params: Vec4(shapeParam, wire.thickness, 0, 0),
                transform: Transform2D(position: obj.position, scale: shapeScale, zOrder: obj.zOrder))
                .store(into: contents, index: count)
            count += 1
        }
    }

    /// Draws the instances submitted since the last flush, from their own
    /// slots. Their slots stay taken until the next frame: the GPU reads them
    /// after encoding ends, so a later submit this frame must not reuse them.
    public func flush(pass: RenderPass) {
        guard drawCount > drawnCount else { return }
        let encoder = pass.encoder
        encoder.setVertexBufferOffset(
            drawnCount * WireframeUniform.stride, index: WireframePipeline.worldBufferIndex)
        encoder.drawPrimitives(
            type: .triangleStrip, vertexStart: 0,
            vertexCount: 4, instanceCount: drawCount - drawnCount)
        drawnCount = drawCount
    }

    public nonisolated func signalFrameComplete() {
        bufferProvider.signal()
    }
}
