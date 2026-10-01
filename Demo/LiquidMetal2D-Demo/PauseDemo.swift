//
//  PauseDemo.swift
//  LiquidMetal2D-Demo
//
//  Scene menu overlay. Slides in from the left with a table view
//  of all available scenes. Tap to switch, or Resume to go back.
//

import UIKit
import LiquidMetal2D

/// Menu overlay scene pushed on top of the current game scene.
///
/// **What the user sees:** A dark semi-transparent overlay covers the screen, and a panel
/// slides in from the left containing a "Resume" button and a list of all demo scenes.
/// Tapping Resume slides the panel out and pops this scene, returning to the previous scene.
/// Tapping a scene name slides out and switches to that scene.
///
/// **Engine features demonstrated:**
/// - **Scene stacking (push/pop):** This scene is *pushed* on top of the current scene using
///   `sceneMgr.pushScene(type:)`. The underlying scene is NOT destroyed -- it remains on the
///   scene stack. Calling `sceneMgr.popScene()` removes this overlay and calls `resume()` on
///   the scene underneath, restoring it seamlessly.
/// - **setScene vs pushScene:** `sceneMgr.setScene(type:)` replaces the entire scene stack
///   (shuts down all stacked scenes). `pushScene` adds on top. This demo uses setScene for
///   scene navigation and popScene for resume.
/// - **SlidePanel:** A library UI component that animates a content view in/out from an edge.
///   `SlidePanel(parentView:direction:duration:)` creates it, `slideIn()` and
///   `slideOut(completion:)` animate the entrance and exit. The completion callback is where
///   you perform the scene transition, ensuring the animation finishes before switching.
/// - **Scene lifecycle:** This scene has empty `update()` and `draw()` methods because it is
///   a pure UI overlay -- no game objects to simulate or render.
/// **Why NSObject?** PauseDemo conforms to UITableViewDataSource and UITableViewDelegate,
/// which are Objective-C protocols that require NSObject inheritance.
class PauseDemo: NSObject, Scene {
    static var sceneType: any SceneType { SceneTypes.pauseDemo }

    private var sceneMgr: SceneManager!
    private var renderer: Renderer!
    private var input: InputReader!

    private var overlayView: UIView!
    private var slidePanel: SlidePanel!
    private var tableView: UITableView!

    /// The list of scenes available for navigation (excludes pauseDemo itself)
    private let scenes = SceneTypes.navigable
    private let cellId = "SceneCell"

    /// Scene protocol: called once when this overlay scene is pushed onto the stack.
    func initialize(services: SceneServices) {
        self.sceneMgr = services.sceneMgr
        self.renderer = services.renderer
        self.input = services.input

        // Semi-transparent dark overlay that dims the scene underneath
        overlayView = UIView(frame: renderer.view.bounds)
        overlayView.backgroundColor = TokyoNight.uiBg.withAlphaComponent(0.8)
        renderer.view.addSubview(overlayView)

        // SlidePanel animates a content view from the specified edge.
        // .left means it slides in from the left side of the screen.
        slidePanel = SlidePanel(
            parentView: renderer.view,
            direction: .left,
            duration: 0.3)

        buildMenuUI()
        // Trigger the slide-in animation after setup is complete
        slidePanel.slideIn()
    }

    /// Scene protocol: not used by this scene since nothing can push on top of it.
    func resume() {}

    /// Scene protocol: called on device rotation. Resize the overlay and panel.
    func resize() {
        overlayView.frame = renderer.view.bounds
        // SlidePanel.layout() recalculates the panel frame for the new screen size
        slidePanel.layout()
        layoutMenuUI()
    }

    // No game logic to update in a pure UI overlay scene
    func update(dt: Float) {}
    // No game objects to draw -- the underlying scene's last frame is still visible
    func draw() {}

    /// Scene protocol: clean up UI elements. Called when this scene is popped or replaced.
    func shutdown() {
        slidePanel.removeFromSuperview()
        overlayView.removeFromSuperview()
    }

    // MARK: - Menu UI

    private func buildMenuUI() {
        // slidePanel.contentView is the panel's drawable area where you add your UI
        let content = slidePanel.contentView

        var resumeConfig = UIButton.Configuration.plain()
        resumeConfig.title = "Resume"
        resumeConfig.baseForegroundColor = TokyoNight.uiBlue
        resumeConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0)
        let resumeButton = UIButton(configuration: resumeConfig)
        resumeButton.contentHorizontalAlignment = .left
        resumeButton.addTarget(self, action: #selector(onResume), for: .touchUpInside)
        resumeButton.tag = 100
        content.addSubview(resumeButton)

        tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellId)
        content.addSubview(tableView)

        layoutMenuUI()
    }

    private func layoutMenuUI() {
        let content = slidePanel.contentView
        let safeArea = renderer.view.safeAreaInsets
        let topPadding = safeArea.top + 16
        let fullWidth = content.bounds.width

        if let resumeButton = content.viewWithTag(100) {
            resumeButton.frame = CGRect(
                x: 0, y: topPadding,
                width: fullWidth, height: 44)
        }

        tableView.frame = CGRect(
            x: 0, y: topPadding + 52,
            width: fullWidth,
            height: content.bounds.height - topPadding - 52)
    }

    /// Resume: slide the panel out, then pop this scene off the stack.
    /// popScene returns to the previous scene and calls its resume() method.
    @objc func onResume() {
        slidePanel.slideOut { [weak self] in
            self?.sceneMgr.popScene()
        }
    }

    /// Navigate to a different scene: slide out, then setScene which replaces the
    /// entire scene stack (shuts down this overlay AND the scene underneath).
    private func selectScene(_ sceneType: SceneTypes) {
        slidePanel.slideOut { [weak self] in
            self?.sceneMgr.setScene(type: sceneType)
        }
    }

    /// Required factory method for TSceneBuilder.
    static func build() -> Scene { return PauseDemo() }
}

// MARK: - UITableViewDataSource & Delegate
// Standard UIKit table view pattern for displaying the list of navigable scenes.

extension PauseDemo: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scenes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        // SceneTypes.title provides a human-readable name for each scene
        cell.textLabel?.text = scenes[indexPath.row].title
        cell.textLabel?.textColor = TokyoNight.uiFg
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        let selectedView = UIView()
        selectedView.backgroundColor = TokyoNight.uiDarker
        cell.selectedBackgroundView = selectedView
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectScene(scenes[indexPath.row])
    }
}
