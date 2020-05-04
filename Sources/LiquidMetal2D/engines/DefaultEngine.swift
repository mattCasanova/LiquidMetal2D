//
//  DefaultSceneManager.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
import simd
import MetalMath

public class DefaultEngine: GameEngine, SceneManager, InputReader {
    private var touchLocation: simd_float2?
    
    public var timer: CADisplayLink!;
    public var lastFrameTime: Double = 0.0
    
    public let renderer: Renderer
    public let sceneFactory: SceneFactory
    
    public var currentSceneType: SceneType
    public var nextSceneType: SceneType
    public var currentScene: Scene
    
    private var isPushing = false
    private var isPoping = false
    private var sceneStack = [SceneData]()
    
    
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
        lastFrameTime = timer.timestamp
        timer.add(to: RunLoop.main, forMode: .default)
    }
    
    @objc public func gameLoop(displayLink: CADisplayLink) {
        let dt: Float = Float(displayLink.timestamp - lastFrameTime)
        lastFrameTime = displayLink.timestamp
        
        guard dt < 5 else { return }
        

        
        if (currentSceneType.value != nextSceneType.value || isPoping) {
            changeScene()
            return
        }
        
        autoreleasepool {
            currentScene.update(dt: dt)
            currentScene.draw()
        }
        
    }
    
    //MARK: InputReader, InputWriter
    public func getWorldTouch(forZ z: Float) -> simd_float3? {
        guard let touch = touchLocation else { return nil }
        return renderer.unproject(screenWithWorldZ: touch.to3D(z))
    }
    
    public func getScreenTouch() -> simd_float2? {
        return touchLocation
    }
    
    public func setTouch(location: simd_float2?) {
        touchLocation = location
    }
    
    
    //MARK: Scene Manager Methods
    public func setScene(type: SceneType) {
        nextSceneType = type
    }
    
    public func pushScene(type: SceneType) {
        isPushing = true
        nextSceneType = type
    }
    
    public func popScene() {
        if !sceneStack.isEmpty {
            isPoping = true
        }
    }
    
    private func changeScene() {
        
        if isPushing {
            sceneStack.append(SceneData(scene: currentScene, type: currentSceneType))
            currentSceneType = nextSceneType
            
            currentScene = sceneFactory.get(currentSceneType).build()
            currentScene.initialize(sceneMgr: self, renderer: renderer, input: self)
        } else if isPoping {
            
            guard let sceneData = sceneStack.popLast() else { return }
            
            currentScene.shutdown()
            currentScene = sceneData.scene
            currentSceneType = sceneData.type
            nextSceneType = currentSceneType
            
            currentScene.resume()
        } else {
            currentSceneType = nextSceneType
            currentScene.shutdown()
            currentScene = sceneFactory.get(currentSceneType).build()
            currentScene.initialize(sceneMgr: self, renderer: renderer, input: self)
        }
        
        
        isPushing = false
        isPoping = false
    }
    
    
}
