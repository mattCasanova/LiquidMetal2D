//
//  Texture.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/11/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

public class Texture {

    nonisolated(unsafe) private static var sIdCounter = 0

    private static let bytesPerPixel = 4
    private static let bitsPerComponent = 8

    private let path: String!
    private let isMipmapped: Bool
    private var mId = 0
    private var mWidth: Int = 0
    private var mHeight: Int = 0
    private var mTexture: MTLTexture!

    public let fileName: String

    public var texture: MTLTexture { mTexture }
    public var id: Int { mId }
    public var width: Int { mWidth }
    public var height: Int { mHeight }

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

        let rowBytes = mWidth * Texture.bytesPerPixel

        guard let context = CGContext(
            data: nil,
            width: mWidth,
            height: mHeight,
            bitsPerComponent: Texture.bitsPerComponent,
            bytesPerRow: rowBytes,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else { return }

        let bounds = CGRect(x: 0, y: 0, width: mWidth, height: mHeight)
        context.clear(bounds)
        context.draw(image, in: bounds)

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.bgra8Unorm,
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
                onComplete: { _ in })
        }

        Texture.sIdCounter += 1
        mId = Texture.sIdCounter
        loadCount += 1

        DebugPrint("Loaded Texture %@", fileName)
    }

    func generateMipmapLayers(
        texture: MTLTexture, device: MTLDevice,
        commandQueue: MTLCommandQueue, onComplete: @escaping MTLCommandBufferHandler
    ) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
            let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else { return }

        commandBuffer.addCompletedHandler(onComplete)
        blitCommandEncoder.generateMipmaps(for: texture)
        blitCommandEncoder.endEncoding()
        commandBuffer.commit()
    }
}
