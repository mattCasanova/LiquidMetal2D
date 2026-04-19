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
public final class AlphaBlendComponent: Component {
    public unowned var parent: GameObj
    public var textureID: Int
    public var tintColor: Vec4
    public var texTrans: Vec4

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

    /// Fill an ``AlphaBlendUniform`` from this component's fields combined
    /// with the parent's transform. Called by ``AlphaBlendShader`` per draw.
    func fillUniform(_ uniform: AlphaBlendUniform) {
        uniform.transform.setToTransform2D(
            scale: parent.scale,
            angle: parent.rotation,
            translate: Vec3(parent.position, parent.zOrder))
        uniform.texTrans = texTrans
        uniform.color = tintColor
    }
}
