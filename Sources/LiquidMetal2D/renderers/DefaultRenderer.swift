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

  private let baseRenderer: BaseRenderer
  private var renderPassData: RenderPassData!
  
  public var screenHeight: Float = 0
  public var screenWidth:  Float = 0
  public var screenAspect: Float = 0
  
  private var drawCount: Int = 0
  private var maxObjects: Int = 0
  
  private let vertexBuffer: MTLBuffer
  
  private let projectionUniforms = TransformUniformData()
  private var projectionBuffer: MTLBuffer!
  private let projectionUniformProvider: BufferProvider!
  
  private let worldUniformProvider: BufferProvider!
  private var worldUniformsPointer: UnsafeMutableRawPointer!
  
  private let perspectiveData = PerspectiveData()
  private let cameraData = CameraData()
  
  private var samplerState: MTLSamplerState!
  
  
  public var view: UIView { get { return baseRenderer.view } }
  
  public init(parentView: UIView, maxObjects: Int, uniformSize: Int) {
    baseRenderer = BaseRenderer.init(parentView: parentView)
    
    self.maxObjects = maxObjects
    
    vertexBuffer = DefaultRenderer.createVertBuffer(device: baseRenderer.device)!
    
    projectionUniformProvider = BufferProvider(device: baseRenderer.device, size: projectionUniforms.size)
    worldUniformProvider      = BufferProvider(device: baseRenderer.device, size: uniformSize * maxObjects)
    samplerState = baseRenderer.createDefaultSampler(device: baseRenderer.device)
  }
  
  
  public func setPerspective(fov: Float, aspect: Float,nearZ: Float, farZ: Float) {
    perspectiveData.set(aspect: aspect, fov: fov, nearZ: nearZ, farZ: farZ)
  }
  
  public func setCamera(x: Float, y: Float, distance: Float) {
    cameraData.set(x: x, y: y, distance: distance)
  }
  
  public func setClearColor(clearColor: Vector3D) {
    baseRenderer.setClearColor(clearColor: clearColor)
  }
  
  public func resize(scale: CGFloat, layerSize: CGSize) {
    baseRenderer.resize(scale: scale, layerSize: layerSize)
    
    screenWidth  = Float(baseRenderer.layer.drawableSize.width)
    screenHeight = Float(baseRenderer.layer.drawableSize.height)
    screenAspect = screenWidth / screenHeight
  }
  
  public func loadTexture(name: String, ext: String, isMipmaped: Bool, shouldFlip: Bool) -> Int {
    return baseRenderer.loadTexture(name: name, ext: ext, isMipmaped: isMipmaped, shouldFlip: shouldFlip)
  }
  
  public func unloadTexture(textureId: Int) {
    baseRenderer.unloadTexture(textureId: textureId)
  }
  
  public func project(worldCoordinate: Vector2D) -> Vector2D {
    let viewPort = UnsafeMutablePointer<Int32>(mutating: baseRenderer.viewPort)
    
    let toReturn3D = Vector3D.init(screenProject: Vector3D(vector2D: worldCoordinate), modelView: cameraData.make(), projection: perspectiveData.make(), viewPort: viewPort)
    return Vector2D(vector3D: toReturn3D)
  }
  
  public func unProject(screenCoordinate: Vector2D) -> Vector3D {
    let viewPort = UnsafeMutablePointer<Int32>(mutating: baseRenderer.viewPort)
    let toReturn = Vector3D.init(screenUnproject: Vector3D(vector2D: screenCoordinate), modelView: cameraData.make(), projection: perspectiveData.make(), viewPort: viewPort)
    
    toReturn.y = -toReturn.y
    
    return toReturn
  }
  
  public func getWorldBounds(zOrder: Float) -> Bounds {
    let angle = 0.5 * perspectiveData.fov
    let maxY = tan(angle) * (cameraData.distance - zOrder)
    let maxX = maxY * screenAspect
    
    return Bounds(maxX: maxX, minX: -maxX, maxY: maxY, minY: -maxY)
  }
  
  //MARK: Draw Methods
  
  public func setTexture(textureId: Int) {
    guard let texture = baseRenderer.getTexture(id: textureId) else { return }
    renderPassData.encoder.setFragmentTexture(texture.texture, index: 0)
  }
  
  public func renderPerspective() {
    let contents = projectionBuffer.contents()
    projectionUniforms.transform = perspectiveData.make() * cameraData.make()
    projectionUniforms.setBuffer(buffer: contents, offsetIndex: 0)
    renderPassData.encoder.setVertexBuffer(projectionBuffer, offset: 0, index: 1)
  }
  
  public func renderOrthographic() {
    
  }
  
  public func beginRenderPass() {
    renderPassData = RenderPassData(
      layer: baseRenderer.layer,
      commandQueue: baseRenderer.commandQueue,
      clearColor: baseRenderer.clearColor)
    
    projectionUniformProvider.wait()
    worldUniformProvider.wait()
    
    projectionBuffer = projectionUniformProvider.nextBuffer()
    
    renderPassData.commandBuffer.addCompletedHandler { [weak self] (_) in
      self?.projectionUniformProvider.signal()
      self?.worldUniformProvider.signal()
    }
    
    renderPassData.encoder.setRenderPipelineState(baseRenderer.alphaBlendPipelineState)
    renderPassData.encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    renderPassData.encoder.setFragmentSamplerState(samplerState, index: 0)
    
    
    let worldBuffer = worldUniformProvider.nextBuffer()
    worldUniformsPointer = worldBuffer.contents()
    renderPassData.encoder.setVertexBuffer(worldBuffer, offset: 0, index: 2)
    drawCount = 0
  }
  
  public func draw(uniforms: UniformData) {
    guard drawCount < maxObjects else { return }
    
    let offset = uniforms.size * drawCount
    
    uniforms.setBuffer(buffer: worldUniformsPointer, offsetIndex: drawCount)
    renderPassData.encoder.setVertexBufferOffset(offset, index: 2)
    renderPassData.encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
    
    drawCount += 1
  }
  
  public func endRenderPass() {
    renderPassData.endPass()
    renderPassData = nil
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
