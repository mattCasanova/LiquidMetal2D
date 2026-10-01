//
//  FrameClock.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/1/26.
//

import QuartzCore

/// Calls back once per display refresh.
///
/// ``DefaultEngine`` steps its loop from one. ``DisplayLinkClock`` is the
/// platform display link; tests substitute a fake that sets ``timestamp``
/// and fires the callback by hand.
@MainActor
public protocol FrameClock: AnyObject {
    /// Time of the latest callback, in seconds on the clock's own base.
    /// Read it only after ``start(onFrame:)``.
    var timestamp: Double { get }

    /// Starts calling `onFrame` every refresh until ``stop()``.
    func start(onFrame: @escaping @MainActor () -> Void)

    /// Stops the callbacks and drops `onFrame`.
    func stop()
}

/// The platform display link, made for a view so it follows that view's
/// display. The one place the engine makes a `CADisplayLink`.
@MainActor
public final class DisplayLinkClock: FrameClock {
    private let view: PlatformView
    private var link: CADisplayLink?
    private var onFrame: (@MainActor () -> Void)?

    public init(view: PlatformView) {
        self.view = view
    }

    public var timestamp: Double {
        guard let link else {
            preconditionFailure("DisplayLinkClock.timestamp read before start()")
        }
        return link.timestamp
    }

    public func start(onFrame: @escaping @MainActor () -> Void) {
        precondition(link == nil, "DisplayLinkClock.start called while running")
        self.onFrame = onFrame
        let link = makeLink()
        // `.common` keeps frames coming while a scroll view or menu tracks.
        link.add(to: RunLoop.main, forMode: .common)
        self.link = link
    }

    public func stop() {
        link?.invalidate()
        link = nil
        onFrame = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        onFrame?()
    }

    private func makeLink() -> CADisplayLink {
        #if canImport(UIKit)
        return CADisplayLink(target: self, selector: #selector(tick))
        #elseif canImport(AppKit)
        return view.displayLink(target: self, selector: #selector(tick))
        #endif
    }
}
