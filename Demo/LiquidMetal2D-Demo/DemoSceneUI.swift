//
//  DemoSceneUI.swift
//  LiquidMetal2D-Demo
//
//  Shared UI helper for demo scenes. Provides a Menu button
//  in the upper-left corner that pushes the scene menu.
//

import UIKit
import LiquidMetal2D

/// Reusable UI overlay that every demo scene uses to show a "Menu" button.
///
/// **Role in the demo app:**
/// Each demo scene creates a DemoSceneUI in its `initialize()` method, passing the
/// renderer's view as the parent and a target/action for the menu button. The button
/// pushes PauseDemo (the scene menu overlay) onto the scene stack.
///
/// **UIKit on top of Metal:**
/// This is a UIKit layer that sits on top of the Metal rendering view. The engine's
/// `renderer.view` is a `MTKView` subclass, and you can add UIKit subviews to it just
/// like any UIView. The safe area insets are used to avoid notch/status bar overlap.
///
/// **Visibility pattern:**
/// The scene hides this view before pushing PauseDemo (so the button does not appear
/// on top of the menu), and re-shows it in `resume()` when PauseDemo pops.
@MainActor
class DemoSceneUI {
    let view: UIView
    private let menuButton: UIButton

    /// - Parameters:
    ///   - parentView: The renderer's UIView (`renderer.view`), used as the superview.
    ///   - target: The scene instance that handles the button tap (usually `self`).
    ///   - menuAction: A selector on the target, typically `#selector(onMenu)`.
    init(parentView: UIView, target: AnyObject, menuAction: Selector) {
        view = UIView(frame: parentView.safeAreaLayoutGuide.layoutFrame)
        parentView.addSubview(view)

        menuButton = UIButton(frame: .zero)
        menuButton.backgroundColor = TokyoNight.uiDarker
        menuButton.setTitle("Menu", for: .normal)
        menuButton.setTitleColor(TokyoNight.uiBlue, for: .normal)
        menuButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        menuButton.layer.cornerRadius = 6
        menuButton.addTarget(target, action: menuAction, for: .touchUpInside)
        view.addSubview(menuButton)

        layoutButtons()
    }

    /// Recalculate layout after device rotation. Call this from your scene's `resize()`.
    func layout() {
        guard let superview = view.superview else { return }
        view.frame = superview.safeAreaLayoutGuide.layoutFrame
        layoutButtons()
    }

    private func layoutButtons() {
        menuButton.frame = CGRect(x: 8, y: 8, width: 70, height: 36)
    }

    /// Remove the overlay from the view hierarchy. Call this from your scene's `shutdown()`.
    func removeFromSuperview() {
        view.removeFromSuperview()
    }
}
