//
//  TexturedComponent.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/22/26.
//

/// A render component that samples one texture. ``DrawList`` sorts by this
/// so consecutive instances sharing a texture batch into one draw call.
public protocol TexturedComponent: Component {
    /// The texture this component samples, as returned by
    /// `renderer.loadTextures(_:)` or a built-in default texture id.
    var textureID: Int { get }
}
