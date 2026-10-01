//
//  PlatformTypes.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/30/26.
//

// `UIView` and `NSView` share no base class, so the engine names the host
// platform's view classes through these aliases and guards the few places
// their APIs differ. UIKit is checked first so Mac Catalyst takes the iOS path.
#if canImport(UIKit)
import UIKit
/// The host platform's view class: `UIView` here, `NSView` on the Mac.
public typealias PlatformView = UIView
/// The host platform's view controller: `UIViewController` here, `NSViewController` on the Mac.
public typealias PlatformViewController = UIViewController
#elseif canImport(AppKit)
import AppKit
/// The host platform's view class: `NSView` here, `UIView` on iOS.
public typealias PlatformView = NSView
/// The host platform's view controller: `NSViewController` here, `UIViewController` on iOS.
public typealias PlatformViewController = NSViewController
#else
#error("LiquidMetal2D needs UIKit or AppKit")
#endif
