//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

public class SceneFactory {
  
  private var builderMap = [Int:SceneBuilder]()

  public init() {
    
  }
  
  public func addScene(type: SceneType, builder: SceneBuilder) {
    builderMap[type.value] = builder
  }
  
  public func removeScene(_ type: SceneType) {
    builderMap.removeValue(forKey: type.value)
  }
  
  public func get(_ type: SceneType) -> SceneBuilder {
    return builderMap[type.value]!
  }
  
}
