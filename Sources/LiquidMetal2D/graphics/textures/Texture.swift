//
//  Texture.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/11/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

/// A texture loaded from the app bundle (or built from a solid color).
///
/// Main-actor isolated: the renderer reads ``texture`` every frame on the
/// main thread, so every write to it happens there too. Async loads decode
/// and upload on a background queue, then publish the result on main.
@MainActor
public class Texture {

    private static var sIdCounter = 0
    private nonisolated static let loadQueue = DispatchQueue(
        label: "com.liquidmetal2d.textureLoad", qos: .userInitiated)

    private nonisolated static let bytesPerPixel = 4
    private nonisolated static let bitsPerComponent = 8

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

    public init(name: String, ext: String, isMipmapped: Bool) {
        self.id = Texture.nextId()
        self.fileName = "\(name).\(ext)".lowercased()
        self.path = Bundle.main.path(forResource: name, ofType: ext)
        self.isMipmapped = isMipmapped
        self.loadCount = 1
    }

    /// Loads the texture synchronously on the main thread.
    public func loadTexture(device: MTLDevice, commandQueue: MTLCommandQueue) {
        guard let path, let image = UIImage(contentsOfFile: path)?.cgImage else { return }
        guard let newTexture = Texture.makeTexture(
            from: image, isMipmapped: isMipmapped, device: device, commandQueue: commandQueue) else { return }
        publish(newTexture)
        DebugPrint("Loaded Texture %@", fileName)
    }

    /// Loads the texture asynchronously. Decoding and GPU upload run on a
    /// background queue; the finished texture is published and `completion`
    /// fires on the main thread. Until then, `texture` returns nil and the
    /// renderer uses the error texture as a fallback.
    public func loadTextureAsync(
        device: MTLDevice, commandQueue: MTLCommandQueue,
        completion: (@MainActor () -> Void)? = nil
    ) {
        guard let path else {
            completion?()
            return
        }

        let isMipmapped = self.isMipmapped
        Texture.loadQueue.async { [weak self] in
            let newTexture = UIImage(contentsOfFile: path)?.cgImage.flatMap {
                Texture.makeTexture(from: $0, isMipmapped: isMipmapped, device: device, commandQueue: commandQueue)
            }
            let loaded = newTexture.map(SendableTexture.init)

            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if let self, let loaded {
                        self.publish(loaded.value)
                        DebugPrint("Async loaded Texture %@", self.fileName)
                    }
                    completion?()
                }
            }
        }
    }

    private func publish(_ newTexture: MTLTexture) {
        mWidth = newTexture.width
        mHeight = newTexture.height
        mTexture = newTexture
    }

    /// Decodes `image` into a new GPU texture. Pure: touches no instance
    /// state, so it can run on any thread.
    private nonisolated static func makeTexture(
        from image: CGImage, isMipmapped: Bool, device: MTLDevice, commandQueue: MTLCommandQueue
    ) -> MTLTexture? {
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
                CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }

        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(bounds)
        context.draw(image, in: bounds)

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.bgra8Unorm,
            width: width,
            height: height,
            mipmapped: isMipmapped)

        guard let newTexture = device.makeTexture(descriptor: textureDescriptor) else { return nil }
        guard let pixelData = context.data else { return nil }

        let region = MTLRegionMake2D(0, 0, width, height)
        newTexture.replace(region: region, mipmapLevel: 0, withBytes: pixelData, bytesPerRow: rowBytes)

        if isMipmapped {
            Texture.generateMipmapLayers(
                texture: newTexture,
                device: device,
                commandQueue: commandQueue,
                onComplete: { _ in })
        }

        return newTexture
    }

    private nonisolated static func generateMipmapLayers(
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

/// Carries a finished texture from the load queue to the main thread. The
/// texture is fully built before it is wrapped and nothing touches it on
/// the load queue afterwards, so handing it across is safe.
private struct SendableTexture: @unchecked Sendable {
    let value: MTLTexture
}
