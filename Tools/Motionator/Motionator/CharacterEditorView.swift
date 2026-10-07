//
//  CharacterEditorView.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import LiquidMetal2D
import MotionatorKit
import SwiftUI

/// The window: bones and clips on the left, the viewport in the middle,
/// the mode and camera controls in the toolbar.
struct CharacterEditorView: View {
    @ObservedObject var document: CharacterDocument
    @State private var session = EditorSession()
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            ViewportView(document: document, session: session)
                .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $session.mode) {
                    ForEach(EditorSession.Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem {
                Toggle("Grid", systemImage: "grid", isOn: $session.showGrid)
            }
            ToolbarItem {
                Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right") { fitCamera() }
                    .help("Centre the character and zoom to fit")
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }

    private var sidebar: some View {
        List(selection: $session.selectedBone) {
            Section("Bones") {
                ForEach(Array(document.character.rig.bones.enumerated()), id: \.offset) { index, bone in
                    Label(bone.name, systemImage: "line.diagonal")
                        .padding(.leading, CGFloat(depth(of: index)) * 12)
                        .tag(index)
                }
            }
            Section("Parts") {
                ForEach(document.character.rig.attachments, id: \.name) { attachment in
                    Label(attachment.name, systemImage: attachment.textureName == nil ? "square" : "photo")
                }
            }
            Section("Clips") {
                ForEach(document.character.clips, id: \.name) { clip in
                    Label(clip.name, systemImage: "film")
                }
            }
        }
    }

    private func depth(of bone: Int) -> Int {
        var depth = 0
        var parent = document.character.rig.bones[bone].parent
        while let current = parent {
            depth += 1
            parent = document.character.rig.bones[current].parent
        }
        return depth
    }

    /// Centres the rest pose and sets the distance from its extent.
    private func fitCamera() {
        let rig = document.character.rig
        let world = RigEditor.restWorld(of: rig)
        var low = Vec2(repeating: .greatestFiniteMagnitude)
        var high = Vec2(repeating: -.greatestFiniteMagnitude)
        for (index, bone) in rig.bones.enumerated() {
            for point in [world[index].position, world[index].apply(to: Vec2(bone.length, 0))] {
                low = simd_min(low, point)
                high = simd_max(high, point)
            }
        }
        guard low.x <= high.x else { return }
        session.cameraCentre = (low + high) / 2
        session.cameraDistance = max(8, max(high.x - low.x, high.y - low.y) * 2.2)
    }
}

/// The engine's view for this document; its own file keeps the engine
/// import away from SwiftUI's `State`.
struct ViewportView: View {
    let document: CharacterDocument
    let session: EditorSession

    var body: some View {
        LiquidView { EditorViewController(document: document, session: session) }
    }
}
