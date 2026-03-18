//
//  SlideDirection.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 3/17/26.
//

/// The direction a ``SlidePanel`` slides in from.
/// Use `.none` to snap into place without animation.
public enum SlideDirection {
    case none
    case left
    case right
    case top
    case bottom
}
