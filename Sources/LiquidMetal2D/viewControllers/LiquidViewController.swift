//
//  LiquidViewController.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/3/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

#if canImport(UIKit)
import UIKit

/// The view controller a game subclasses. It owns the engine's host view,
/// forwards layout changes and touches to ``gameEngine``, and shuts the
/// engine down when the view goes away. The AppKit build has a class of the
/// same name and API, so a game's subclass compiles on both platforms.
///
/// Touch locations reach the engine in top-left screen coordinates.
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

/// The view controller a game subclasses. It owns the engine's host view
/// (a ``LiquidNSView``), forwards layout changes and mouse input to
/// ``gameEngine``, and shuts the engine down when the view leaves its
/// window. The UIKit build has a class of the same name and API, so a
/// game's subclass compiles on both platforms.
///
/// A mouse drag acts as a touch. Locations reach the engine in top-left
/// screen coordinates, as on iOS.
open class LiquidViewController: NSViewController {
    public var gameEngine: GameEngine!

    open override func loadView() {
        let liquidView = LiquidNSView()
        liquidView.onBackingChange = { [weak self] in self?.resizeEngine() }
        // Not `viewWillDisappear`: AppKit sends that whenever the window is
        // ordered out, so minimising or hiding would kill the game.
        liquidView.onLeaveWindow = { [weak self] in self?.gameEngine?.shutdown() }
        view = liquidView
    }

    open override func viewDidLayout() {
        super.viewDidLayout()
        resizeEngine()
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
