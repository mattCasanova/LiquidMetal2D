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
/// forwards layout changes and input to ``gameEngine``, and shuts the
/// engine down when the view goes away. The AppKit build has a class of the
/// same name and API, so a game's subclass compiles on both platforms.
///
/// Input reaches the engine as ``RawInputEvent``s in top-left screen
/// coordinates: every finger as a touch point (the first is the pointer and
/// `pointerPrimary`), and an iPad trackpad or mouse hover as the pointer with
/// no button. Installed only when the engine has the pointer device.
open class LiquidViewController: UIViewController {
    public var gameEngine: GameEngine! {
        didSet { installInputSources() }
    }

    private var hover: UIHoverGestureRecognizer?

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let scale = view.window?.screen.nativeScale ?? traitCollection.displayScale
        gameEngine.resize(scale: scale, layerSize: view.bounds.size)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        gameEngine?.shutdown()
    }

    // MARK: - Pointer source

    private var hasPointer: Bool {
        // No engine yet means nothing to feed; the subclass's viewDidLoad makes it.
        gameEngine?.inputDevices.contains(.pointer) ?? false
    }

    private func installInputSources() {
        guard hasPointer else { return }
        view.isMultipleTouchEnabled = true
        if hover == nil {
            let recognizer = UIHoverGestureRecognizer(target: self, action: #selector(onHover(_:)))
            view.addGestureRecognizer(recognizer)
            hover = recognizer
        }
    }

    @objc private func onHover(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            gameEngine.enqueue(.pointerMoved(screenPoint(recognizer.location(in: view))))
        case .ended, .cancelled, .failed:
            gameEngine.enqueue(.pointerMoved(nil))
        case .possible:
            break
        @unknown default:
            break
        }
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard hasPointer else { return }
        for touch in touches {
            gameEngine.enqueue(.touchBegan(id: touchID(touch), screenPoint(touch.location(in: view))))
        }
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard hasPointer else { return }
        for touch in touches {
            gameEngine.enqueue(.touchMoved(id: touchID(touch), screenPoint(touch.location(in: view))))
        }
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        endTouches(touches)
    }

    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        guard hasPointer else { return }
        for touch in touches {
            gameEngine.enqueue(.touchEnded(id: touchID(touch)))
        }
    }

    /// The `UITouch` object stands for one finger from began to ended, so
    /// its identity is the id. UIKit may reuse the object for a later finger,
    /// after this one has ended.
    private func touchID(_ touch: UITouch) -> Int {
        Int(bitPattern: ObjectIdentifier(touch))
    }

    private func screenPoint(_ point: CGPoint) -> Vec2 {
        Vec2(Float(point.x), Float(point.y))
    }
}

#elseif canImport(AppKit)
import AppKit

/// The view controller a game subclasses. It owns the engine's host view
/// (a ``LiquidNSView``), forwards layout changes and input to
/// ``gameEngine``, and shuts the engine down when the view leaves its
/// window. The UIKit build has a class of the same name and API, so a
/// game's subclass compiles on both platforms.
///
/// Input reaches the engine as ``RawInputEvent``s in top-left screen
/// coordinates, as on iOS: the mouse is the pointer (hover included), its
/// buttons are `pointerPrimary`, `pointerSecondary` and `pointerMiddle`, and
/// the scroll wheel is `scroll`. Installed only when the engine has the
/// pointer device.
open class LiquidViewController: NSViewController {
    public var gameEngine: GameEngine! {
        didSet { installInputSources() }
    }

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

    // MARK: - Pointer source

    private var hasPointer: Bool {
        // No engine yet means nothing to feed; the subclass's viewDidLoad makes it.
        gameEngine?.inputDevices.contains(.pointer) ?? false
    }

    private func installInputSources() {
        guard hasPointer, let liquidView = view as? LiquidNSView else { return }
        liquidView.tracksPointer = true
    }

    open override func mouseEntered(with event: NSEvent) { movePointer(event) }
    open override func mouseMoved(with event: NSEvent) { movePointer(event) }
    open override func mouseDragged(with event: NSEvent) { movePointer(event) }
    open override func rightMouseDragged(with event: NSEvent) { movePointer(event) }
    open override func otherMouseDragged(with event: NSEvent) { movePointer(event) }

    open override func mouseExited(with event: NSEvent) {
        guard hasPointer else { return }
        gameEngine.enqueue(.pointerMoved(nil))
    }

    open override func mouseDown(with event: NSEvent) { press(.pointerPrimary, event) }
    open override func mouseUp(with event: NSEvent) { release(.pointerPrimary, event) }
    open override func rightMouseDown(with event: NSEvent) { press(.pointerSecondary, event) }
    open override func rightMouseUp(with event: NSEvent) { release(.pointerSecondary, event) }
    open override func otherMouseDown(with event: NSEvent) { press(.pointerMiddle, event) }
    open override func otherMouseUp(with event: NSEvent) { release(.pointerMiddle, event) }

    open override func scrollWheel(with event: NSEvent) {
        guard hasPointer else { return }
        gameEngine.enqueue(.scroll(Vec2(Float(event.scrollingDeltaX), Float(event.scrollingDeltaY))))
    }

    private func movePointer(_ event: NSEvent) {
        guard hasPointer else { return }
        gameEngine.enqueue(.pointerMoved(screenPoint(event)))
    }

    private func press(_ code: InputCode, _ event: NSEvent) {
        guard hasPointer else { return }
        gameEngine.enqueue(.pointerMoved(screenPoint(event)))
        gameEngine.enqueue(.down(code))
    }

    private func release(_ code: InputCode, _ event: NSEvent) {
        guard hasPointer else { return }
        gameEngine.enqueue(.pointerMoved(screenPoint(event)))
        gameEngine.enqueue(.up(code))
    }

    private func screenPoint(_ event: NSEvent) -> Vec2 {
        let point = view.convert(event.locationInWindow, from: nil)
        // AppKit's origin is bottom-left; the engine's screen space is top-left.
        return Vec2(Float(point.x), Float(view.bounds.height - point.y))
    }
}
#endif
