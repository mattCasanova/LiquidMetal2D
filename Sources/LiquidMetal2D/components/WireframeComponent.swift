//
//  WireframeComponent.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Foundation

/// Render state for ``WireframeShader``. Attach to any ``GameObj`` that
/// should render an outline of its ``Collider``.
///
/// The shape is derived at submit time from the parent's attached
/// ``Collider`` (currently ``CircleCollider`` and ``AABBCollider`` are
/// supported). Objects without a collider or with an unsupported collider
/// type are silently skipped by ``WireframeShader/submit(objects:)``.
///
/// Mutate ``color`` at runtime to signal state changes (e.g., turn red on
/// collision, green when clear). The shader reads the field every frame.
public final class WireframeComponent: Component {
    public unowned var parent: GameObj
    public var color: Vec4
    /// Outline thickness in UV space (fraction of the shape's size).
    /// Typical values: 0.02..0.08. Clamp to (0, 0.5).
    public var thickness: Float

    public init(
        parent: GameObj,
        color: Vec4 = Vec4(0, 1, 0, 1),
        thickness: Float = 0.05
    ) {
        self.parent = parent
        self.color = color
        self.thickness = thickness
    }
}
