//
//  SceneFactory.swift
//
//
//  Created by Matt Casanova on 3/6/20.
//

public class SceneFactory {

    private var builderMap = [AnyHashable: SceneBuilder]()

    public init() {
    }

    public func addScene(type: some SceneType, builder: SceneBuilder) {
        builderMap[type] = builder
    }

    public func removeScene(_ type: some SceneType) {
        builderMap.removeValue(forKey: type)
    }

    public func get(_ type: some SceneType) -> SceneBuilder {
        return builderMap[type]!
    }

    public func get(_ type: AnyHashable) -> SceneBuilder {
        return builderMap[type]!
    }
}
