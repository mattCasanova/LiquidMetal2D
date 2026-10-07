//
//  EditorSession.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import Foundation
import LiquidMetal2D
import Observation

/// What the sidebar and the viewport agree is selected.
enum EditorSelection: Hashable {
    case bone(Int)
    case attachment(Int)
}

/// What the window shows that isn't saved: the mode, the selection, the
/// camera. The SwiftUI views write it; `EditorScene` reads it each frame
/// and writes the selection back when the viewport is clicked.
@Observable
final class EditorSession {
    enum Mode: String, CaseIterable, Identifiable {
        case setup = "Setup"
        case animate = "Animate"
        var id: String { rawValue }
    }

    var mode: Mode = .setup
    var selection: EditorSelection?
    var clipName: String?
    /// Camera centre in world units and its distance (the zoom).
    var cameraCentre = Vec2(0, 0)
    var cameraDistance: Float = 24
    var showGrid = true
    var isInspectorShown = true
    /// How many image pixels make one world unit when a part is imported.
    var pixelsPerUnit: Float = 100
    /// The last edit that was refused, shown in the inspector until the next edit.
    var problem: String?
    /// The window's undo manager, for edits the viewport makes.
    @ObservationIgnored weak var undoManager: UndoManager?

    var selectedBone: Int? {
        if case .bone(let index) = selection { return index }
        return nil
    }

    var selectedAttachment: Int? {
        if case .attachment(let index) = selection { return index }
        return nil
    }
}
