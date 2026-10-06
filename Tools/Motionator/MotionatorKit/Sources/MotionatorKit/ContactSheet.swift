//
//  ContactSheet.swift
//  MotionatorKit
//
//  Created by Matt Casanova on 10/6/26.
//

import AppKit
import CoreGraphics
import CoreText
import ImageIO
import LiquidMetal2D
import Metal

public enum ContactSheetError: Error, CustomStringConvertible {
    case noSuchClip(String)
    case badImage(String)
    case noRenderPass
    case noTexture
    case cannotWrite(String)

    public var description: String {
        switch self {
        case .noSuchClip(let name): "no clip named \(name)"
        case .badImage(let name): "image \(name) is not a PNG the system can decode"
        case .noRenderPass: "the renderer could not begin a pass"
        case .noTexture: "Metal could not make the sheet's texture"
        case .cannotWrite(let path): "could not write \(path)"
        }
    }
}

/// N frames of a clip, drawn by the real renderer into one image: the way an
/// agent looks at an animation. Each frame sits in a square cell with its
/// time under it; the camera is framed once over every frame's extent, so
/// the figure holds still in the cells and the motion reads.
public struct ContactSheet: Sendable {
    public var frames = 8
    /// Pixels; the cells are square.
    public var cellSize = 256
    public var background = Vec3(0.1, 0.1, 0.12)
    /// The time under each cell.
    public var labels = true
    /// The previous frame at a quarter alpha in each cell.
    public var ghost = false

    public static let labelHeight = 18

    public init() {}

    /// Renders the sheet headless: a render core on a view in no window, as
    /// the engine's own pixel tests do.
    @MainActor
    public func render(_ character: Character, clip clipName: String) throws -> CGImage {
        guard let clip = character.clip(named: clipName) else { throw ContactSheetError.noSuchClip(clipName) }
        let rig = character.rig
        let resolved = try clip.resolved(for: rig)
        let renderer = SheetRenderer(parentView: PlatformView(), maxObjects: max(1, rig.attachments.count * 2))
        let core = renderer.renderCore
        core.resize(scale: 1, layerSize: CGSize(width: cellSize, height: cellSize))
        renderer.setClearColor(color: background)

        let textureIDs = try Self.loadTextures(of: character, into: renderer)
        // The roots own nothing the parts need, but the components hold them
        // unowned: keep them alive for the whole render.
        let (figureRoot, figure) = try Self.makeFigure(rig: rig, renderer: renderer, textureIDs: textureIDs)
        let shadowPair = ghost ? try Self.makeFigure(rig: rig, renderer: renderer, textureIDs: textureIDs) : nil
        let shadow = shadowPair?.skeleton
        defer { withExtendedLifetime((figureRoot, shadowPair?.root)) {} }
        let times = Self.sampleTimes(duration: clip.duration, loops: clip.loops, frames: frames)
        Self.frame(renderer, around: figure, resolved, at: times)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: core.layer.pixelFormat, width: cellSize, height: cellSize, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = core.device.hasUnifiedMemory ? .shared : .managed
        guard let target = core.device.makeTexture(descriptor: descriptor) else { throw ContactSheetError.noTexture }
        TextureRenderPass.target = target
        defer { TextureRenderPass.target = nil }

        var cells: [CGImage] = []
        for (index, time) in times.enumerated() {
            var objects: [GameObj] = []
            if let shadow, index > 0 {
                Self.pose(shadow, resolved, at: times[index - 1])
                for part in shadow.parts {
                    if let sprite = part.get(AlphaBlendComponent.self) { sprite.tintColor.w *= 0.25 }
                }
                objects += shadow.parts
            }
            Self.pose(figure, resolved, at: time)
            objects += figure.parts
            guard renderer.beginPass() else { throw ContactSheetError.noRenderPass }
            renderer.useOrthographic()
            renderer.submit(objects: objects)
            renderer.endPass()
            cells.append(try Self.readBack(target, core: core))
        }
        return try compose(cells: cells, times: times)
    }

    /// Every texture the rig names: its image, or the white default when there is none.
    @MainActor
    private static func loadTextures(of character: Character, into renderer: DefaultRenderer) throws -> [String: Int] {
        var textureIDs: [String: Int] = [:]
        for name in Set(character.rig.attachments.compactMap(\.textureName)) {
            if let data = character.images[name] {
                guard let image = decode(data), let id = renderer.addTexture(image) else {
                    throw ContactSheetError.badImage(name)
                }
                textureIDs[name] = id
            } else {
                textureIDs[name] = renderer.defaultTextureId
            }
        }
        return textureIDs
    }

    /// An orthographic camera over every frame's parts, with a margin, so
    /// the figure holds still across the cells.
    @MainActor
    private static func frame(
        _ renderer: DefaultRenderer, around figure: SkeletonComponent, _ clip: ResolvedClip, at times: [Float]
    ) {
        var low = Vec2(repeating: .greatestFiniteMagnitude)
        var high = Vec2(repeating: -.greatestFiniteMagnitude)
        for time in times {
            pose(figure, clip, at: time)
            for part in figure.parts where part.isActive {
                for corner in corners(of: part.transform) {
                    low = simd_min(low, corner)
                    high = simd_max(high, corner)
                }
            }
        }
        let centre = (low + high) / 2
        let half = max(high.x - low.x, high.y - low.y) / 2 * 1.1
        renderer.setOrthographic(
            left: centre.x - half, right: centre.x + half, bottom: centre.y - half, top: centre.y + half,
            nearZ: -100, farZ: 100)
    }

    /// Writes a PNG.
    public static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw ContactSheetError.cannotWrite(url.path)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ContactSheetError.cannotWrite(url.path) }
    }

    /// The frame times: a loop samples up to but not including its end (the
    /// end is the start); a one-shot includes both ends.
    public static func sampleTimes(duration: Float, loops: Bool, frames: Int) -> [Float] {
        let count = max(1, frames)
        guard count > 1 else { return [0] }
        let step = loops ? duration / Float(count) : duration / Float(count - 1)
        return (0..<count).map { Float($0) * step }
    }

    // MARK: - Private

    @MainActor
    private static func makeFigure(
        rig: SkeletonDefinition, renderer: DefaultRenderer, textureIDs: [String: Int]
    ) throws -> (root: GameObj, skeleton: SkeletonComponent) {
        let root = GameObj()
        let skeleton = try SkeletonComponent(
            parent: root, definition: rig, defaultTextureID: renderer.defaultTextureId, textureIDs: textureIDs)
        root.add(skeleton)
        return (root, skeleton)
    }

    /// Puts the figure at the clip's `time` exactly: restart, then advance.
    @MainActor
    private static func pose(_ figure: SkeletonComponent, _ clip: ResolvedClip, at time: Float) {
        figure.animator.play(clip, restart: true)
        figure.update(dt: time)
    }

    private static func corners(of transform: Transform2D) -> [Vec2] {
        let cosine = cos(transform.rotation)
        let sine = sin(transform.rotation)
        let half = transform.scale / 2
        return [Vec2(-half.x, -half.y), Vec2(half.x, -half.y), Vec2(half.x, half.y), Vec2(-half.x, half.y)].map {
            transform.position + Vec2($0.x * cosine - $0.y * sine, $0.x * sine + $0.y * cosine)
        }
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Waits for the queue, then copies the target's pixels into a CGImage.
    @MainActor
    private static func readBack(_ target: MTLTexture, core: RenderCore) throws -> CGImage {
        guard let commandBuffer = core.commandQueue.makeCommandBuffer() else { throw ContactSheetError.noRenderPass }
        if target.storageMode == .managed, let blit = commandBuffer.makeBlitCommandEncoder() {
            blit.synchronize(resource: target)
            blit.endEncoding()
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let bytesPerRow = target.width * 4
        var bytes = Data(count: bytesPerRow * target.height)
        bytes.withUnsafeMutableBytes { buffer in
            target.getBytes(buffer.baseAddress!, bytesPerRow: bytesPerRow,
                            from: MTLRegionMake2D(0, 0, target.width, target.height), mipmapLevel: 0)
        }
        guard let provider = CGDataProvider(data: bytes as CFData),
              let image = CGImage(
                width: target.width, height: target.height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue
                                         | CGImageAlphaInfo.premultipliedFirst.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw ContactSheetError.noTexture }
        return image
    }

    private func compose(cells: [CGImage], times: [Float]) throws -> CGImage {
        let labelHeight = labels ? Self.labelHeight : 0
        let width = cellSize * cells.count
        let height = cellSize + labelHeight
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ContactSheetError.noTexture }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for (index, cell) in cells.enumerated() {
            context.draw(cell, in: CGRect(x: index * cellSize, y: labelHeight, width: cellSize, height: cellSize))
        }
        if labels {
            let font = CTFontCreateWithName("Menlo" as CFString, 11, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                .init(kCTFontAttributeName as String): font,
                .init(kCTForegroundColorAttributeName as String): CGColor(gray: 0.85, alpha: 1),
            ]
            for (index, time) in times.enumerated() {
                let line = CTLineCreateWithAttributedString(
                    NSAttributedString(string: String(format: "%.3f s", time), attributes: attributes))
                context.textPosition = CGPoint(x: index * cellSize + 4, y: 5)
                CTLineDraw(line, context)
            }
        }
        guard let image = context.makeImage() else { throw ContactSheetError.noTexture }
        return image
    }
}

/// A pass into `target` instead of the layer's drawable.
@MainActor
final class TextureRenderPass: RenderPass {
    static var target: MTLTexture?

    override static func createDescriptor(
        drawable: CAMetalDrawable, clearColor: MTLClearColor
    ) -> MTLRenderPassDescriptor? {
        guard let target else { return nil }
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = target
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = clearColor
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }
}

@MainActor
final class SheetRenderer: DefaultRenderer {
    override func makeRenderPass() -> RenderPass? {
        TextureRenderPass(renderCore: renderCore)
    }
}
