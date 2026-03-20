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
    private static let loadQueue = DispatchQueue(label: "com.liquidmetal2d.textureLoad", qos: .userInitiated)

    private static let bytesPerPixel = 4
    private static let bitsPerComponent = 8

    private let path: String?
    private let isMipmapped: Bool
    private var mWidth: Int = 0
    private var mHeight: Int = 0
    private var mTexture: MTLTexture?

    public let fileName: String
    public let id: Int

    public var texture: MTLTexture? { mTexture }
    public var width: Int { mWidth }
    public var height: Int { mHeight }
    public var isLoaded: Bool { mTexture != nil }

    public var loadCount = 0

    static func nextId() -> Int {
        sIdCounter += 1
        return sIdCounter
    }

    /// Creates a texture from a pre-built MTLTexture (used for solid colors).
    public init(solidColorWithId id: Int, mtlTexture: MTLTexture) {
        self.id = id
        self.fileName = "__solid_\(id)"
        self.path = nil
        self.isMipmapped = false
        self.mTexture = mtlTexture
        self.mWidth = mtlTexture.width
        self.mHeight = mtlTexture.height
        self.loadCount = 1
    }

    public init(name: String, ext: String, isMipmaped: Bool) {
        self.id = Texture.nextId()
        self.fileName = "\(name).\(ext)".lowercased()
        self.path = Bundle.main.path(forResource: name, ofType: ext)
        self.isMipmapped = isMipmaped
        self.loadCount = 1
    }

    /// Loads the texture synchronously on the current thread.
    public func loadTexture(device: MTLDevice, commandQueue: MTLCommandQueue) {
        guard let path, let image = UIImage(contentsOfFile: path)?.cgImage else { return }
        loadFromImage(image, device: device, commandQueue: commandQueue)
        DebugPrint("Loaded Texture %@", fileName)
    }

    /// Loads the texture asynchronously on a background queue.
    /// Until loading completes, `texture` returns nil and the renderer
    /// uses the error texture as a fallback. Optional completion fires
    /// on the background queue when loading finishes.
    public func loadTextureAsync(
        device: MTLDevice, commandQueue: MTLCommandQueue,
        completion: (() -> Void)? = nil
    ) {
        guard let path else {
            completion?()
            return
        }

        Texture.loadQueue.async { [weak self] in
            guard let self,
                  let image = UIImage(contentsOfFile: path)?.cgImage else {
                completion?()
                return
            }

            self.loadFromImage(image, device: device, commandQueue: commandQueue)
            DebugPrint("Async loaded Texture %@", self.fileName)
            completion?()
        }
    }

    private func loadFromImage(_ image: CGImage, device: MTLDevice, commandQueue: MTLCommandQueue) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let width = image.width
        let height = image.height
        let rowBytes = width * Texture.bytesPerPixel

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: Texture.bitsPerComponent,
            bytesPerRow: rowBytes,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                CGImageAlphaInfo.premultipliedFirst.rawValue) else { return }

        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(bounds)
        context.draw(image, in: bounds)

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.bgra8Unorm,
            width: width,
            height: height,
            mipmapped: isMipmapped)

        guard let newTexture = device.makeTexture(descriptor: textureDescriptor) else { return }
        guard let pixelData = context.data else { return }

        let region = MTLRegionMake2D(0, 0, width, height)
        newTexture.replace(region: region, mipmapLevel: 0, withBytes: pixelData, bytesPerRow: rowBytes)

        if isMipmapped {
            generateMipmapLayers(
                texture: newTexture,
                device: device,
                commandQueue: commandQueue,
                onComplete: { _ in })
        }

        // Texture properties are read on the main thread during rendering.
        // MTLTexture is thread-safe, so assigning from background is safe.
        // Width/height are only used for informational purposes.
        mWidth = width
        mHeight = height
        mTexture = newTexture
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
