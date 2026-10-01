//
//  LiquidNSView.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/1/26.
//

#if canImport(AppKit) && !canImport(UIKit)
import AppKit

/// The Mac host view ``LiquidViewController`` loads. Takes keyboard focus,
/// and tells the controller when the window moves to a display with a
/// different backing scale so the Metal layer can follow.
public final class LiquidNSView: NSView {
    var onBackingChange: (() -> Void)?

    public override var acceptsFirstResponder: Bool { true }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        onBackingChange?()
    }
}
#endif
