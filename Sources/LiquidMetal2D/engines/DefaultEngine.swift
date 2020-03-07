//
//  DefaultSceneManager.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

public class DefaultEngine: GameEngine, SceneManager {
  
  private let mInput = Input()
  
  public var timer: CADisplayLink! = nil
  public var lastFrameTime: Double = 0.0
  
  public var renderer: Renderer
  public var sceneFactory: SceneFactory
  
  public var currentSceneType: SceneType
  public var nextSceneType: SceneType
  public var currentScene: Scene

  public var input: InputSetter { get { mInput } }
  
  
  public init(renderer: Renderer, intitialSceneType: SceneType, sceneFactory: SceneFactory) {
    currentSceneType = intitialSceneType
    nextSceneType = intitialSceneType
    
    self.renderer = renderer
    self.sceneFactory = sceneFactory
    
    currentScene = sceneFactory.get(intitialSceneType).build()
    currentScene.initialize(sceneMgr: self, renderer: renderer, input: mInput)
  }
  
  public func run() {
    timer = CADisplayLink(target: self, selector: #selector(gameLoop(displayLink:)))
    timer.add(to: RunLoop.main, forMode: .default)
    lastFrameTime = timer.timestamp
  }
  
  @objc public func gameLoop(displayLink: CADisplayLink) {
    let dt: Float = Float(displayLink.timestamp - lastFrameTime)
    lastFrameTime = displayLink.timestamp
    
    autoreleasepool {
      currentScene.update(dt: dt)
      currentScene.draw()
    }
    
  }
  
  
  public func setScene(type: SceneType) {
    
  }
  
  public func pushScene(type: SceneType) {
    
  }
  
  public func popScene() {
    
  }
  
  
}
