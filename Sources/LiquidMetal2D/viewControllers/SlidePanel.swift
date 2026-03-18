//
//  SlidePanel.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 3/17/26.
//

import UIKit

/// A UIView container that slides in from a screen edge.
///
/// Add your UI elements to ``contentView``, then call ``slideIn()``
/// to animate them on screen. Call ``slideOut(completion:)`` to animate
/// them off and run a callback (e.g., pop the scene).
///
/// ```swift
/// let panel = SlidePanel(
///     parentView: renderer.view,
///     direction: .bottom,
///     duration: 0.35)
///
/// panel.contentView.addSubview(myLabel)
/// panel.slideIn()
///
/// // Later:
/// panel.slideOut { sceneMgr.popScene() }
/// ```
@MainActor
public class SlidePanel {
    /// The view to add your UI elements to.
    public let contentView: UIView

    private let parentView: UIView
    private let direction: SlideDirection
    private let duration: TimeInterval

    /// Creates a slide panel and adds it to the parent view.
    ///
    /// - Parameters:
    ///   - parentView: The view to attach the panel to.
    ///   - direction: The edge to slide in from. `.none` snaps into place.
    ///   - duration: Animation duration in seconds. Ignored when direction is `.none`.
    public init(parentView: UIView, direction: SlideDirection, duration: TimeInterval = 0.35) {
        self.parentView = parentView
        self.direction = direction
        self.duration = duration

        contentView = UIView(frame: parentView.bounds)
        contentView.backgroundColor = .clear

        if direction != .none {
            contentView.frame.origin = offScreenOrigin()
        }

        parentView.addSubview(contentView)
    }

    /// Animates the content view on screen from the configured direction.
    public func slideIn() {
        guard direction != .none else { return }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseOut
        ) {
            self.contentView.frame.origin = .zero
        }
    }

    /// Animates the content view off screen, then calls the completion handler.
    /// - Parameter completion: Called after the animation finishes.
    public func slideOut(completion: @escaping () -> Void) {
        guard direction != .none else {
            completion()
            return
        }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseIn,
            animations: {
                self.contentView.frame.origin = self.offScreenOrigin()
            },
            completion: { _ in completion() }
        )
    }

    /// Removes the content view from its parent.
    public func removeFromSuperview() {
        contentView.removeFromSuperview()
    }

    /// Updates the content view frame after a layout change (e.g., rotation).
    public func layout() {
        contentView.frame = parentView.bounds
    }

    private func offScreenOrigin() -> CGPoint {
        let bounds = parentView.bounds
        switch direction {
        case .none:   return .zero
        case .left:   return CGPoint(x: -bounds.width, y: 0)
        case .right:  return CGPoint(x: bounds.width, y: 0)
        case .top:    return CGPoint(x: 0, y: -bounds.height)
        case .bottom: return CGPoint(x: 0, y: bounds.height)
        }
    }
}
