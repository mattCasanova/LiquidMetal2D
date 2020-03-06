//
//  Texture.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/11/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
import MetalMath

public class Texture: NSObject {
    
    var target: MTLTextureType = MTLTextureType.type2D
    var pixelFormat = MTLPixelFormat.rgba8Unorm
    var depth: Int = 1
    let bytesPerPixel = 4
    let bitsPerComponent = 8
    
    public var texture: MTLTexture! = nil
    var width: Int = 0
    var height: Int = 0
    var hasAlpha: Bool!
    var path: String!
    var isMipmapped: Bool!

    
    public init(name: String, ext: String, isMipmaped: Bool) {
        path = Bundle.main.path(forResource: name, ofType: ext)
        self.isMipmapped = isMipmaped
        super.init()
    }
    
    public func loadTexture(device: MTLDevice, commandQueue: MTLCommandQueue, flip: Bool) {
        guard let image = UIImage(contentsOfFile: path)?.cgImage else { return }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        width = image.width
        height = image.height
        
        let rowBytes = width * bytesPerPixel
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: rowBytes,
            space:  colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }

        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(bounds)
        
        if !flip {
            context.scaleBy(x: 1, y: -1)
        }
        
        context.draw(image, in: bounds)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm, width: width, height: height, mipmapped: isMipmapped)
        target = textureDescriptor.textureType
        texture = device.makeTexture(descriptor: textureDescriptor)
        
        guard let pixelData = context.data else { return }
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: pixelData, bytesPerRow: Int(rowBytes))
        
        if isMipmapped {
            generateMipmapLayers(texture: texture, device: device, commandQueue: commandQueue, onComplete: { (buffer) -> Void in print("mips generated")})
        }
        
        print("mipCount:\(texture.mipmapLevelCount)")
    }
    
    func textureCopy(source: MTLTexture, device: MTLDevice, isMipmapped: Bool) -> MTLTexture? {
        //This seems like a bug, but the original pxel format was bgra8Unorm
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm, width: source.width, height: source.height, mipmapped: isMipmapped)
        
        let rowSize = source.width * bytesPerPixel
        let dataSize = rowSize * source.height
        
        let region = MTLRegionMake2D(0, 0, source.width, source.height)
        guard let copyTexture = device.makeTexture(descriptor: textureDescriptor), let pixelData = malloc(dataSize) else { return nil }
        
        source.getBytes(pixelData, bytesPerRow: rowSize, from: region, mipmapLevel: 0)
        copyTexture.replace(region: region, mipmapLevel: 0, withBytes: pixelData, bytesPerRow: rowSize)
        
        free(pixelData)
        return copyTexture
    }
    
    func copyMipLevel(source: MTLTexture, destination: MTLTexture, mipLevel: Int) {
        let q = Int(powf(2, Float(mipLevel)))
        let mipmappedWidth = GameMath.maxInt(source.width / q, y: 1)
        let mipmappedHeight = GameMath.maxInt(source.height / q, y: 1)
        
        let rowSize = mipmappedWidth * bytesPerPixel
        
        let region = MTLRegionMake2D(0, 0, mipmappedWidth, mipmappedHeight)
        guard let pixelData = malloc(mipmappedHeight * rowSize) else { return }
        
        source.getBytes(pixelData, bytesPerRow: rowSize, from: region, mipmapLevel: mipLevel)
        destination.replace(region: region, mipmapLevel: mipLevel, withBytes: pixelData, bytesPerRow: rowSize)
        free(pixelData)
    }
    
    //MARK: - Generating UIImage from texture mip layers
    func image(mipLevel: Int) -> UIImage? {
        guard let p = bytesForMipLevel(mipLevel: mipLevel) else { return nil }
        
        let q = Int(powf(2, Float(mipLevel)))
        let mipmappedWidth = GameMath.maxInt(width / q, y: 1)
        let mipmappedHeight = GameMath.maxInt(height / q, y: 1)
        
        //This should changed to costant
        let rowBytes = mipmappedWidth * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: p,
            width: mipmappedWidth,
            height: mipmappedHeight,
            bitsPerComponent: bitsPerComponent,
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
    
    
    //MARK: - Getting raw bytes from texture mip layers
    
    
    func bytesForMipLevel(mipLevel: Int = 0) -> UnsafeMutableRawPointer? {
        let q = GameMath.getNextPowerOf2(mipLevel)
        let mipmappedWidth = GameMath.maxInt(width / q, y: 1)
        let mipmappedHeight = GameMath.maxInt(height / q, y: 1)
        
        let rowBytes = mipmappedWidth * bytesPerPixel
        let region = MTLRegionMake2D(0, 0, mipmappedWidth, mipmappedHeight)
        
        guard let pointer = malloc(rowBytes * mipmappedHeight) else { return nil }
        
        texture.getBytes(pointer, bytesPerRow: rowBytes, from: region, mipmapLevel: mipLevel)
        return pointer
    }
    
    func bytes() -> UnsafeMutableRawPointer? {
        return bytesForMipLevel()
    }
    
    func generateMipmapLayers(texture: MTLTexture, device: MTLDevice, commandQueue: MTLCommandQueue, onComplete: @escaping MTLCommandBufferHandler) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(), let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
        
        commandBuffer.addCompletedHandler(onComplete)
        blitCommandEncoder.generateMipmaps(for: texture)
        blitCommandEncoder.endEncoding()
        commandBuffer.commit()
    }
    
}
