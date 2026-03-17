//
//  TSceneBuilder.swift
//
//
//  Created by Matt Casanova on 3/6/20.
//

/// Generic scene builder that calls the static `build()` method on a
/// concrete ``Scene`` type.
///
/// ```swift
/// factory.addScene(type: MyScenes.menu, builder: TSceneBuilder<MenuScene>())
/// ```
@MainActor
public class TSceneBuilder<T: Scene>: SceneBuilder {

    public init() {}

    /// Builds a new instance by calling `T.build()`.
    public func build() -> Scene {
        return T.self.build()
    }
}
