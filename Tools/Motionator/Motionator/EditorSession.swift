//
//  EditorSession.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import Foundation
import LiquidMetal2D
import MotionatorKit
import Observation

/// What the sidebar and the viewport agree is selected.
enum EditorSelection: Hashable {
    case bone(Int)
    case attachment(Int)
}

/// What the window shows that isn't saved: the mode, the selection, the
/// camera, the playhead. The SwiftUI views write it; `EditorScene` reads it
/// each frame and writes the selection, the playhead and the pending bones back.
@Observable
final class EditorSession {
    enum Mode: String, CaseIterable, Identifiable {
        case setup = "Setup"
        case animate = "Animate"
        var id: String { rawValue }
    }

    var mode: Mode = .setup
    var selection: EditorSelection?
    /// Camera centre in world units and its distance (the zoom).
    var cameraCentre = Vec2(0, 0)
    var cameraDistance: Float = 24
    var showGrid = true
    var isInspectorShown = true
    /// How many image pixels make one world unit when a part or a reference is imported.
    var pixelsPerUnit: Float = 100
    /// The last edit that was refused, shown in the inspector until the next edit.
    var problem: String?
    /// The window's undo manager, for edits the viewport makes.
    @ObservationIgnored weak var undoManager: UndoManager?

    // MARK: Animate mode

    var clipName: String?
    var playhead: Float = 0
    var isPlaying = false
    /// The frame grid the playhead and dragged keys snap to; nil is free.
    var fps: Int? = 24
    /// A pose edit at the playhead writes keys when the drag ends.
    var autoKey = true
    var onionSkins = true
    var selectedKeys: Set<KeyRef> = []
    var selectedEvent: Int?
    /// Bones edited with auto-key off, shown orange until Key writes them or the playhead moves.
    var pendingBones: Set<String> = []
    /// Set by the Key button; the viewport writes the pending bones and clears it.
    var wantsKey = false
    /// A picture behind the viewport to pose against.
    var referenceImage: Data?
    var referenceOpacity: Float = 0.5

    var selectedBone: Int? {
        if case .bone(let index) = selection { return index }
        return nil
    }

    var selectedAttachment: Int? {
        if case .attachment(let index) = selection { return index }
        return nil
    }

    func clip(in character: Character) -> AnimationClip? {
        clipName.flatMap { character.clip(named: $0) } ?? character.clips.first
    }
}
