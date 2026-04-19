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
/// Unlike ``AlphaBlendShader``, there is no texture batching — all instances
/// issue in one instanced draw call, with color/shape/thickness per instance.
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
    private var worldBufferContents: UnsafeMutableRawPointer?
    private var drawCount: Int = 0

    private let scratchUniform = WireframeUniform()

    public init(renderCore: RenderCore, maxObjects: Int) {
        self.renderCore = renderCore
        self.maxObjects = maxObjects
        self.pipelineState = WireframePipeline.create(renderCore: renderCore)
        self.vertexBuffer = renderCore.createQuad()
        self.bufferProvider = BufferProvider(
            device: renderCore.device,
            size: WireframeUniform.typeSize() * maxObjects)
    }

    // MARK: - Shader protocol

    public func beginFrame() -> Bool {
        guard bufferProvider.wait() else { return false }
        let buffer = bufferProvider.nextBuffer()
        worldBuffer = buffer
        worldBufferContents = buffer.contents()
        drawCount = 0
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

            assert(drawCount < maxObjects,
                   "WireframeShader draw count \(drawCount) exceeds maxObjects \(maxObjects)")
            guard drawCount < maxObjects else { break }

            scratchUniform.transform.setToTransform2D(
                scale: shapeScale,
                angle: 0,
                translate: Vec3(obj.position, obj.zOrder))
            scratchUniform.color = wire.color
            scratchUniform.params = Vec4(shapeParam, wire.thickness, 0, 0)
            scratchUniform.setBuffer(buffer: contents, offsetIndex: drawCount)
            drawCount += 1
        }
    }

    public func flush(pass: RenderPass) {
        guard drawCount > 0 else { return }
        pass.encoder.drawPrimitives(
            type: .triangleStrip, vertexStart: 0,
            vertexCount: 4, instanceCount: drawCount)
        drawCount = 0
    }

    public nonisolated func signalFrameComplete() {
        bufferProvider.signal()
    }
}
