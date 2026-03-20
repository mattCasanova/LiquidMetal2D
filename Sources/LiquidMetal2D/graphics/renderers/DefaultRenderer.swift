//
//  DefaultRenderer.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/24/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
import Metal

@MainActor
open class DefaultRenderer: Renderer {

    public let renderCore: RenderCore
    private var renderPass: AlphaBlendRenderPass!

    public var screenHeight: Float = 0
    public var screenWidth: Float = 0
    public var screenAspect: Float = 0

    public var drawCount: Int = 0
    public var maxObjects: Int = 0

    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer

    private let projectionUniforms = ProjectionUniform()
    private var projectionBuffer: MTLBuffer!
    private let projectionBufferProvider: BufferProvider

    private let worldBufferProvider: BufferProvider
    private var worldBufferContents: UnsafeMutableRawPointer!

    private var samplerState: MTLSamplerState

    public var view: UIView { renderCore.view }

    public init(parentView: UIView, maxObjects: Int, uniformSize: Int) {
        renderCore = RenderCore(parentView: parentView)

        pipelineState = AlphaBlendPipeline.create(renderCore: renderCore)
        vertexBuffer = renderCore.createQuad()

        guard let samplerState = renderCore.createDefaultSampler() else {
            fatalError("Unable to create sampler state.")
        }

        self.maxObjects          = maxObjects
        self.samplerState        = samplerState
        projectionBufferProvider = BufferProvider(device: renderCore.device, size: projectionUniforms.size)
        worldBufferProvider      = BufferProvider(device: renderCore.device, size: uniformSize * maxObjects)
    }

    public func setPerspective(fov: Float, aspect: Float, nearZ: Float, farZ: Float) {
        renderCore.perspective.set(aspect: aspect, fov: fov, nearZ: nearZ, farZ: farZ)
    }

    public func setOrthographic(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) {
        renderCore.orthographic.set(left: left, right: right, bottom: bottom, top: top, nearZ: nearZ, farZ: farZ)
    }

    public func setCamera(point: Vec3) {
        renderCore.camera2D.set(point: point)
    }

    /// Sets the camera's Z-axis rotation in radians.
    public func setCameraRotation(angle: Float) {
        renderCore.camera2D.rotation = angle
    }

    public func setClearColor(color: Vec3) {
        renderCore.setClearColor(color: color)
    }

    public func resize(scale: CGFloat, layerSize: CGSize) {
        renderCore.resize(scale: scale, layerSize: layerSize)

        screenWidth  = Float(renderCore.layer.drawableSize.width)
        screenHeight = Float(renderCore.layer.drawableSize.height)
        screenAspect = screenWidth / screenHeight
    }

    public var defaultTextureId: Int { renderCore.textureManager.defaultTextureId }

    public func loadTextures(
        _ items: [(name: String, ext: String, isMipmaped: Bool)],
        completion: (() -> Void)? = nil
    ) -> [Int] {
        return renderCore.textureManager.loadTextures(items, completion: completion)
    }

    public func unloadTexture(textureId: Int) {
        renderCore.textureManager.unloadTexture(textureId: textureId)
    }

    public func shutdown() {
        renderCore.shutdown()
    }

    public func unloadAllTextures() {
        renderCore.textureManager.unloadAllTextures()
    }

    private var projectionMatrix: Mat4 { renderCore.perspective.make() }
    private var viewMatrix: Mat4 { renderCore.camera2D.make() }
    private var viewFrame: CGRect { renderCore.view.frame }
    private var viewBounds: CGRect { renderCore.view.bounds }

    public func project(world: Vec3) -> Vec3 {
        return Projection.project(
            worldPoint: world, projection: projectionMatrix,
            viewMatrix: viewMatrix, viewFrame: viewFrame, viewBounds: viewBounds)
    }

    public func unproject(screen: Vec2, forWorldZ worldZ: Float) -> Vec3 {
        return unproject(screenWithWorldZ: screen.to3D(worldZ))
    }

    public func unproject(screenWithWorldZ: Vec3) -> Vec3 {
        let projected = Projection.project(
            worldPoint: Vec3(0, 0, screenWithWorldZ.z), projection: projectionMatrix,
            viewMatrix: viewMatrix, viewFrame: viewFrame, viewBounds: viewBounds)
        var unprojected = Projection.unproject(
            screenPoint: Vec3(screenWithWorldZ.x, screenWithWorldZ.y, projected.z),
            projection: projectionMatrix, viewMatrix: viewMatrix,
            viewFrame: viewFrame, viewBounds: viewBounds)

        unprojected.z = screenWithWorldZ.z
        return unprojected
    }

    public func getUnprojectRay(forScreenPoint point: Vec2) -> UnprojectRay {
        return Projection.unprojectRay(
            screenPoint: point, projection: projectionMatrix,
            viewMatrix: viewMatrix, viewFrame: viewFrame, viewBounds: viewBounds)
    }

    public func getWorldBoundsFromCamera(zOrder: Float) -> WorldBounds {
        return getWorldBounds(cameraDistance: renderCore.camera2D.distance, zOrder: zOrder)
    }

    public func getWorldBounds(cameraDistance: Float, zOrder: Float) -> WorldBounds {
        let angle = 0.5 * renderCore.perspective.fov
        let maxY = tan(angle) * (cameraDistance - zOrder)
        let maxX = maxY * screenAspect

        return WorldBounds(minX: -maxX, maxX: maxX, minY: -maxY, maxY: maxY)
    }

    // MARK: - Batch Tracking

    public struct TextureBatch {
        public let textureId: Int
        public let startIndex: Int
        public var count: Int
    }

    public var currentTextureId: Int = -1
    public var batches: [TextureBatch] = []
    public let worldUniforms = WorldUniform()

    // MARK: - Draw Methods

    open func usePerspective() {
        let contents = projectionBuffer.contents()
        projectionUniforms.transform = renderCore.perspective.make() * renderCore.camera2D.make()
        projectionUniforms.setBuffer(buffer: contents, offsetIndex: 0)
        renderPass.setProjection(buffer: projectionBuffer)
    }

    open func useOrthographic() {
        let contents = projectionBuffer.contents()
        projectionUniforms.transform = renderCore.orthographic.make()
        projectionUniforms.setBuffer(buffer: contents, offsetIndex: 0)
        renderPass.setProjection(buffer: projectionBuffer)
    }

    open func submit(objects: [GameObj]) {
        let sorted = objects.lazy
            .filter { $0.isActive }
            .sorted { ($0.zOrder, $0.textureID) < ($1.zOrder, $1.textureID) }

        for obj in sorted {
            assert(drawCount < maxObjects, "Draw count \(drawCount) exceeds maxObjects \(maxObjects)")
            guard drawCount < maxObjects else { break }

            obj.toUniform(worldUniforms)
            worldUniforms.setBuffer(buffer: worldBufferContents, offsetIndex: drawCount)

            if let last = batches.last, last.textureId == obj.textureID {
                batches[batches.count - 1].count += 1
            } else {
                batches.append(TextureBatch(
                    textureId: obj.textureID, startIndex: drawCount, count: 1))
            }
            drawCount += 1
        }
    }

    // MARK: - Advanced Draw Methods (manual control)
    //
    // Unlike submit(objects:), these methods do NOT sort by zOrder or textureID.
    // Objects render in the order you call draw(). If you need correct depth
    // ordering, sort your objects before the draw loop. Consecutive calls with
    // the same texture will batch into one instanced draw call; interleaved
    // textures produce more draw calls.

    public func useTexture(textureId: Int) {
        currentTextureId = textureId
    }

    open func draw(uniforms: UniformData) {
        assert(drawCount < maxObjects, "Draw count \(drawCount) exceeds maxObjects \(maxObjects)")
        guard drawCount < maxObjects else { return }

        uniforms.setBuffer(buffer: worldBufferContents, offsetIndex: drawCount)

        if let last = batches.last, last.textureId == currentTextureId {
            batches[batches.count - 1].count += 1
        } else {
            batches.append(TextureBatch(
                textureId: currentTextureId, startIndex: drawCount, count: 1))
        }
        drawCount += 1
    }

    // MARK: - Pass Management

    open func beginPass() -> Bool {
        guard projectionBufferProvider.wait(),
              worldBufferProvider.wait() else {
            return false
        }

        guard let pass = AlphaBlendRenderPass(renderCore: renderCore) else {
            projectionBufferProvider.signal()
            worldBufferProvider.signal()
            return false
        }

        renderPass = pass
        projectionBuffer = projectionBufferProvider.nextBuffer()

        let projProvider = projectionBufferProvider
        let worldProvider = worldBufferProvider
        renderPass.addCompletedHandler { (_) in
            projProvider.signal()
            worldProvider.signal()
        }

        let worldBuffer = worldBufferProvider.nextBuffer()
        worldBufferContents = worldBuffer.contents()

        renderPass.setup(
            pipelineState: pipelineState,
            vertexBuffer: vertexBuffer,
            samplerState: samplerState,
            worldBuffer: worldBuffer)

        drawCount = 0
        return true
    }

    open func endPass() {
        renderPass.drawBatches(batches)
        renderPass.end()
        renderPass = nil
        drawCount = 0
        batches.removeAll(keepingCapacity: true)
        currentTextureId = -1
    }

}
