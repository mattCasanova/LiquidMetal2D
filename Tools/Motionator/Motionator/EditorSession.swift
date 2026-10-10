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
    /// Reports changes to the document's folder made outside the window (`CharacterEditorView+Reload`).
    @ObservationIgnored var watcher: DocumentWatcher?

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

    /// After the document was replaced from disk: keeps what still exists
    /// under its name and drops the rest, so the window stays where it was.
    func reconcile(from old: Character, to new: Character) {
        switch selection {
        case .bone(let index):
            let name = old.rig.bones.indices.contains(index) ? old.rig.bones[index].name : nil
            selection = name.flatMap { name in new.rig.bones.firstIndex { $0.name == name } }.map { .bone($0) }
        case .attachment(let index):
            let name = old.rig.attachments.indices.contains(index) ? old.rig.attachments[index].name : nil
            selection = name.flatMap { name in new.rig.attachments.firstIndex { $0.name == name } }
                .map { .attachment($0) }
        case nil:
            break
        }
        if let clipName, new.clip(named: clipName) == nil { self.clipName = nil }
        let clip = clip(in: new)
        if let clip { playhead = min(playhead, clip.duration) }
        selectedKeys = selectedKeys.filter { ref in clip.map { ClipEditor.key(in: $0, ref) != nil } ?? false }
        if let index = selectedEvent, !(clip?.events.indices.contains(index) ?? false) { selectedEvent = nil }
        pendingBones = pendingBones.filter { name in new.rig.bones.contains { $0.name == name } }
    }
}
