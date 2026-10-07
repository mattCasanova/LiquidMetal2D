//
//  EditorSession.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import LiquidMetal2D
import Observation

/// What the window shows that isn't saved: the mode, the selection, the
/// camera. The SwiftUI views write it; `EditorScene` reads it each frame.
@Observable
final class EditorSession {
    enum Mode: String, CaseIterable, Identifiable {
        case setup = "Setup"
        case animate = "Animate"
        var id: String { rawValue }
    }

    var mode: Mode = .setup
    var selectedBone: Int?
    var clipName: String?
    /// Camera centre in world units and its distance (the zoom).
    var cameraCentre = Vec2(0, 0)
    var cameraDistance: Float = 24
    var showGrid = true
}
