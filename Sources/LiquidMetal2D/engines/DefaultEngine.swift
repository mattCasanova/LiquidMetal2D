//
//  DefaultSceneManager.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
import MetalMath

public class DefaultEngine: GameEngine, SceneManager, InputReader {
  
  private var touchLocation: Vector2D?
  
  public var timer: CADisplayLink! = nil
  public var lastFrameTime: Double = 0.0
  
  public var renderer: Renderer
  public var sceneFactory: SceneFactory
  
  public var currentSceneType: SceneType
  public var nextSceneType: SceneType
  public var currentScene: Scene
  
  
  public init(renderer: Renderer, intitialSceneType: SceneType, sceneFactory: SceneFactory) {
    currentSceneType = intitialSceneType
    nextSceneType = intitialSceneType
    
    self.renderer = renderer
    self.sceneFactory = sceneFactory
    
    currentScene = sceneFactory.get(intitialSceneType).build()
    currentScene.initialize(sceneMgr: self, renderer: renderer, input: self)
  }
  
  public func run() {
    timer = CADisplayLink(target: self, selector: #selector(gameLoop(displayLink:)))
    timer.add(to: RunLoop.main, forMode: .default)
    lastFrameTime = timer.timestamp
  }
  
  @objc public func gameLoop(displayLink: CADisplayLink) {
    let dt: Float = Float(displayLink.timestamp - lastFrameTime)
    lastFrameTime = displayLink.timestamp
    
    if (currentSceneType.value != nextSceneType.value) {
      changeScene()
      return
    }
    
    autoreleasepool {
      currentScene.update(dt: dt)
      currentScene.draw()
    }
    
  }
  
  //MARK: InputReader, InputWriter
  public func getWorldTouch() -> Vector2D? {
    guard let touch = touchLocation else { return nil }
    return Vector2D(vector3D: renderer.unProject(screenCoordinate: touch))
  }
  
  public func getScreenTouch() -> Vector2D? {
    return touchLocation
  }
  
  public func setTouch(location: Vector2D?) {
    touchLocation = location
  }
  
  
  //MARK: Scene Manager Methods
  public func setScene(type: SceneType) {
    nextSceneType = type
  }
  
  public func pushScene(type: SceneType) {
    
  }
  
  public func popScene() {
    
  }
  
  private func changeScene() {
    currentScene.shutdown()
    currentSceneType = nextSceneType
    currentScene = sceneFactory.get(currentSceneType).build()
    currentScene.initialize(sceneMgr: self, renderer: renderer, input: self)
  }
  
  
}
