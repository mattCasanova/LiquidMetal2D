//
//  TSceneBuilder.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

public class TSceneBuilder<T: Scene>: SceneBuilder {
  
  public init() {  }
  
  public func build() -> Scene {
    return T.self.build()
  }
}
