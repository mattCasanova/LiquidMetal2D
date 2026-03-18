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
public class DefaultRenderer: Renderer {

    private let renderCore: RenderCore
    private var renderPass: RenderPass!

    public var screenHeight: Float = 0
    public var screenWidth: Float = 0
    public var screenAspect: Float = 0

    private var drawCount: Int = 0
    private var maxObjects: Int = 0

    private let vertexBuffer: MTLBuffer

    private let projectionUniforms = ProjectionUniform()
    private var projectionBuffer: MTLBuffer!
    private let projectionBufferProvider: BufferProvider

    private let worldBufferProvider: BufferProvider
    private var worldBufferContents: UnsafeMutableRawPointer!

    private var samplerState: MTLSamplerState

    public var view: UIView { renderCore.view }

    public init(parentView: UIView, maxObjects: Int, uniformSize: Int) {
        renderCore = RenderCore.init(parentView: parentView)

        guard let vertexBuffer = DefaultRenderer.createVertBuffer(device: renderCore.device),
            let samplerState = renderCore.createDefaultSampler()
        else {
            fatalError("Unable to create renderer.")
        }

        self.maxObjects          = maxObjects
        self.vertexBuffer        = vertexBuffer
        self.samplerState        = samplerState
        projectionBufferProvider = BufferProvider(device: renderCore.device, size: projectionUniforms.size)
        worldBufferProvider      = BufferProvider(device: renderCore.device, size: uniformSize * maxObjects)
    }

    public func setPerspective(fov: Float, aspect: Float, nearZ: Float, farZ: Float) {
        renderCore.perspective.set(aspect: aspect, fov: fov, nearZ: nearZ, farZ: farZ)
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

    public func loadTexture(name: String, ext: String, isMipmaped: Bool) -> Int {
        return renderCore.loadTexture(name: name, ext: ext, isMipmaped: isMipmaped)
    }

    public func unloadTexture(textureId: Int) {
        renderCore.unloadTexture(textureId: textureId)
    }

    public func project(world: Vec3) -> Vec3 {
        return renderCore.project(worldPoint: world)
    }

    public func unproject(screen: Vec2, forWorldZ worldZ: Float) -> Vec3 {
        return unproject(screenWithWorldZ: screen.to3D(worldZ))
    }

    public func unproject(screenWithWorldZ: Vec3) -> Vec3 {
        let projected = renderCore.project(worldPoint: Vec3(0, 0, screenWithWorldZ.z))
        var unprojected = renderCore.unproject(
            screenPoint: Vec3(screenWithWorldZ.x, screenWithWorldZ.y, projected.z))

        unprojected.z = screenWithWorldZ.z
        return unprojected
    }

    public func getUnprojectRay(forScreenPoint point: Vec2) -> UnprojectRay {
        return renderCore.getUnprojectRay(forScreenPoint: point)
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

    // MARK: - Draw Methods

    public func useTexture(textureId: Int) {
        guard let texture = renderCore.getTexture(id: textureId) else { return }
        renderPass.encoder.setFragmentTexture(texture.texture, index: 0)
    }

    public func usePerspective() {
        let contents = projectionBuffer.contents()
        projectionUniforms.transform = renderCore.perspective.make() * renderCore.camera2D.make()
        projectionUniforms.setBuffer(buffer: contents, offsetIndex: 0)
        renderPass.encoder.setVertexBuffer(projectionBuffer, offset: 0, index: 1)
    }

    public func useOrthographic() {
    }

    @discardableResult
    public func beginPass() -> Bool {
        guard projectionBufferProvider.wait(),
              worldBufferProvider.wait() else {
            return false
        }

        renderPass = RenderPass(
            layer: renderCore.layer,
            commandQueue: renderCore.commandQueue,
            clearColor: renderCore.clearColor)

        projectionBuffer = projectionBufferProvider.nextBuffer()

        let projProvider = projectionBufferProvider
        let worldProvider = worldBufferProvider
        renderPass.addCompletedHandler { (_) in
            projProvider.signal()
            worldProvider.signal()
        }

        renderPass.encoder.setViewport(renderCore.viewport)
        renderPass.encoder.setRenderPipelineState(renderCore.alphaBlendPipelineState)
        renderPass.encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderPass.encoder.setFragmentSamplerState(samplerState, index: 0)

        let worldBuffer = worldBufferProvider.nextBuffer()
        worldBufferContents = worldBuffer.contents()
        renderPass.encoder.setVertexBuffer(worldBuffer, offset: 0, index: 2)
        drawCount = 0
        return true
    }

    public func draw(uniforms: UniformData) {
        assert(drawCount < maxObjects, "Draw count \(drawCount) exceeds maxObjects \(maxObjects)")
        guard drawCount < maxObjects else { return }

        let offset = uniforms.size * drawCount

        uniforms.setBuffer(buffer: worldBufferContents, offsetIndex: drawCount)
        renderPass.encoder.setVertexBufferOffset(offset, index: 2)
        renderPass.encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)

        drawCount += 1
    }

    public func endPass() {
        renderPass.end()
        renderPass = nil
        drawCount = 0
    }

    private static func createVertBuffer(device: MTLDevice) -> MTLBuffer? {
        let vertexData: [Float] = [
            -0.5, -0.5, 0.0, 0.0, 1.0,
            0.5, -0.5, 0.0, 1.0, 1.0,
            -0.5, 0.5, 0.0, 0.0, 0.0,
            0.5, 0.5, 0.0, 1.0, 0.0
        ]

        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        return device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
    }
}
