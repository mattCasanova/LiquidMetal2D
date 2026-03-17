//
//  GameEngine.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/27/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

@MainActor
public protocol GameEngine: InputWriter {
    var timer: CADisplayLink! { get set }
    var lastFrameTime: Double { get set }
    var renderer: Renderer { get }

    var currentSceneType: AnyHashable { get }
    var nextSceneType: AnyHashable { get }
    var currentScene: Scene { get }

    func run()
    func gameLoop(displayLink: CADisplayLink)
}

public extension GameEngine {
    func resize(scale: CGFloat, layerSize: CGSize) {
        renderer.resize(scale: scale, layerSize: layerSize)
        currentScene.resize()
    }
}
