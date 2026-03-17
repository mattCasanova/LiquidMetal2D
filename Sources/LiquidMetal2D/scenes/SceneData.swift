//
//  SceneData.swift
//
//
//  Created by Matt Casanova on 3/13/20.
//

/// Stores a scene and its type identifier for the push/pop stack.
/// Used internally by ``SceneManager`` to save and restore scenes.
public class SceneData {
    public var scene: Scene
    public var type: any SceneType

    public init(scene: Scene, type: any SceneType) {
        self.scene = scene
        self.type = type
    }
}
