//
//  RenderPass.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
import Metal

@MainActor
open class RenderPass {
    private let commandBuffer: MTLCommandBuffer
    private let drawable: CAMetalDrawable
    public let encoder: MTLRenderCommandEncoder
    public let renderCore: RenderCore

    public init?(renderCore: RenderCore) {
        self.renderCore = renderCore

        guard let safeDrawable = renderCore.layer.nextDrawable(),
            let safeBuffer = renderCore.commandQueue.makeCommandBuffer(),
            let safeDescriptor = RenderPass.createDescriptor(drawable: safeDrawable, clearColor: renderCore.clearColor),
            let safeEncoder = safeBuffer.makeRenderCommandEncoder(descriptor: safeDescriptor)
        else {
            return nil
        }

        drawable      = safeDrawable
        commandBuffer = safeBuffer
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

    open class func createDescriptor(
        drawable: CAMetalDrawable, clearColor: MTLClearColor
    ) -> MTLRenderPassDescriptor? {
        let descriptor = MTLRenderPassDescriptor()

        descriptor.colorAttachments[0].texture     = drawable.texture
        descriptor.colorAttachments[0].loadAction  = .clear
        descriptor.colorAttachments[0].clearColor  = clearColor
        descriptor.colorAttachments[0].storeAction = .store

        return descriptor
    }
}
