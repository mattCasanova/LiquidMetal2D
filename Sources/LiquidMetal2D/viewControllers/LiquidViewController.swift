//
//  LiquidViewController.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/3/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

/// The view controller a game subclasses. It owns the engine's host view,
/// forwards layout changes and pointer input to ``gameEngine``, and shuts
/// the engine down when the view goes away. One class per platform, same
/// name and API, so a game's subclass compiles on both.
///
/// On the Mac a mouse drag acts as a touch. Pointer locations reach the
/// engine in top-left screen coordinates on both platforms.
#if canImport(UIKit)
import UIKit

open class LiquidViewController: UIViewController {
    public var gameEngine: GameEngine!

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let scale = view.window?.screen.nativeScale ?? traitCollection.displayScale
        gameEngine.resize(scale: scale, layerSize: view.bounds.size)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        gameEngine?.shutdown()
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        guard let raw = touches.first?.location(in: self.view) else {
            gameEngine.setTouch(location: nil)
            return
        }

        gameEngine.setTouch(location: Vec2(Float(raw.x), Float(raw.y)))
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        gameEngine.setTouch(location: nil)
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let raw = touches.first?.location(in: self.view) else {
            gameEngine.setTouch(location: nil)
            return
        }

        gameEngine.setTouch(location: Vec2(Float(raw.x), Float(raw.y)))
    }
}

#elseif canImport(AppKit)
import AppKit

open class LiquidViewController: NSViewController {
    public var gameEngine: GameEngine!

    open override func loadView() {
        let liquidView = LiquidNSView()
        liquidView.onBackingChange = { [weak self] in self?.resizeEngine() }
        view = liquidView
    }

    open override func viewDidLayout() {
        super.viewDidLayout()
        resizeEngine()
    }

    open override func viewWillDisappear() {
        super.viewWillDisappear()
        gameEngine?.shutdown()
    }

    /// Resizes the engine to the view at the window's backing scale.
    /// Before the view has a window there is no scale to use; the layout
    /// pass after it gets one calls this again.
    func resizeEngine() {
        guard let scale = view.window?.backingScaleFactor else { return }
        // Layout can run before the subclass's `viewDidLoad` makes the engine.
        gameEngine?.resize(scale: scale, layerSize: view.bounds.size)
    }

    open override func mouseDown(with event: NSEvent) {
        setTouch(from: event)
    }

    open override func mouseDragged(with event: NSEvent) {
        setTouch(from: event)
    }

    open override func mouseUp(with event: NSEvent) {
        gameEngine.setTouch(location: nil)
    }

    private func setTouch(from event: NSEvent) {
        let point = view.convert(event.locationInWindow, from: nil)
        // AppKit's origin is bottom-left; the engine's screen space is top-left.
        gameEngine.setTouch(location: Vec2(Float(point.x), Float(view.bounds.height - point.y)))
    }
}
#endif
