//
//  SceneData.swift
//  
//
//  Created by Matt Casanova on 3/13/20.
//

public class SceneData {
  public var scene: Scene
  public var type: AnyHashable

  public init(scene: Scene, type: AnyHashable) {
    self.scene = scene
    self.type = type
  }
}
