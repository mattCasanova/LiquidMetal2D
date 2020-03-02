//
//  Scene.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation

protocol Scene {
    func initialize(sceneMgr: SceneManager, renderer: Renderer)
    func resize()
    func update(dt: Float)
    func draw()
    func shutdown()
}
