//
//  AlphaBlendRenderPass.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 3/20/26.
//

import Metal

@MainActor
class AlphaBlendRenderPass: RenderPass {

    func setup(
        pipelineState: MTLRenderPipelineState,
        vertexBuffer: MTLBuffer,
        samplerState: MTLSamplerState,
        worldBuffer: MTLBuffer
    ) {
        encoder.setViewport(renderCore.viewport)
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: AlphaBlendPipeline.vertexBufferIndex)
        encoder.setFragmentSamplerState(samplerState, index: AlphaBlendPipeline.samplerIndex)
        encoder.setVertexBuffer(worldBuffer, offset: 0, index: AlphaBlendPipeline.worldBufferIndex)
    }

    func setProjection(buffer: MTLBuffer) {
        encoder.setVertexBuffer(buffer, offset: 0, index: AlphaBlendPipeline.projectionBufferIndex)
    }

    func drawBatches(_ batches: [DefaultRenderer.TextureBatch]) {
        for batch in batches {
            encoder.setFragmentTexture(
                renderCore.textureManager.getTexture(id: batch.textureId),
                index: AlphaBlendPipeline.textureIndex)
            let offset = batch.startIndex * WorldUniform.typeSize()
            encoder.setVertexBufferOffset(offset, index: AlphaBlendPipeline.worldBufferIndex)
            encoder.drawPrimitives(
                type: .triangleStrip, vertexStart: 0,
                vertexCount: 4, instanceCount: batch.count)
        }
    }
}
