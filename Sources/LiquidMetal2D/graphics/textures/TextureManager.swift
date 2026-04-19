//
//  TextureManager.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 3/20/26.
//

import Metal

@MainActor
class TextureManager {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    private var textures = [Texture]()
    private var texturesMap = [Int: Texture]()

    let errorTexture: MTLTexture
    let defaultTexture: Texture
    let defaultParticleTexture: Texture

    var defaultTextureId: Int { defaultTexture.id }
    var defaultParticleTextureId: Int { defaultParticleTexture.id }

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        errorTexture = TextureManager.createErrorTexture(device: device)
        defaultTexture = TextureManager.createDefaultTexture(device: device)
        defaultParticleTexture = TextureManager.createDefaultParticleTexture(device: device)
        textures.append(defaultTexture)
        textures.append(defaultParticleTexture)
        texturesMap[defaultTexture.id] = defaultTexture
        texturesMap[defaultParticleTexture.id] = defaultParticleTexture
    }

    // MARK: - Loading

    func loadTextures(
        _ items: [TextureDescriptor],
        completion: (() -> Void)? = nil
    ) -> [Int] {
        guard !items.isEmpty else {
            completion?()
            return []
        }

        let total = items.count
        let loaded = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        loaded.initialize(to: 0)

        return items.map { item in
            loadTexture(name: item.name, ext: item.ext, isMipmapped: item.isMipmapped) {
                let count = loaded.pointee + 1
                loaded.pointee = count
                if count == total {
                    loaded.deallocate()
                    DispatchQueue.main.async { completion?() }
                }
            }
        }
    }

    // MARK: - Unloading

    func unloadTexture(textureId: Int) {
        guard let texture = texturesMap[textureId] else { return }

        texture.loadCount -= 1

        if texture.loadCount <= 0 {
            texturesMap[textureId] = nil
            textures.removeAll(where: { $0.id == textureId })
        }
    }

    func unloadAllTextures() {
        textures.removeAll()
        texturesMap.removeAll()
    }

    // MARK: - Access

    func getTexture(id: Int) -> MTLTexture {
        return texturesMap[id]?.texture ?? errorTexture
    }

    func shutdown() {
        unloadAllTextures()
    }

    // MARK: - Private

    private func loadTexture(name: String, ext: String, isMipmapped: Bool,
                             completion: (() -> Void)? = nil) -> Int {
        let fileName = "\(name).\(ext)".lowercased()

        if let existing = textures.first(where: { $0.fileName == fileName }) {
            existing.loadCount += 1
            completion?()
            return existing.id
        }

        let newTexture = Texture(name: name, ext: ext, isMipmapped: isMipmapped)
        textures.append(newTexture)
        texturesMap[newTexture.id] = newTexture

        newTexture.loadTextureAsync(
            device: device, commandQueue: commandQueue,
            completion: completion)

        return newTexture.id
    }

    private static func createDefaultTexture(device: MTLDevice) -> Texture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false)

        guard let mtlTexture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Failed to create default texture")
        }

        var pixel: [UInt8] = [255, 255, 255, 255]
        mtlTexture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0, withBytes: &pixel,
            bytesPerRow: 4)

        return Texture(solidColorWithId: Texture.nextId(), mtlTexture: mtlTexture)
    }

    /// Procedural 64×64 soft-circle texture for additive particles: RGB is
    /// pure white, alpha falls off quadratically from opaque center to
    /// transparent corner. Tint with ``ParticleEmitterComponent/startColor``
    /// / ``endColor`` to color the resulting glow.
    private static func createDefaultParticleTexture(device: MTLDevice) -> Texture {
        let size = 64
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: size, height: size, mipmapped: false)

        guard let mtlTexture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Failed to create default particle texture")
        }

        let center = Float(size - 1) / 2
        let maxRadius = Float(size) / 2
        var pixels = [UInt8](repeating: 0, count: size * size * 4)

        for y in 0..<size {
            for x in 0..<size {
                let dx = Float(x) - center
                let dy = Float(y) - center
                let dist = sqrt(dx * dx + dy * dy) / maxRadius
                let t = max(0, 1 - dist)
                let alpha = UInt8(min(255, Int(t * t * 255)))
                let pixelIndex = (y * size + x) * 4
                // BGRA order
                pixels[pixelIndex]     = 255    // B
                pixels[pixelIndex + 1] = 255    // G
                pixels[pixelIndex + 2] = 255    // R
                pixels[pixelIndex + 3] = alpha  // A
            }
        }

        pixels.withUnsafeBytes { rawBuffer in
            mtlTexture.replace(
                region: MTLRegionMake2D(0, 0, size, size),
                mipmapLevel: 0,
                withBytes: rawBuffer.baseAddress!,
                bytesPerRow: size * 4)
        }

        return Texture(solidColorWithId: Texture.nextId(), mtlTexture: mtlTexture)
    }

    private static func createErrorTexture(device: MTLDevice) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false)

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Failed to create error texture")
        }

        // BGRA magenta: B=255, G=0, R=255, A=255
        var pixel: [UInt8] = [255, 0, 255, 255]
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0, withBytes: &pixel,
            bytesPerRow: 4)

        return texture
    }
}
