//
//  WireframePipeline.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Metal

@MainActor
enum WireframePipeline {

    static let vertexBufferIndex = 0
    static let projectionBufferIndex = 1
    static let worldBufferIndex = 2

    static func create(renderCore: RenderCore) -> MTLRenderPipelineState {
        let library = renderCore.loadShaderLibrary(
            resource: "WireframeShader", withExtension: "metalSource")

        guard let vertexProgram = library.makeFunction(name: "wireframe_vertex") else {
            fatalError("Failed to find vertex function 'wireframe_vertex'")
        }
        guard let fragmentProgram = library.makeFunction(name: "wireframe_fragment") else {
            fatalError("Failed to find fragment function 'wireframe_fragment'")
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

        let descriptor                             = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction                  = vertexProgram
        descriptor.fragmentFunction                = fragmentProgram
        descriptor.vertexDescriptor                = vertexDescriptor
        descriptor.colorAttachments[0].pixelFormat = renderCore.layer.pixelFormat

        // Alpha blending so the outline composites over the sprite behind it.
        let colorDescriptor                          = descriptor.colorAttachments[0]
        colorDescriptor?.isBlendingEnabled           = true
        colorDescriptor?.rgbBlendOperation           = .add
        colorDescriptor?.alphaBlendOperation         = .add
        colorDescriptor?.sourceRGBBlendFactor        = .sourceAlpha
        colorDescriptor?.sourceAlphaBlendFactor      = .sourceAlpha
        colorDescriptor?.destinationRGBBlendFactor   = .oneMinusSourceAlpha
        colorDescriptor?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            return try renderCore.device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create wireframe pipeline state: \(error)")
        }
    }
}
