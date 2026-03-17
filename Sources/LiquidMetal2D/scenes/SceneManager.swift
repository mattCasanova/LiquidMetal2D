//
//  SceneManager.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

@MainActor
public protocol SceneManager: AnyObject {
    func setScene(type: some SceneType)
    func pushScene(type: some SceneType)
    func popScene()
}
