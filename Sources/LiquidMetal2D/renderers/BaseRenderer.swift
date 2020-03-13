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
public class BaseRenderer {
  public let device: MTLDevice!
  public let layer: CAMetalLayer!
  public let commandQueue: MTLCommandQueue!
  public let alphaBlendPipelineState: MTLRenderPipelineState
  public let view: UIView
  
  var viewPort: Array<Int32> = [0, 0, 0, 0]
  
  public var clearColor: MTLClearColor = MTLClearColor()
  
  public init(parentView: UIView) {
    view = parentView
    
    device                = MTLCreateSystemDefaultDevice()!
    commandQueue          = device.makeCommandQueue()
    
    layer                 = CAMetalLayer()
    layer.device          = device
    layer.pixelFormat     = .bgra8Unorm
    layer.framebufferOnly = true
    layer.frame           = view.layer.frame
    view.layer.addSublayer(layer)
    
    alphaBlendPipelineState = BaseRenderer.createPipelineState(
      device: device,
      layer: layer,
      vertexName: "basic_vertex",
      fragmentName: "basic_fragment")
  }
  
  public func resize(scale: CGFloat, layerSize: CGSize) {
    view.contentScaleFactor = scale
    layer.frame             = CGRect(x: 0, y: 0, width: layerSize.width, height: layerSize.height)
    layer.drawableSize      = CGSize(width: layerSize.width * scale, height: layerSize.height * scale)
    
    viewPort[0] = 0                               //bottom left x
    viewPort[1] = 0//Int32(layerSize.height)  //bottom left y
    viewPort[2] = Int32(layerSize.width)  //width
    viewPort[3] = Int32(layerSize.height)  //height
  }
  
  public func setClearColor(clearColor: Vector3D) {
    self.clearColor = MTLClearColor(red: Double(clearColor.r), green: Double(clearColor.g), blue: Double(clearColor.b), alpha: 1.0)
  }
  
  public func createDefaultSampler(device: MTLDevice) -> MTLSamplerState {
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
  
  private static func createPipelineState(device: MTLDevice, layer: CAMetalLayer, vertexName: String, fragmentName: String) -> MTLRenderPipelineState {
    
    // TODO: Error Check
    let defaultLibrary                                      = try! device.makeLibrary(source: ShaderSources.alphaBlendShader, options: nil)//device.makeDefaultLibrary()!
    let fragmentProgram                                     = defaultLibrary.makeFunction(name: fragmentName)
    let vertexProgram                                       = defaultLibrary.makeFunction(name: vertexName)
    
    let pipelineStateDescriptor                             = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexFunction                  = vertexProgram
    pipelineStateDescriptor.fragmentFunction                = fragmentProgram
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = layer.pixelFormat
    
    
    //////////////////////// Alpha Blending
    let colorDescriptor                          = pipelineStateDescriptor.colorAttachments[0]
    colorDescriptor?.isBlendingEnabled           = true
    colorDescriptor?.rgbBlendOperation           = .add
    colorDescriptor?.alphaBlendOperation         = .add
    
    colorDescriptor?.sourceRGBBlendFactor        = .sourceAlpha
    colorDescriptor?.sourceAlphaBlendFactor      = .sourceAlpha
    
    colorDescriptor?.destinationRGBBlendFactor   = .oneMinusSourceAlpha
    colorDescriptor?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
    ////////////////////////
    
    // TODO Error Check
    return try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
  }
}
