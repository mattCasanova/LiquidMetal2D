//
//  SceneTypes.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/8/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation
import LiquidMetal2D

/// Defines all scene types in the app by conforming to the engine's `SceneType` protocol.
///
/// **How scene types work in LiquidMetal2D:**
/// The engine identifies scenes by `SceneType` values. You define your own enum conforming
/// to `SceneType`. Each scene class declares a `static var sceneType` returning its case,
/// so the factory can register and build scenes automatically.
///
/// **Registration flow:**
/// 1. Define your enum cases here
/// 2. Each scene class sets `static var sceneType` to its case
/// 3. In ViewController, call `sceneFactory.addScenes([MyScene.self, ...])`
/// 4. In your scenes, call `sceneMgr.setScene(type:)` or `sceneMgr.pushScene(type:)` to navigate
///
/// The `title` property provides human-readable names used by the PauseDemo menu.
/// The `navigable` list controls which scenes appear in the menu (excludes pauseDemo
/// since it is a push-only overlay, not a standalone scene).
enum SceneTypes: SceneType {
    case massRenderDemo
    case touchZoomDemo
    case instanceDemo
    case schedulerDemo
    case spawnDemo
    case collisionDemo
    case collisionStressDemo
    case bezierDemo
    case cameraRotationDemo
    case cameraPanDemo
    case asyncLoadDemo
    case multiShaderDemo
    case particleDemo
    case lineParticleDemo
    case smokeDemo
    case skeletonDemo
    case pauseDemo

    /// Human-readable display name for each scene, used in the PauseDemo menu table view.
    var title: String {
        switch self {
        case .massRenderDemo: return "\(GameConstants.MAX_OBJECTS.formatted()) Ships - Z-Depth Parallax"
        case .touchZoomDemo: return "Touch Input & Camera Zoom"
        case .instanceDemo: return "\(GameConstants.MAX_OBJECTS.formatted()) Ships - Instanced Rendering"
        case .schedulerDemo: return "Scheduler - Task Chaining"
        case .spawnDemo: return "Touch Spawn - Manual Draw Order"
        case .collisionDemo: return "Collision & AI States"
        case .collisionStressDemo: return "Collision Stress Test"
        case .bezierDemo: return "Cubic Bezier Curves"
        case .cameraRotationDemo: return "Camera Rotation & Shake"
        case .cameraPanDemo: return "Camera Pan - Unproject & Visible Bounds"
        case .asyncLoadDemo: return "Async Texture Loading"
        case .multiShaderDemo: return "Multi-Shader (Wireframe + Ripple)"
        case .particleDemo: return "Particles - Additive Campfire"
        case .lineParticleDemo: return "Particles - Line Emitter"
        case .smokeDemo: return "Particles - Alpha Smoke"
        case .skeletonDemo: return "Skeletal Animation - Stick Figure"
        case .pauseDemo: return "Paused"
        }
    }

    /// Navigable scenes in order (excludes pauseDemo which is push-only, not a standalone scene).
    static let navigable: [SceneTypes] = [
        .massRenderDemo, .touchZoomDemo, .instanceDemo,
        .schedulerDemo, .spawnDemo, .collisionDemo, .collisionStressDemo,
        .bezierDemo, .cameraRotationDemo, .cameraPanDemo, .multiShaderDemo,
        .particleDemo, .lineParticleDemo, .smokeDemo, .skeletonDemo
    ]

    /// Returns the next scene in the navigable list, or nil if this is the last one.
    func next() -> SceneTypes? {
        guard let index = SceneTypes.navigable.firstIndex(of: self) else { return nil }
        let nextIndex = index + 1
        return nextIndex < SceneTypes.navigable.count ? SceneTypes.navigable[nextIndex] : nil
    }

    /// Returns the previous scene in the navigable list, or nil if this is the first one.
    func prev() -> SceneTypes? {
        guard let index = SceneTypes.navigable.firstIndex(of: self) else { return nil }
        let prevIndex = index - 1
        return prevIndex >= 0 ? SceneTypes.navigable[prevIndex] : nil
    }
}
