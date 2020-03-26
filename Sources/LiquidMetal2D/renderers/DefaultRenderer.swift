//
//  Gfx.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/24/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
import Metal
import MetalMath

@available(iOS 13.0, *)
public class DefaultRenderer: Renderer {
  
  private let renderCore: RenderCore
  private var renderPass: RenderPass!
  
  public var screenHeight: Float = 0
  public var screenWidth:  Float = 0
  public var screenAspect: Float = 0
  
  private var drawCount: Int = 0
  private var maxObjects: Int = 0
  
  private let vertexBuffer: MTLBuffer
  
  private let projectionUniforms = TransformUniformData()
  private var projectionBuffer: MTLBuffer!
  private let projectionBufferProvider: BufferProvider
  
  private let worldBufferProvider: BufferProvider
  private var worldBufferContents: UnsafeMutableRawPointer!
  
  private let perspectiveData = PerspectiveData()
  private let cameraData = CameraData()
  
  private var samplerState: MTLSamplerState
  
  
  public var view: UIView { get { return renderCore.view } }
  
  public init(parentView: UIView, maxObjects: Int, uniformSize: Int) {
    renderCore = RenderCore.init(parentView: parentView)
    
    guard let vertexBuffer = DefaultRenderer.createVertBuffer(device: renderCore.device),
      let samplerState = renderCore.createDefaultSampler()
      else {
        fatalError("Unable to create renderer.")
    }
    
    self.maxObjects          = maxObjects
    self.vertexBuffer        = vertexBuffer
    self.samplerState        = samplerState
    projectionBufferProvider = BufferProvider(device: renderCore.device, size: projectionUniforms.size)
    worldBufferProvider      = BufferProvider(device: renderCore.device, size: uniformSize * maxObjects)
    
  }
  
  
  public func setPerspective(fov: Float, aspect: Float,nearZ: Float, farZ: Float) {
    perspectiveData.set(aspect: aspect, fov: fov, nearZ: nearZ, farZ: farZ)
  }
  
  public func setCamera(x: Float, y: Float, distance: Float) {
    cameraData.set(x: x, y: y, distance: distance)
  }
  
  public func setClearColor(clearColor: Vector3D) {
    renderCore.setClearColor(clearColor: clearColor)
  }
  
  public func resize(scale: CGFloat, layerSize: CGSize) {
    renderCore.resize(scale: scale, layerSize: layerSize)
    
    screenWidth  = Float(renderCore.layer.drawableSize.width)
    screenHeight = Float(renderCore.layer.drawableSize.height)
    screenAspect = screenWidth / screenHeight
  }
  
  public func loadTexture(name: String, ext: String, isMipmaped: Bool, shouldFlip: Bool) -> Int {
    return renderCore.loadTexture(name: name, ext: ext, isMipmaped: isMipmaped, shouldFlip: shouldFlip)
  }
  
  public func unloadTexture(textureId: Int) {
    renderCore.unloadTexture(textureId: textureId)
  }
  
  public func project(worldCoordinate: Vector2D) -> Vector2D {
    renderCore.viewPort.withUnsafeMutableBufferPointer({ bufferPointer in
      let viewPort = bufferPointer.baseAddress!
      
      let toReturn3D = Vector3D.init(
        screenProject: Vector3D(vector2D: worldCoordinate),
        modelView: cameraData.make(),
        projection: perspectiveData.make(),
        viewPort: viewPort)
        return Vector2D(vector3D: toReturn3D)
    })
  }
  
  public func unProject(screenCoordinate: Vector2D) -> Vector3D {
    
    renderCore.viewPort.withUnsafeMutableBufferPointer({ bufferPointer in
      let viewPort = bufferPointer.baseAddress!
      let toReturn = Vector3D.init(
        screenUnproject: Vector3D(vector2D: screenCoordinate),
        modelView: cameraData.make(),
        projection: perspectiveData.make(),
        viewPort: viewPort)
      //Because openGl and metal view ports have different y origin
      toReturn.y = -toReturn.y
      return toReturn
      
    })
  
  }
  
  public func getWorldBoundsFromCamera(zOrder: Float) -> Bounds {
    return getWorldBounds(cameraDistance: cameraData.distance, zOrder: zOrder)
  }
  
  public func getWorldBounds(cameraDistance: Float, zOrder: Float) -> Bounds {
    let angle = 0.5 * perspectiveData.fov
    let maxY = tan(angle) * (cameraDistance - zOrder)
    let maxX = maxY * screenAspect
    
    return Bounds(maxX: maxX, minX: -maxX, maxY: maxY, minY: -maxY)
  }
  
  //MARK: Draw Methods
  
  public func useTexture(textureId: Int) {
    guard let texture = renderCore.getTexture(id: textureId) else { return }
    renderPass.encoder.setFragmentTexture(texture.texture, index: 0)
  }
  
  public func usePerspective() {
    let contents = projectionBuffer.contents()
    projectionUniforms.transform = perspectiveData.make() * cameraData.make()
    projectionUniforms.setBuffer(buffer: contents, offsetIndex: 0)
    renderPass.encoder.setVertexBuffer(projectionBuffer, offset: 0, index: 1)
  }
  
  public func useOrthographic() {
    
  }
  
  public func beginPass() {
    renderPass = RenderPass(
      layer: renderCore.layer,
      commandQueue: renderCore.commandQueue,
      clearColor: renderCore.clearColor)
    
    projectionBufferProvider.wait()
    worldBufferProvider.wait()
    
    projectionBuffer = projectionBufferProvider.nextBuffer()
    
    renderPass.addCompletedHandler { [unowned self] (_) in
      self.projectionBufferProvider.signal()
      self.worldBufferProvider.signal()
    }
    
    renderPass.encoder.setRenderPipelineState(renderCore.alphaBlendPipelineState)
    renderPass.encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    renderPass.encoder.setFragmentSamplerState(samplerState, index: 0)
    
    
    let worldBuffer = worldBufferProvider.nextBuffer()
    worldBufferContents = worldBuffer.contents()
    renderPass.encoder.setVertexBuffer(worldBuffer, offset: 0, index: 2)
    drawCount = 0
  }
  
  public func draw(uniforms: UniformData) {
    guard drawCount < maxObjects else { return }
    
    let offset = uniforms.size * drawCount
    
    uniforms.setBuffer(buffer: worldBufferContents, offsetIndex: drawCount)
    renderPass.encoder.setVertexBufferOffset(offset, index: 2)
    renderPass.encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
    
    drawCount += 1
  }
  
  public func endPass() {
    renderPass.end()
    renderPass = nil
    drawCount = 0
  }
  
  
  
  private static func createVertBuffer(device: MTLDevice) -> MTLBuffer? {
    let vertexData: [Float] = [
      -0.5, -0.5, 0.0, 0.0, 1.0,
       0.5, -0.5, 0.0, 1.0, 1.0,
      -0.5,  0.5, 0.0, 0.0, 0.0,
       0.5,  0.5, 0.0, 1.0, 0.0
    ]
    
    let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
    return device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
  }
  
  
  
  
}
