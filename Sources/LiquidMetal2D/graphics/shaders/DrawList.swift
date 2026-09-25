//
//  DrawList.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/22/26.
//

/// The objects one shader draws this frame, in draw order.
///
/// ``rebuild(from:)`` collects the active objects that carry `Comp` and
/// sorts them by `(zOrder, textureID)`. Ascending `zOrder` is far-to-near
/// for this engine's camera (it sits at `z = distance` looking down −z),
/// which "over" blending needs; grouping by texture within a z level lets
/// consecutive instances batch.
///
/// The array keeps its capacity between frames. When the objects arrive
/// already in draw order (the common case for a steady scene), the sort is
/// skipped, so a steady frame allocates nothing. Otherwise the standard
/// library's stable sort allocates a scratch buffer for that frame.
public struct DrawList<Comp: TexturedComponent> {
    /// This frame's `(object, component)` pairs in draw order. Empty
    /// between frames once the shader calls ``clear()``.
    public private(set) var pairs: [(GameObj, Comp)] = []

    public init() {}

    /// Replaces the list with the active objects in `objects` that carry
    /// `Comp`, in draw order.
    public mutating func rebuild(from objects: [GameObj]) {
        pairs.removeAll(keepingCapacity: true)
        for obj in objects where obj.isActive {
            guard let comp = obj.get(Comp.self) else { continue }
            pairs.append((obj, comp))
        }
        if !isInDrawOrder() {
            pairs.sort(by: Self.drawsBefore)
        }
    }

    /// Drops this frame's references, keeping the capacity. Call once the
    /// uniforms are written so a popped scene's objects aren't held until
    /// the next frame.
    public mutating func clear() {
        pairs.removeAll(keepingCapacity: true)
    }

    private func isInDrawOrder() -> Bool {
        for index in pairs.indices.dropFirst() where Self.drawsBefore(pairs[index], pairs[index - 1]) {
            return false
        }
        return true
    }

    /// Lower `zOrder` first (farther from the camera), then lower `textureID`.
    private static func drawsBefore(_ lhs: (GameObj, Comp), _ rhs: (GameObj, Comp)) -> Bool {
        if lhs.0.zOrder != rhs.0.zOrder { return lhs.0.zOrder < rhs.0.zOrder }
        return lhs.1.textureID < rhs.1.textureID
    }
}
