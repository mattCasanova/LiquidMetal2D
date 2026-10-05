//
//  LightPipeline.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/5/26.
//

import Metal

/// The pipelines a ``LightMap`` draws with: lights into its float texture,
/// then that texture multiplied over the scene.
@MainActor
enum LightPipeline {
    static let vertexBufferIndex = 0
    static let viewProjectionBufferIndex = 1
    static let lightsBufferIndex = 0
    static let pixelFormat = MTLPixelFormat.rgba16Float

    /// Lights add: overlapping pools brighten. The vertex function reads
    /// its buffer by vertex id, so no vertex descriptor.
    static func createLights(renderCore: RenderCore) -> MTLRenderPipelineState {
        let library = renderCore.loadShaderLibrary(resource: "LightShader", withExtension: "metalSource")
        guard let vertexProgram = library.makeFunction(name: "light_vertex") else {
            fatalError("Failed to find vertex function 'light_vertex'")
        }
        guard let fragmentProgram = library.makeFunction(name: "light_fragment") else {
            fatalError("Failed to find fragment function 'light_fragment'")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexProgram
        descriptor.fragmentFunction = fragmentProgram
        descriptor.colorAttachments[0].pixelFormat = pixelFormat

        let color = descriptor.colorAttachments[0]
        color?.isBlendingEnabled = true
        color?.rgbBlendOperation = .add
        color?.alphaBlendOperation = .add
        color?.sourceRGBBlendFactor = .one
        color?.sourceAlphaBlendFactor = .one
        color?.destinationRGBBlendFactor = .one
        color?.destinationAlphaBlendFactor = .one

        do {
            return try renderCore.device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create light pipeline state: \(error)")
        }
    }
}
