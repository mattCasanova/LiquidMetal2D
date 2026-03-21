/// Registry that maps scene types to scene classes.
///
/// Each ``Scene`` declares a static `sceneType` property. Register scenes
/// by passing the class itself — the factory reads the type automatically.
///
/// ```swift
/// let factory = SceneFactory()
/// factory.addScenes([
///     MenuScene.self,
///     GameplayScene.self,
///     GameOverScene.self,
/// ])
/// ```
@MainActor
public class SceneFactory {

    private var sceneMap = [AnyHashable: Scene.Type]()

    public init() {}

    /// Registers a single scene class. The scene's `sceneType` is used as the key.
    public func addScene(_ sceneClass: Scene.Type) {
        sceneMap[AnyHashable(sceneClass.sceneType)] = sceneClass
    }

    /// Registers multiple scene classes at once.
    public func addScenes(_ sceneClasses: [Scene.Type]) {
        for sceneClass in sceneClasses {
            addScene(sceneClass)
        }
    }

    /// Removes the scene registered for the given type.
    public func removeScene(_ type: some SceneType) {
        sceneMap.removeValue(forKey: AnyHashable(type))
    }

    /// Builds a new instance of the scene registered for the given type.
    /// Crashes if the type was never registered.
    func build(_ type: any SceneType) -> Scene {
        guard let sceneClass = sceneMap[AnyHashable(type)] else {
            fatalError("No scene registered for type: \(type)")
        }
        return sceneClass.build()
    }
}
