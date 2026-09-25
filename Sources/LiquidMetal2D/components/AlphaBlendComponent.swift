//
//  AlphaBlendComponent.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Foundation

/// Render state for the alpha-blend shader. Attach to any ``GameObj`` that
/// should render via ``AlphaBlendShader``.
///
/// A GameObj without an ``AlphaBlendComponent`` is silently skipped by
/// ``AlphaBlendShader/submit(objects:)`` — attach additional render
/// components (e.g., a future wireframe component) to render the same
/// object through multiple shaders.
public final class AlphaBlendComponent: TexturedComponent {
    public unowned let parent: GameObj
    // Plain values read every frame: no run-time exclusivity check (see GameObj).
    @exclusivity(unchecked) public var textureID: Int
    @exclusivity(unchecked) public var tintColor: Vec4
    @exclusivity(unchecked) public var texTrans: Vec4

    public init(
        parent: GameObj,
        textureID: Int,
        tintColor: Vec4 = Vec4(1, 1, 1, 1),
        texTrans: Vec4 = Vec4(1, 1, 0, 0)
    ) {
        self.parent = parent
        self.textureID = textureID
        self.tintColor = tintColor
        self.texTrans = texTrans
    }

    /// The ``AlphaBlendUniform`` for this component combined with the
    /// parent's transform. Called by ``AlphaBlendShader`` per draw.
    func makeUniform() -> AlphaBlendUniform {
        return AlphaBlendUniform(
            transform: Mat4.makeTransform2D(
                scale: parent.scale,
                angle: parent.rotation,
                translate: Vec3(parent.position, parent.zOrder)),
            texTrans: texTrans,
            color: tintColor)
    }
}
