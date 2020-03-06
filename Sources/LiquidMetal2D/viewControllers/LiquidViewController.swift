//
//  ViewController.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/3/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import UIKit

open class LiquidViewController: UIViewController {

    public var gameEngine: GameEngine!
    
  open override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification,
        object: nil,
        queue: .main,
        using: didRotate)
    
    }
    
  open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard let window = view.window else { return }
        gameEngine.resize(scale: window.screen.nativeScale, layerSize: view.bounds.size)
    }
    
    open func didRotate(_ notification: Notification) {
        guard let window = view.window else { return }
        gameEngine.resize(scale: window.screen.nativeScale, layerSize: view.bounds.size)
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
}


