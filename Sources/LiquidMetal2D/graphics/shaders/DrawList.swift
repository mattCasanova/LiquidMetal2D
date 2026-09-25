//
//  DrawList.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/22/26.
//

/// The objects one shader draws this frame, in draw order.
///
/// ``rebuild(from:)`` collects the active objects that carry `Comp` and
/// sorts them by the list's ``Order``:
///
/// - ``Order/farToNear`` (default): `(zOrder, textureID)`. Ascending
///   `zOrder` is far-to-near for this engine's camera (it sits at
///   `z = distance` looking down −z), which "over" blending needs; grouping
///   by texture within a z level lets consecutive instances batch.
/// - ``Order/byTexture``: `textureID` only, for order-independent blending
///   (additive). Every object sharing a texture lands in one instanced draw.
///
/// The array keeps its capacity between frames. When the objects arrive
/// already in draw order (the common case for a steady scene), the sort is
/// skipped, so a steady frame allocates nothing. Otherwise the standard
/// library's stable sort allocates a scratch buffer for that frame.
public struct DrawList<Comp: TexturedComponent> {
    public enum Order: Sendable {
        /// Ascending `zOrder`, then `textureID`. For "over" blending.
        case farToNear
        /// `textureID` only. For blending where draw order doesn't change the result.
        case byTexture
    }

    public let order: Order

    /// This frame's `(object, component)` pairs in draw order. Empty
    /// between frames once the shader calls ``clear()``.
    public private(set) var pairs: [(GameObj, Comp)] = []

    public init(order: Order = .farToNear) {
        self.order = order
    }

    /// Replaces the list with the active objects in `objects` that carry
    /// `Comp`, in draw order.
    public mutating func rebuild(from objects: [GameObj]) {
        pairs.removeAll(keepingCapacity: true)
        for obj in objects where obj.isActive {
            guard let comp = obj.get(Comp.self) else { continue }
            pairs.append((obj, comp))
        }
        if !isInDrawOrder() {
            pairs.sort(by: drawsBefore)
        }
    }

    /// Drops this frame's references, keeping the capacity. Call once the
    /// uniforms are written so a popped scene's objects aren't held until
    /// the next frame.
    public mutating func clear() {
        pairs.removeAll(keepingCapacity: true)
    }

    private func isInDrawOrder() -> Bool {
        for index in pairs.indices.dropFirst() where drawsBefore(pairs[index], pairs[index - 1]) {
            return false
        }
        return true
    }

    private func drawsBefore(_ lhs: (GameObj, Comp), _ rhs: (GameObj, Comp)) -> Bool {
        switch order {
        case .farToNear:
            if lhs.0.zOrder != rhs.0.zOrder { return lhs.0.zOrder < rhs.0.zOrder }
            return lhs.1.textureID < rhs.1.textureID
        case .byTexture:
            return lhs.1.textureID < rhs.1.textureID
        }
    }
}
