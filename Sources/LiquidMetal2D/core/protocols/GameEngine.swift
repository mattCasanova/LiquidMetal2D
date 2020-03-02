//
//  GameEngine.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit
 
protocol GameEngine {
    var timer: CADisplayLink! { get set }
    var lastFrameTime: Double  { get set }
    var renderer: Renderer    { get }
    
    var currentSceneType: SceneType { get }
    var nextSceneType: SceneType    { get }
    var currentScene: Scene         { get }
    
    func run()
    func gameLoop(displayLink: CADisplayLink)
    
}

extension GameEngine {
    func resize(scale: CGFloat, layerSize: CGSize) {
        renderer.resize(scale: scale, layerSize: layerSize)
        currentScene.resize()
    }
}
