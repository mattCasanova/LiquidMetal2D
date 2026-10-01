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
/// window for good so the engine can shut down.
public final class LiquidNSView: NSView {
    var onBackingChange: (() -> Void)?
    var onLeaveWindow: (() -> Void)?

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
}
#endif
