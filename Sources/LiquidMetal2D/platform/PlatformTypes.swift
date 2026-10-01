//
//  PlatformTypes.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/30/26.
//

/// The host platform's view and view-controller classes.
///
/// `UIView` and `NSView` share no base class, so the engine names them
/// through these aliases and guards the few places their APIs differ.
/// UIKit is checked first so Mac Catalyst takes the iOS path.
#if canImport(UIKit)
import UIKit
public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
#elseif canImport(AppKit)
import AppKit
public typealias PlatformView = NSView
public typealias PlatformViewController = NSViewController
#else
#error("LiquidMetal2D needs UIKit or AppKit")
#endif
