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
public class RenderCore {
  
  public let device: MTLDevice
  public let commandQueue: MTLCommandQueue
  public let layer: CAMetalLayer

  public let alphaBlendPipelineState: MTLRenderPipelineState
  public let view: UIView
  
  var viewPort: Array<Int32> = [0, 0, 0, 0]
  
  
  private var textures = [Texture]()
  private var texturesMap = [Int : Texture]()
  
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
      vertexName: "basic_vertex",
      fragmentName: "basic_fragment")
  }
  
  public func resize(scale: CGFloat, layerSize: CGSize) {
    view.contentScaleFactor = scale
    layer.frame             = CGRect(x: 0, y: 0, width: layerSize.width, height: layerSize.height)
    layer.drawableSize      = CGSize(width: layerSize.width * scale, height: layerSize.height * scale)
    
    viewPort[0] = 0
    viewPort[1] = 0
    viewPort[2] = Int32(layerSize.width)
    viewPort[3] = Int32(layerSize.height)
  }
  
  public func setClearColor(clearColor: Vector3D) {
    self.clearColor = MTLClearColor(red: Double(clearColor.r), green: Double(clearColor.g), blue: Double(clearColor.b), alpha: 1.0)
  }
  
  public func createDefaultSampler() -> MTLSamplerState? {
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
    return device.makeSamplerState(descriptor: sampler)
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
  
  public func loadTexture(name: String, ext: String, isMipmaped: Bool, shouldFlip: Bool) -> Int {
    
    let fileName = "\(name).\(ext)".lowercased()
    let foundTexture = textures.first(where: { $0.fileName == fileName })
    
    if let safeTexture = foundTexture {
      safeTexture.loadCount += 1
      return safeTexture.id
    }
    
    let newTexture = Texture(name: name, ext: ext, isMipmaped: isMipmaped)
    
    //TODO Error checking to make sure texture exists
    newTexture.loadTexture(device: device, commandQueue: commandQueue, flip: shouldFlip)
    
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
}
