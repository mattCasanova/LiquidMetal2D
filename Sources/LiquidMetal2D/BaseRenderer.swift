//
//  BaseRenderer.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//


import UIKit
import Metal
import MetalMath

@available(iOS 13.0, *)
class BaseRenderer {
    let device: MTLDevice!
    let layer: CAMetalLayer!
    let commandQueue: MTLCommandQueue!
    let view: UIView
    
    var clearColor: MTLClearColor = MTLClearColor()
    
    init(parentView: UIView) {
        view = parentView
        
        device                = MTLCreateSystemDefaultDevice()!
        commandQueue          = device.makeCommandQueue()
        
        layer                 = CAMetalLayer()
        layer.device          = device
        layer.pixelFormat     = .bgra8Unorm
        layer.framebufferOnly = true
        layer.frame           = view.layer.frame
        view.layer.addSublayer(layer)
    }
    
    func resize(scale: CGFloat, layerSize: CGSize) {
        view.contentScaleFactor = scale
        layer.frame             = CGRect(x: 0, y: 0, width: layerSize.width, height: layerSize.height)
        layer.drawableSize      = CGSize(width: layerSize.width * scale, height: layerSize.height * scale)
    }
        
    func setClearColor(clearColor: Vector3D) {
        self.clearColor = MTLClearColor(red: Double(clearColor.r), green: Double(clearColor.g), blue: Double(clearColor.b), alpha: 1.0)
    }
    
    func createDefaultSampler(device: MTLDevice) -> MTLSamplerState {
      let sampler = MTLSamplerDescriptor()
      sampler.minFilter             = MTLSamplerMinMagFilter.nearest
      sampler.magFilter             = MTLSamplerMinMagFilter.nearest
      sampler.mipFilter             = MTLSamplerMipFilter.nearest
      sampler.maxAnisotropy         = 1
      sampler.sAddressMode          = MTLSamplerAddressMode.clampToEdge
      sampler.tAddressMode          = MTLSamplerAddressMode.clampToEdge
      sampler.rAddressMode          = MTLSamplerAddressMode.clampToEdge
      sampler.normalizedCoordinates = true
      sampler.lodMinClamp           = 0
      sampler.lodMaxClamp           = .greatestFiniteMagnitude
      return device.makeSamplerState(descriptor: sampler)!
    }
}
