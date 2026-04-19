//
//  DefaultRenderer.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/24/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
import Metal

/// Wraps a value so it can cross actor isolation in a completion handler
/// without the compiler requiring `Sendable` conformance. Safe only when
/// the closure treats the captured value as read-only.
private struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

@MainActor
open class DefaultRenderer: Renderer {

    public let renderCore: RenderCore

    /// Built-in alpha-blend shader. Exposed so scenes can call
    /// ``AlphaBlendShader/draw(transform:texTrans:color:textureId:)`` for
    /// advanced manual rendering.
    public let alphaBlend: AlphaBlendShader

    public var screenHeight: Float = 0
    public var screenWidth: Float = 0
    public var screenAspect: Float = 0

    private let projectionUniforms = ProjectionUniform()
    private let projectionBufferProvider: BufferProvider
    private var projectionBuffer: MTLBuffer!

    private var currentPass: RenderPass?
    private var currentShader: Shader?

    /// All shaders whose per-frame lifecycle runs inside `beginPass`. The
    /// built-in alpha-blend shader is the first entry; custom shaders are
    /// appended via `register(shader:)`.
    private var shaders: [Shader]

    public var view: UIView { renderCore.view }

    public init(parentView: UIView, maxObjects: Int) {
        renderCore = RenderCore(parentView: parentView)
        projectionBufferProvider = BufferProvider(
            device: renderCore.device, size: projectionUniforms.size)
        alphaBlend = AlphaBlendShader(renderCore: renderCore, maxObjects: maxObjects)
        shaders = [alphaBlend]
    }

    public func register(shader: Shader) {
        guard !shaders.contains(where: { $0 === shader }) else { return }
        shaders.append(shader)
    }

    public func unregister(shader: Shader) {
        shaders.removeAll(where: { $0 === shader })
    }

    // MARK: - Projection / camera

    public func setPerspective(fov: Float, aspect: Float, nearZ: Float, farZ: Float) {
        renderCore.perspective.set(aspect: aspect, fov: fov, nearZ: nearZ, farZ: farZ)
    }

    // swiftlint:disable:next function_parameter_count
    public func setOrthographic(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) {
        renderCore.orthographic.set(left: left, right: right, bottom: bottom, top: top, nearZ: nearZ, farZ: farZ)
    }

    public func setCamera(point: Vec3) {
        renderCore.camera2D.set(point: point)
    }

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

    // MARK: - Textures

    public var defaultTextureId: Int { renderCore.textureManager.defaultTextureId }
    public var defaultParticleTextureId: Int { renderCore.textureManager.defaultParticleTextureId }

    public func loadTextures(
        _ items: [TextureDescriptor],
        completion: (() -> Void)? = nil
    ) -> [Int] {
        return renderCore.textureManager.loadTextures(items, completion: completion)
    }

    public func unloadTexture(textureId: Int) {
        renderCore.textureManager.unloadTexture(textureId: textureId)
    }

    public func unloadAllTextures() {
        renderCore.textureManager.unloadAllTextures()
    }

    public func shutdown() {
        renderCore.shutdown()
    }

    // MARK: - Projection helpers

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

    public func getVisibleBounds(zOrder: Float) -> WorldBounds {
        return getVisibleBounds(cameraDistance: renderCore.camera2D.distance, zOrder: zOrder)
    }

    public func getVisibleBounds(cameraDistance: Float, zOrder: Float) -> WorldBounds {
        let angle = 0.5 * renderCore.perspective.fov
        let maxY = tan(angle) * (cameraDistance - zOrder)
        let maxX = maxY * screenAspect

        return WorldBounds(minX: -maxX, maxX: maxX, minY: -maxY, maxY: maxY)
    }

    // MARK: - Pass lifecycle

    open func beginPass() -> Bool {
        guard projectionBufferProvider.wait() else { return false }

        // Acquire a frame buffer on each registered shader. If any shader
        // times out, signal back everything acquired so far and bail.
        var acquired = 0
        for shader in shaders {
            if shader.beginFrame() {
                acquired += 1
            } else {
                projectionBufferProvider.signal()
                for i in 0..<acquired { shaders[i].signalFrameComplete() }
                return false
            }
        }

        guard let pass = RenderPass(renderCore: renderCore) else {
            projectionBufferProvider.signal()
            for shader in shaders { shader.signalFrameComplete() }
            return false
        }

        let projProvider = projectionBufferProvider
        // Shader is @MainActor-isolated, so Array<Shader> isn't Sendable. The
        // only methods we call on each captured reference are nonisolated
        // (`signalFrameComplete` -> BufferProvider.signal()), which is safe.
        let capturedShaders = UncheckedSendable(shaders)
        pass.addCompletedHandler { _ in
            projProvider.signal()
            for shader in capturedShaders.value {
                shader.signalFrameComplete()
            }
        }

        projectionBuffer = projectionBufferProvider.nextBuffer()
        currentPass = pass
        currentShader = nil
        return true
    }

    open func usePerspective() {
        projectionUniforms.transform = renderCore.perspective.make() * renderCore.camera2D.make()
        projectionUniforms.setBuffer(buffer: projectionBuffer.contents(), offsetIndex: 0)
    }

    open func useOrthographic() {
        projectionUniforms.transform = renderCore.orthographic.make()
        projectionUniforms.setBuffer(buffer: projectionBuffer.contents(), offsetIndex: 0)
    }

    open func useShader(_ shader: Shader) {
        guard let pass = currentPass else { return }
        currentShader?.flush(pass: pass)
        shader.bind(pass: pass, projectionBuffer: projectionBuffer)
        currentShader = shader
    }

    open func submit(objects: [GameObj]) {
        if currentShader == nil { useShader(alphaBlend) }
        currentShader?.submit(objects: objects)
    }

    open func endPass() {
        guard let pass = currentPass else { return }
        currentShader?.flush(pass: pass)
        pass.end()
        currentPass = nil
        currentShader = nil
    }
}
