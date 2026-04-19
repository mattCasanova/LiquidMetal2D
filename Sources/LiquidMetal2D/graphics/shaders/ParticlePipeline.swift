//
//  ParticlePipeline.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Metal

@MainActor
enum ParticlePipeline {

    static let vertexBufferIndex = 0
    static let projectionBufferIndex = 1
    static let worldBufferIndex = 2
    static let textureIndex = 0
    static let samplerIndex = 0

    static func create(renderCore: RenderCore) -> MTLRenderPipelineState {
        let library = renderCore.loadShaderLibrary(
            resource: "ParticleShader", withExtension: "metalSource")

        guard let vertexProgram = library.makeFunction(name: "particle_vertex") else {
            fatalError("Failed to find vertex function 'particle_vertex'")
        }
        guard let fragmentProgram = library.makeFunction(name: "particle_fragment") else {
            fatalError("Failed to find fragment function 'particle_fragment'")
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

        // Additive blending: output is added to the framebuffer, weighted by
        // source alpha. Order-independent — no z-sort needed. Overlapping
        // particles brighten into hotspots.
        let colorDescriptor                          = descriptor.colorAttachments[0]
        colorDescriptor?.isBlendingEnabled           = true
        colorDescriptor?.rgbBlendOperation           = .add
        colorDescriptor?.alphaBlendOperation         = .add
        colorDescriptor?.sourceRGBBlendFactor        = .sourceAlpha
        colorDescriptor?.sourceAlphaBlendFactor      = .sourceAlpha
        colorDescriptor?.destinationRGBBlendFactor   = .one
        colorDescriptor?.destinationAlphaBlendFactor = .one

        do {
            return try renderCore.device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create particle pipeline state: \(error)")
        }
    }
}
