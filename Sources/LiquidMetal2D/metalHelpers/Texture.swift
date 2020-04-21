//
//  Texture.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/11/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

public class Texture {
  
  private static var sIdCounter = 0
  
  private static let BYTES_PER_PIXEL = 4
  private static let BITS_PER_COMPONENT = 8
  
  private let path: String!
  private let isMipmapped: Bool
  private var mId = 0
  private var mWidth: Int = 0
  private var mHeight: Int = 0
  private var mTexture: MTLTexture! = nil
  
  public let fileName: String
  
  public var texture: MTLTexture { get { mTexture } }
  public var id: Int { get { mId } }
  public var width: Int { get { mWidth } }
  public var height: Int { get { mHeight } }
  
  public var loadCount = 0
  
  public init(name: String, ext: String, isMipmaped: Bool) {
    self.fileName = "\(name).\(ext)".lowercased()
    self.path = Bundle.main.path(forResource: name, ofType: ext)
    self.isMipmapped = isMipmaped
  }
  
  public func loadTexture(device: MTLDevice, commandQueue: MTLCommandQueue) {
    guard let image = UIImage(contentsOfFile: path)?.cgImage else { return }
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    mWidth = image.width
    mHeight = image.height
    
    let rowBytes = mWidth * Texture.BYTES_PER_PIXEL
    
    guard let context = CGContext(
      data: nil,
      width: mWidth,
      height: mHeight,
      bitsPerComponent: Texture.BITS_PER_COMPONENT,
      bytesPerRow: rowBytes,
      space:  colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    
    let bounds = CGRect(x: 0, y: 0, width: mWidth, height: mHeight)
    context.clear(bounds)
    context.draw(image, in: bounds)
    
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: MTLPixelFormat.rgba8Unorm,
      width: mWidth,
      height: mHeight,
      mipmapped: isMipmapped)
    

    mTexture = device.makeTexture(descriptor: textureDescriptor)
    
    guard let pixelData = context.data else { return }

    let region = MTLRegionMake2D(0, 0, mWidth, mHeight)
    mTexture.replace(region: region, mipmapLevel: 0, withBytes: pixelData, bytesPerRow: Int(rowBytes))
    
    if isMipmapped {
      generateMipmapLayers(
        texture: mTexture,
        device: device,
        commandQueue: commandQueue,
        onComplete: { (buffer) -> Void in })
    }
    
    Texture.sIdCounter += 1
    mId = Texture.sIdCounter
    loadCount += 1
    
    print("Loaded Texture \(fileName)")
  }
  
  func generateMipmapLayers(texture: MTLTexture, device: MTLDevice, commandQueue: MTLCommandQueue, onComplete: @escaping MTLCommandBufferHandler) {
    guard let commandBuffer = commandQueue.makeCommandBuffer(), let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
    
    commandBuffer.addCompletedHandler(onComplete)
    blitCommandEncoder.generateMipmaps(for: texture)
    blitCommandEncoder.endEncoding()
    commandBuffer.commit()
  }
  
  //MARK: - Example methods That I didn't need...yet???
  
  /*
  func textureCopy(source: MTLTexture, device: MTLDevice, isMipmapped: Bool) -> MTLTexture? {
    //This seems like a bug, but the original pxel format was bgra8Unorm
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm, width: source.width, height: source.height, mipmapped: isMipmapped)
    
    let rowSize = source.width * Texture.bytesPerPixel
    let dataSize = rowSize * source.height
    
    let region = MTLRegionMake2D(0, 0, source.width, source.height)
    guard let copyTexture = device.makeTexture(descriptor: textureDescriptor), let pixelData = malloc(dataSize) else { return nil }
    
    source.getBytes(pixelData, bytesPerRow: rowSize, from: region, mipmapLevel: 0)
    copyTexture.replace(region: region, mipmapLevel: 0, withBytes: pixelData, bytesPerRow: rowSize)
    
    free(pixelData)
    return copyTexture
  }
 */
  
  /*
  
  func copyMipLevel(source: MTLTexture, destination: MTLTexture, mipLevel: Int) {
    let q = Int(powf(2, Float(mipLevel)))
    let mipmappedWidth = GameMath.maxInt(source.width / q, y: 1)
    let mipmappedHeight = GameMath.maxInt(source.height / q, y: 1)
    
    let rowSize = mipmappedWidth * Texture.bytesPerPixel
    
    let region = MTLRegionMake2D(0, 0, mipmappedWidth, mipmappedHeight)
    guard let pixelData = malloc(mipmappedHeight * rowSize) else { return }
    
    source.getBytes(pixelData, bytesPerRow: rowSize, from: region, mipmapLevel: mipLevel)
    destination.replace(region: region, mipmapLevel: mipLevel, withBytes: pixelData, bytesPerRow: rowSize)
    free(pixelData)
  }
 
 */
  
 
  /*
  func image(mipLevel: Int) -> UIImage? {
    guard let p = bytesForMipLevel(mipLevel: mipLevel) else { return nil }
    
    let q = Int(powf(2, Float(mipLevel)))
    let mipmappedWidth = GameMath.maxInt(width / q, y: 1)
    let mipmappedHeight = GameMath.maxInt(height / q, y: 1)
    

    let rowBytes = mipmappedWidth * Texture.bytesPerPixel
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    guard let context = CGContext(
      data: p,
      width: mipmappedWidth,
      height: mipmappedHeight,
      bitsPerComponent: Texture.bitsPerComponent,
      bytesPerRow: rowBytes,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
        free(p)
        return nil
    }
    
    guard let imageRef = context.makeImage()
      else {
        free(p)
        return nil
    }
    
    return UIImage(cgImage: imageRef)
  }
  
  func image() -> UIImage? {
    return image(mipLevel: 0)
  }
 
 */
  
  /*
  func bytesForMipLevel(mipLevel: Int = 0) -> UnsafeMutableRawPointer? {
    let q = GameMath.getNextPowerOf2(mipLevel)
    let mipmappedWidth = GameMath.maxInt(width / q, y: 1)
    let mipmappedHeight = GameMath.maxInt(height / q, y: 1)
    
    let rowBytes = mipmappedWidth * Texture.bytesPerPixel
    let region = MTLRegionMake2D(0, 0, mipmappedWidth, mipmappedHeight)
    
    guard let pointer = malloc(rowBytes * mipmappedHeight) else { return nil }
    
    texture.getBytes(pointer, bytesPerRow: rowBytes, from: region, mipmapLevel: mipLevel)
    return pointer
  }
  
  func bytes() -> UnsafeMutableRawPointer? {
    return bytesForMipLevel()
  }
 */
  

  
}
