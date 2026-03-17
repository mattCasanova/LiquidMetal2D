//
//  SceneFactory.swift
//
//
//  Created by Matt Casanova on 3/6/20.
//

/// Registry that maps scene types to their builders.
///
/// Register scenes during setup, then ``SceneManager`` uses `get(_:)` to
/// build scenes on demand during transitions.
///
/// ```swift
/// let factory = SceneFactory()
/// factory.addScene(type: MyScenes.menu, builder: TSceneBuilder<MenuScene>())
/// factory.addScene(type: MyScenes.gameplay, builder: TSceneBuilder<GameplayScene>())
/// ```
public class SceneFactory {

    private var builderMap = [AnyHashable: SceneBuilder]()

    public init() {
    }

    /// Registers a scene builder for the given type.
    public func addScene(type: some SceneType, builder: SceneBuilder) {
        builderMap[AnyHashable(type)] = builder
    }

    /// Removes the builder registered for the given type.
    public func removeScene(_ type: some SceneType) {
        builderMap.removeValue(forKey: AnyHashable(type))
    }

    /// Returns the builder for the given type.
    /// Crashes with a descriptive message if the type was never registered.
    public func get(_ type: any SceneType) -> SceneBuilder {
        guard let builder = builderMap[AnyHashable(type)] else {
            fatalError("No scene registered for type: \(type)")
        }
        return builder
    }
}
