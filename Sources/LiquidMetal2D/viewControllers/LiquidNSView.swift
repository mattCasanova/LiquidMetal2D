//
//  LiquidNSView.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/1/26.
//

#if canImport(AppKit) && !canImport(UIKit)
import AppKit

/// The Mac host view ``LiquidViewController`` loads. Takes keyboard focus,
/// tells the controller when the window moves to a display with a different
/// backing scale so the Metal layer can follow, and when the view leaves its
/// window for good so the engine can shut down. With ``tracksPointer`` on it
/// reports mouse movement and exit, which the controller turns into pointer
/// events.
public final class LiquidNSView: NSView {
    var onBackingChange: (() -> Void)?
    var onLeaveWindow: (() -> Void)?

    /// Whether the view keeps a tracking area for hover. Set by the
    /// controller when the engine has the pointer device.
    var tracksPointer = false {
        didSet { updateTrackingAreas() }
    }

    /// Whether key events stop here. Set by the controller when the engine
    /// has the keyboard device: the keys reach the engine through
    /// `GCKeyboard`, and letting them fall through the responder chain
    /// would make the system beep on every press. Menu shortcuts are
    /// handled before `keyDown`, so they keep working.
    var swallowsKeyEvents = false

    public override var acceptsFirstResponder: Bool { true }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        onBackingChange?()
    }

    /// Minimising or hiding the window keeps the view in it; only closing the
    /// window or pulling the view out of the hierarchy sends a nil window.
    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            onLeaveWindow?()
        }
    }

    public override func keyDown(with event: NSEvent) {
        if !swallowsKeyEvents { super.keyDown(with: event) }
    }

    public override func keyUp(with event: NSEvent) {
        if !swallowsKeyEvents { super.keyUp(with: event) }
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        guard tracksPointer else { return }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self))
    }
}
#endif
