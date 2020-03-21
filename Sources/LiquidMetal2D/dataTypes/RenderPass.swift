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
public class RenderPass {
  private let commandBuffer: MTLCommandBuffer
  private let drawable: CAMetalDrawable!
  private let descriptor: MTLRenderPassDescriptor!
  public let encoder: MTLRenderCommandEncoder!
  
  public init(layer: CAMetalLayer, commandQueue: MTLCommandQueue, clearColor: MTLClearColor) {
    
    guard let safeDrawable = layer.nextDrawable(),
      let safeBuffer = commandQueue.makeCommandBuffer(),
      let safeDescriptor = RenderPass.createDescriptor(drawable: safeDrawable, clearColor: clearColor),
      let safeEncoder = safeBuffer.makeRenderCommandEncoder(descriptor: safeDescriptor)
    else {
      fatalError("Unable to start render pass")
    }
    
    drawable      = safeDrawable
    commandBuffer = safeBuffer
    descriptor    = safeDescriptor
    encoder       = safeEncoder
  }
  
  public func end() {
    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
  
  func addCompletedHandler(_ block: @escaping MTLCommandBufferHandler) {
    commandBuffer.addCompletedHandler(block)
  }
  
  private static func createDescriptor(drawable: CAMetalDrawable, clearColor: MTLClearColor) -> MTLRenderPassDescriptor? {
    let descriptor = MTLRenderPassDescriptor()
    
    descriptor.colorAttachments[0].texture     = drawable.texture
    descriptor.colorAttachments[0].loadAction  = .clear
    descriptor.colorAttachments[0].clearColor  = clearColor
    descriptor.colorAttachments[0].storeAction = .store
    
    return descriptor
  }
  
}
