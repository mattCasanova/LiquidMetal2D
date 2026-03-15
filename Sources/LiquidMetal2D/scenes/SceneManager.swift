//
//  SceneManager.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation

public protocol SceneManager: AnyObject {
    func setScene(type: SceneType)
    func pushScene(type: SceneType)
    func popScene()
}
