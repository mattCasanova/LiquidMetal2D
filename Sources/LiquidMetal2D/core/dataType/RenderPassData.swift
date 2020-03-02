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
class RenderPassData {
    let commandBuffer: MTLCommandBuffer!
    let drawable: CAMetalDrawable!
    let descriptor: MTLRenderPassDescriptor!
    let encoder: MTLRenderCommandEncoder!
    
    init(layer: CAMetalLayer, commandQueue: MTLCommandQueue, clearColor: MTLClearColor) {
        drawable      = layer.nextDrawable()
        descriptor    = RenderPassData.createRenderPassDescriptor(drawable: drawable, clearColor: clearColor)
        commandBuffer = commandQueue.makeCommandBuffer()
        encoder       = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
    }
    
    func endPass() {
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private static func createRenderPassDescriptor(drawable: CAMetalDrawable, clearColor: MTLClearColor) -> MTLRenderPassDescriptor? {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture     = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction  = .clear
        renderPassDescriptor.colorAttachments[0].clearColor  = clearColor
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        return renderPassDescriptor
    }
    
}
