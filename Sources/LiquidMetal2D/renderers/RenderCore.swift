//
//  RenderCore.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
import Metal

@MainActor
public class RenderCore {

    private var textures = [Texture]()
    private var texturesMap = [Int: Texture]()

    public let view: UIView
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let layer: CAMetalLayer

    public let alphaBlendPipelineState: MTLRenderPipelineState

    var viewport = MTLViewport(originX: 0, originY: 0, width: 0, height: 0, znear: 0, zfar: 1)

    public let perspective = PerspectiveProjection()
    public let camera2D = Camera2D()
    public var clearColor: MTLClearColor = MTLClearColor()

    public init(parentView: UIView) {
        view = parentView
        guard let safeDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to Create Metal Device")
        }

        guard let safeQueue = safeDevice.makeCommandQueue() else {
            fatalError("Unable to make command queue")
        }

        device                = safeDevice
        commandQueue          = safeQueue

        layer                 = CAMetalLayer()
        layer.device          = device
        layer.pixelFormat     = .bgra8Unorm
        layer.framebufferOnly = true
        layer.frame           = view.layer.frame
        view.layer.addSublayer(layer)

        alphaBlendPipelineState = RenderCore.createPipelineState(
            device: device,
            layer: layer,
            vertexName: "alphaBlend_vertex",
            fragmentName: "alphaBlend_fragment")
    }

    public func resize(scale: CGFloat, layerSize: CGSize) {
        view.contentScaleFactor = scale
        layer.frame             = CGRect(x: 0, y: 0, width: layerSize.width, height: layerSize.height)
        layer.drawableSize      = CGSize(width: layerSize.width * scale, height: layerSize.height * scale)

        viewport = MTLViewport(
            originX: 0, originY: 0,
            width: Double(layer.drawableSize.width),
            height: Double(layer.drawableSize.height),
            znear: 0, zfar: 1)
    }

    public func setClearColor(color: Vec3) {
        self.clearColor = MTLClearColor(red: Double(color.r), green: Double(color.g), blue: Double(color.b), alpha: 1.0)
    }

    public func createDefaultSampler() -> MTLSamplerState? {
        let sampler = MTLSamplerDescriptor()
        sampler.minFilter             = MTLSamplerMinMagFilter.nearest
        sampler.magFilter             = MTLSamplerMinMagFilter.nearest
        sampler.mipFilter             = MTLSamplerMipFilter.nearest
        sampler.maxAnisotropy         = 1
        sampler.sAddressMode          = MTLSamplerAddressMode.repeat
        sampler.tAddressMode          = MTLSamplerAddressMode.repeat
        sampler.rAddressMode          = MTLSamplerAddressMode.repeat
        sampler.normalizedCoordinates = true
        sampler.lodMinClamp           = 0
        sampler.lodMaxClamp           = .greatestFiniteMagnitude
        return device.makeSamplerState(descriptor: sampler)
    }

    private static func loadShaderLibrary(device: MTLDevice) -> MTLLibrary {
        guard let shaderURL = Bundle.module.url(
            forResource: "AlphaBlendShader", withExtension: "metalSource"
        ) else {
            fatalError("Failed to find AlphaBlendShader.metalSource in bundle")
        }

        let shaderSource: String
        do {
            shaderSource = try String(contentsOf: shaderURL)
        } catch {
            fatalError("Failed to read AlphaBlendShader.metalSource: \(error)")
        }

        do {
            return try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            fatalError("Failed to compile Metal shader library: \(error)")
        }
    }

    private static func createPipelineState(
        device: MTLDevice, layer: CAMetalLayer, vertexName: String, fragmentName: String
    ) -> MTLRenderPipelineState {
        let defaultLibrary = loadShaderLibrary(device: device)

        guard let fragmentProgram = defaultLibrary.makeFunction(name: fragmentName) else {
            fatalError("Failed to find fragment function '\(fragmentName)'")
        }
        guard let vertexProgram = defaultLibrary.makeFunction(name: vertexName) else {
            fatalError("Failed to find vertex function '\(vertexName)'")
        }

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 5
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        let pipelineStateDescriptor                             = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction                  = vertexProgram
        pipelineStateDescriptor.fragmentFunction                = fragmentProgram
        pipelineStateDescriptor.vertexDescriptor                = vertexDescriptor
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = layer.pixelFormat

        // Alpha Blending
        let colorDescriptor                          = pipelineStateDescriptor.colorAttachments[0]
        colorDescriptor?.isBlendingEnabled           = true
        colorDescriptor?.rgbBlendOperation           = .add
        colorDescriptor?.alphaBlendOperation         = .add

        colorDescriptor?.sourceRGBBlendFactor        = .sourceAlpha
        colorDescriptor?.sourceAlphaBlendFactor      = .sourceAlpha

        colorDescriptor?.destinationRGBBlendFactor   = .oneMinusSourceAlpha
        colorDescriptor?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch {
            fatalError("Failed to create render pipeline state: \(error)")
        }
    }

    public func loadTexture(name: String, ext: String, isMipmaped: Bool) -> Int {

        let fileName = "\(name).\(ext)".lowercased()
        let foundTexture = textures.first(where: { $0.fileName == fileName })

        if let safeTexture = foundTexture {
            safeTexture.loadCount += 1
            return safeTexture.id
        }

        let newTexture = Texture(name: name, ext: ext, isMipmaped: isMipmaped)

        newTexture.loadTexture(device: device, commandQueue: commandQueue)

        textures.append(newTexture)
        texturesMap[newTexture.id] = newTexture

        return newTexture.id
    }

    public func unloadTexture(textureId: Int) {
        guard let texture = texturesMap[textureId] else { return }

        texture.loadCount -= 1

        if texture.loadCount <= 0 {
            texturesMap[textureId] = nil
            textures.removeAll(where: { $0.id == textureId })
        }
    }

    public func getTexture(id: Int) -> Texture? {
        return texturesMap[id]
    }

    public func getUnprojectRay(forScreenPoint point: Vec2) -> UnprojectRay {
        let near = unproject(screenPoint: Vec3(point.x, point.y, 0))
        let far = unproject(screenPoint: Vec3(point.x, point.y, 1))

        let zMag = abs(far.z - near.z)
        let nearFactor = abs(near.z) / zMag
        let farFactor = abs(far.z) / zMag

        let origin = (near * farFactor) + (far * nearFactor)
        let vector = (near - far) / zMag

        return UnprojectRay(origin: origin, vector: vector)
    }

    public func unproject(screenPoint: Vec3) -> Vec3 {
        let viewX = Float(view.frame.origin.x)
        let viewY = Float(view.frame.origin.y)
        let width = Float(view.bounds.width)
        let height = Float(view.bounds.height)

        let clipPoint = Vec4(
            2 * (screenPoint.x - viewX) / width - 1,
            2 * (screenPoint.y - viewY) / height - 1,
            2 * screenPoint.z - 1,
            1
        )

        var worldPoint = (perspective.make() * camera2D.make()).inverse * clipPoint
        worldPoint.w = 1 / worldPoint.w

        return Vec3(
            worldPoint.x * worldPoint.w,
            worldPoint.y * worldPoint.w * -1,
            worldPoint.z * worldPoint.w
        )
    }

    public func project(worldPoint: Vec3) -> Vec3 {
        var clipPoint = perspective.make() * camera2D.make() * worldPoint.to4D(1)
        clipPoint.w = 1 / clipPoint.w

        // Perspective Division
        clipPoint.x *= clipPoint.w
        clipPoint.y *= clipPoint.w
        clipPoint.z *= clipPoint.w

        let viewX = Float(view.frame.origin.x)
        let viewY = Float(view.frame.origin.y)
        let width = Float(view.bounds.width)
        let height = Float(view.bounds.height)

        return Vec3(
            (clipPoint.x * 0.5 + 0.5) * width + viewX,
            (clipPoint.y * 0.5 + 0.5) * height + viewY,
            (1.0 + clipPoint.z) * 0.5 // Between 0 and 1
        )
    }
}
