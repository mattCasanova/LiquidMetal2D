//
//  TransportBar.swift
//  Motionator
//
//  Created by Matt Casanova on 10/8/26.
//

import LiquidMetal2D
import MotionatorKit
import SwiftUI

/// Above the timeline: the clip, play and step, the time, the clip's length
/// and loop, the frame grid, auto-key, onion skins and the Key button.
struct TransportBar: View {
    @ObservedObject var document: CharacterDocument
    let session: EditorSession
    @Environment(\.undoManager) private var undoManager
    @State private var isNamingClip = false
    @State private var newClipName = ""

    private var clip: AnimationClip? { session.clip(in: document.character) }

    var body: some View {
        HStack(spacing: 10) {
            clipMenu
            Divider().frame(height: 18)
            Button("Start", systemImage: "backward.end") { session.playhead = 0 }
                .keyboardShortcut(.home, modifiers: [])
            Button("Back a frame", systemImage: "backward.frame") { step(-1) }
                .keyboardShortcut(",", modifiers: [])
            Button(session.isPlaying ? "Pause" : "Play",
                   systemImage: session.isPlaying ? "pause.fill" : "play.fill") { session.isPlaying.toggle() }
            .keyboardShortcut(.space, modifiers: [])
            Button("Forward a frame", systemImage: "forward.frame") { step(1) }
                .keyboardShortcut(".", modifiers: [])
            Button("End", systemImage: "forward.end") { session.playhead = clip?.duration ?? 0 }
                .keyboardShortcut(.end, modifiers: [])
            Text(String(format: "%.3f / %.3f s", session.playhead, clip?.duration ?? 0))
                .font(.system(.body, design: .monospaced))
                .frame(width: 130, alignment: .leading)
            Divider().frame(height: 18)
            if let clip {
                TextField("Length", value: Binding(get: { clip.duration }, set: { duration in
                    guard duration > 0.05, duration != clip.duration else { return }
                    replace(ClipEditor.settingDuration(clip, to: duration, scalingKeys: false),
                            named: "Change Duration")
                }), format: .number.precision(.fractionLength(0...3)))
                .frame(width: 60)
                Toggle("Loop", isOn: Binding(get: { clip.loops }, set: { loops in
                    var changed = clip
                    changed.loops = loops
                    replace(changed, named: loops ? "Loop Clip" : "Play Clip Once")
                }))
                .toggleStyle(.checkbox)
            }
            Picker("Snap", selection: Bindable(session).fps) {
                Text("Free").tag(Int?.none)
                Text("24 fps").tag(Int?.some(24))
                Text("30 fps").tag(Int?.some(30))
                Text("60 fps").tag(Int?.some(60))
            }
            .frame(width: 110)
            Spacer()
            Toggle("Auto-key", systemImage: "diamond.fill", isOn: Bindable(session).autoKey)
                .toggleStyle(.button)
                .help("A pose edit at the playhead writes keys when the drag ends")
            Button("Key", systemImage: "diamond") { session.wantsKey = true }
                .keyboardShortcut("k", modifiers: [])
                .disabled(session.pendingBones.isEmpty)
                .help("Write keys for the bones edited with auto-key off")
            Toggle("Onion skins", systemImage: "square.3.layers.3d", isOn: Bindable(session).onionSkins)
                .toggleStyle(.button)
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(white: 0.17))
        .sheet(isPresented: $isNamingClip) { newClipSheet }
    }

    private var clipMenu: some View {
        HStack(spacing: 4) {
            Picker("Clip", selection: Binding(get: { clip?.name ?? "" }, set: { name in
                session.clipName = name
                session.playhead = 0
                session.selectedKeys = []
                session.selectedEvent = nil
            })) {
                ForEach(document.character.clips, id: \.name) { Text($0.name).tag($0.name) }
            }
            .labelsHidden()
            .frame(width: 120)
            Button("New Clip", systemImage: "plus") {
                newClipName = ""
                isNamingClip = true
            }
            Button("Delete Clip", systemImage: "minus") {
                guard let clip else { return }
                document.apply({ character in
                    var character = character
                    character.clips.removeAll { $0.name == clip.name }
                    return character
                }, named: "Delete Clip", undoManager: undoManager)
                session.clipName = document.character.clips.first?.name
                session.selectedKeys = []
            }
            .disabled(clip == nil)
        }
    }

    private var newClipSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Clip").font(.headline)
            TextField("Name", text: $newClipName).frame(width: 220)
            HStack {
                Spacer()
                Button("Cancel") { isNamingClip = false }.keyboardShortcut(.cancelAction)
                Button("Add") {
                    let name = newClipName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, document.character.clip(named: name) == nil else { return }
                    document.apply({ character in
                        var character = character
                        character.clips.append(AnimationClip(name: name, duration: 1, loops: true, tracks: []))
                        return character
                    }, named: "Add Clip", undoManager: undoManager)
                    session.clipName = name
                    session.playhead = 0
                    session.selectedKeys = []
                    isNamingClip = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private func step(_ frames: Int) {
        guard let clip else { return }
        let fps = Float(session.fps ?? 24)
        session.isPlaying = false
        let frame = (session.playhead * fps).rounded() + Float(frames)
        session.playhead = GameMath.clamp(value: frame / fps, low: 0, high: clip.duration)
    }

    private func replace(_ edited: AnimationClip, named name: String) {
        document.apply({ character in
            var character = character
            if let index = character.clips.firstIndex(where: { $0.name == edited.name }) {
                character.clips[index] = edited
            }
            return character
        }, named: name, undoManager: undoManager)
    }
}
