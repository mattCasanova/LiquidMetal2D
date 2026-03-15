//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

@MainActor
public protocol SceneBuilder {
  func build() -> Scene
}
