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

    public let view: UIView
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let layer: CAMetalLayer

    let textureManager: TextureManager

    var viewport = MTLViewport(originX: 0, originY: 0, width: 0, height: 0, znear: 0, zfar: 1)

    public let perspective = PerspectiveProjection()
    public let orthographic = OrthographicProjection()
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

        textureManager = TextureManager(device: device, commandQueue: commandQueue)
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

    public func loadShaderLibrary(resource: String, withExtension ext: String) -> MTLLibrary {
        guard let shaderURL = Bundle.module.url(forResource: resource, withExtension: ext) else {
            fatalError("Failed to find \(resource).\(ext) in bundle")
        }

        let shaderSource: String
        do {
            shaderSource = try String(contentsOf: shaderURL, encoding: .utf8)
        } catch {
            fatalError("Failed to read \(resource).\(ext): \(error)")
        }

        do {
            return try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            fatalError("Failed to compile shader library \(resource): \(error)")
        }
    }

    public func createQuad() -> MTLBuffer {
        let vertexData: [Float] = [
            -0.5, -0.5, 0.0, 0.0, 1.0,
             0.5, -0.5, 0.0, 1.0, 1.0,
            -0.5,  0.5, 0.0, 0.0, 0.0,
             0.5,  0.5, 0.0, 1.0, 0.0
        ]

        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        guard let buffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: []) else {
            fatalError("Failed to create quad vertex buffer")
        }
        return buffer
    }

    /// Releases all dynamic GPU resources (textures). Called during
    /// renderer shutdown. Static resources (pipeline state, command queue,
    /// device) are released automatically when RenderCore is deallocated.
    public func shutdown() {
        textureManager.shutdown()
    }

}
