//
//  RenderPassData.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
import Metal

@available(iOS 13.0, *)
public class RenderPassData {
    public let commandBuffer: MTLCommandBuffer!
    public let drawable: CAMetalDrawable!
    public let descriptor: MTLRenderPassDescriptor!
    public let encoder: MTLRenderCommandEncoder!
    
  public init(layer: CAMetalLayer, commandQueue: MTLCommandQueue, clearColor: MTLClearColor, depthTexture: MTLTexture?) {
        drawable      = layer.nextDrawable()
        descriptor    = RenderPassData.createRenderPassDescriptor(drawable: drawable, clearColor: clearColor, depthTexture: depthTexture)
        commandBuffer = commandQueue.makeCommandBuffer()
        encoder       = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
    }
    
    public func endPass() {
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
  private static func createRenderPassDescriptor(drawable: CAMetalDrawable, clearColor: MTLClearColor, depthTexture: MTLTexture?) -> MTLRenderPassDescriptor? {
        let renderPassDescriptor = MTLRenderPassDescriptor()
    
    if let depthTexture = depthTexture {
      renderPassDescriptor.depthAttachment.texture = depthTexture
      
      renderPassDescriptor.depthAttachment.storeAction = .dontCare
      renderPassDescriptor.depthAttachment.clearDepth = 1.0
      //renderPassDescriptor.stencilAttachment.texture = depthTexture
    }
    
    
    renderPassDescriptor.colorAttachments[0].texture     = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction  = .clear
        renderPassDescriptor.colorAttachments[0].clearColor  = clearColor
        renderPassDescriptor.colorAttachments[0].storeAction = .store
    

  
        return renderPassDescriptor
    }
    
}
