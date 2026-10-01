//
//  RenderCore.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import QuartzCore
import Metal

@MainActor
public class RenderCore {

    public let view: PlatformView
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let layer: CAMetalLayer

    let textureManager: TextureManager

    var viewport = MTLViewport(originX: 0, originY: 0, width: 0, height: 0, znear: 0, zfar: 1)

    public let perspective = PerspectiveProjection()
    public let orthographic = OrthographicProjection()
    public let camera2D = Camera2D()
    public var clearColor: MTLClearColor = MTLClearColor()

    public init(parentView: PlatformView) {
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
        #if canImport(UIKit)
        let hostLayer: CALayer = view.layer
        #elseif canImport(AppKit)
        view.wantsLayer = true
        guard let hostLayer = view.layer else {
            fatalError("RenderCore: NSView has no backing layer after wantsLayer = true")
        }
        #endif
        layer.frame           = hostLayer.frame
        hostLayer.addSublayer(layer)

        textureManager = TextureManager(device: device, commandQueue: commandQueue)
    }

    public func resize(scale: CGFloat, layerSize: CGSize) {
        #if canImport(UIKit)
        view.contentScaleFactor = scale
        #elseif canImport(AppKit)
        layer.contentsScale     = scale
        #endif
        // A hand-added sublayer animates frame changes by default; during a
        // live window resize that would leave the picture trailing the edge.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame             = CGRect(x: 0, y: 0, width: layerSize.width, height: layerSize.height)
        layer.drawableSize      = CGSize(width: layerSize.width * scale, height: layerSize.height * scale)
        CATransaction.commit()

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
        let shaderSource = Self.shaderSource(resource: resource, withExtension: ext)
        do {
            return try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            fatalError("Failed to compile shader library \(resource): \(error)")
        }
    }

    /// The text of a bundled shader. Tests compile it with test kernels added.
    static func shaderSource(resource: String, withExtension ext: String) -> String {
        guard let shaderURL = Bundle.module.url(forResource: resource, withExtension: ext) else {
            fatalError("Failed to find \(resource).\(ext) in bundle")
        }
        do {
            return try String(contentsOf: shaderURL, encoding: .utf8)
        } catch {
            fatalError("Failed to read \(resource).\(ext): \(error)")
        }
    }

    public func createQuad() -> MTLBuffer {
        let vertexData: [Float] = [
            -0.5, -0.5, 0.0, 0.0, 1.0,
             0.5, -0.5, 0.0, 1.0, 1.0,
             -0.5, 0.5, 0.0, 0.0, 0.0,
             0.5, 0.5, 0.0, 1.0, 0.0
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
