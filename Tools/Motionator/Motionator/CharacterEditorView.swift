//
//  CharacterEditorView.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import AppKit
import LiquidMetal2D
import MotionatorKit
import SwiftUI
import UniformTypeIdentifiers

/// The window: bones, parts and clips on the left, the viewport in the
/// middle, the inspector on the right, the mode and camera in the toolbar.
struct CharacterEditorView: View {
    @ObservedObject var document: CharacterDocument
    @State private var session = EditorSession()
    @State private var isImportingParts = false
    @State private var isImportingReference = false
    @State private var timelineHeight: CGFloat = 260
    @State private var timelineHeightAtDragStart: CGFloat?
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            // A plain stack with its own divider: SwiftUI's VSplitView throws
            // inside AppKit's constraint pass when it asks the engine's view
            // for a size (seen 2026-10-08 on every divider drag).
            VStack(spacing: 0) {
                ViewportView(document: document, session: session)
                    .ignoresSafeArea()
                    .dropDestination(for: URL.self) { urls, _ in
                        importParts(from: urls)
                        return true
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if session.mode == .animate {
                    timelineDivider
                    VStack(spacing: 0) {
                        TransportBar(document: document, session: session)
                        TimelineView(document: document, session: session)
                    }
                    .frame(height: timelineHeight)
                }
            }
        }
        .inspector(isPresented: $session.isInspectorShown) {
            InspectorView(document: document, session: session)
                .inspectorColumnWidth(min: 220, ideal: 260)
        }
        .toolbar { toolbar }
        .fileImporter(isPresented: $isImportingParts, allowedContentTypes: [.png], allowsMultipleSelection: true) {
            if case .success(let urls) = $0 { importParts(from: urls) }
        }
        .fileImporter(isPresented: $isImportingReference, allowedContentTypes: [.image]) {
            if case .success(let url) = $0 {
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                session.referenceImage = try? Data(contentsOf: url)
            }
        }
        .onChange(of: session.mode) { _, mode in
            if mode == .animate, session.clipName == nil { session.clipName = document.character.clips.first?.name }
            session.selectedKeys = []
        }
        .onAppear { session.undoManager = undoManager }
        .frame(minWidth: 900, minHeight: 540)
    }

    /// A thin bar the timeline's height is dragged by.
    private var timelineDivider: some View {
        Rectangle()
            .fill(Color(white: 0.25))
            .frame(height: 5)
            .overlay(Rectangle().fill(Color(white: 0.4)).frame(width: 40, height: 1))
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
            .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                let start = timelineHeightAtDragStart ?? timelineHeight
                timelineHeightAtDragStart = start
                timelineHeight = min(600, max(120, start - value.translation.height))
            }.onEnded { _ in timelineHeightAtDragStart = nil })
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Mode", selection: $session.mode) {
                ForEach(EditorSession.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        ToolbarItemGroup {
            Button("Add Bone", systemImage: "plus") { addBone() }
                .help("Add a child of the selected bone (or a root)")
            Button("Add Part…", systemImage: "photo.badge.plus") { isImportingParts = true }
                .help("Import PNGs as parts on the selected bone")
            Button("Delete", systemImage: "trash") { deleteSelection() }
                .disabled(session.selection == nil)
        }
        ToolbarItemGroup {
            Button("Reference…", systemImage: "photo.on.rectangle") { isImportingReference = true }
                .help("A picture behind the viewport to pose against")
            Toggle("Grid", systemImage: "grid", isOn: $session.showGrid)
            Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right") { fitCamera() }
                .help("Centre the character and zoom to fit")
            Toggle("Inspector", systemImage: "sidebar.trailing", isOn: $session.isInspectorShown)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $session.selection) {
            Section("Bones") {
                ForEach(Array(document.character.rig.bones.enumerated()), id: \.offset) { index, bone in
                    Label(bone.name, systemImage: "line.diagonal")
                        .padding(.leading, CGFloat(depth(of: index)) * 12)
                        .tag(EditorSelection.bone(index))
                        .contextMenu {
                            Button("Add Child Bone") { addBone(under: index) }
                            Button("Delete Bone", role: .destructive) { deleteBone(index) }
                        }
                }
            }
            Section("Parts (back to front)") {
                ForEach(RigEditor.attachmentsByDrawOrder(document.character.rig), id: \.self) { index in
                    let attachment = document.character.rig.attachments[index]
                    Label(attachment.name, systemImage: attachment.textureName == nil ? "square" : "photo")
                        .tag(EditorSelection.attachment(index))
                }
                .onMove { source, destination in
                    edit("Reorder Parts") {
                        $0.rig = RigEditor.movingAttachments($0.rig, from: source, to: destination)
                    }
                }
            }
            Section("Clips") {
                ForEach(document.character.clips, id: \.name) { clip in
                    Label(clip.name, systemImage: "film")
                        .foregroundStyle(isCurrent(clip) ? Color.accentColor : Color.primary)
                        .onTapGesture {
                            session.mode = .animate
                            session.clipName = clip.name
                            session.playhead = 0
                            session.selectedKeys = []
                        }
                }
            }
        }
        .onDeleteCommand { deleteSelection() }
    }

    private func isCurrent(_ clip: AnimationClip) -> Bool {
        session.mode == .animate && session.clip(in: document.character)?.name == clip.name
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

    // MARK: - Edits

    /// One undoable change; a refused edit shows its reason in the inspector.
    private func edit(_ name: String, _ change: (inout Character) throws -> Void) {
        do {
            try document.apply({ character in
                var character = character
                try change(&character)
                return character
            }, named: name, undoManager: undoManager)
            session.problem = nil
        } catch {
            session.problem = "\(error)"
        }
    }

    private func addBone(under parent: Int? = nil) {
        let rig = document.character.rig
        let parentIndex = parent ?? session.selectedBone
        var name = "bone"
        var suffix = 2
        while rig.bones.contains(where: { $0.name == name }) {
            name = "bone \(suffix)"
            suffix += 1
        }
        let rest = parentIndex.map { RigidTransform2D(position: Vec2(rig.bones[$0].length, 0)) } ?? .identity
        edit("Add Bone") {
            $0.rig = try RigEditor.addingBone($0.rig, named: name, parent: parentIndex, length: 1, rest: rest)
        }
        session.selection = .bone(document.character.rig.bones.count - 1)
    }

    private func deleteBone(_ index: Int) {
        edit("Delete Bone") { character in
            (character.rig, character.clips) = try RigEditor.removingBone(character.rig, index, in: character.clips)
        }
        session.selection = nil
    }

    private func deleteSelection() {
        switch session.selection {
        case .bone(let index): deleteBone(index)
        case .attachment(let index):
            edit("Delete Part") { $0.rig = try RigEditor.removingAttachment($0.rig, index) }
            session.selection = nil
        case nil: break
        }
    }

    /// Each PNG becomes an image in the document and a part on the selected bone (or the root).
    private func importParts(from urls: [URL]) {
        let bone = session.selectedBone ?? 0
        for url in urls where url.pathExtension.lowercased() == "png" {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), let image = ContactSheet.decode(data) else {
                session.problem = "\(url.lastPathComponent) is not a PNG the system can decode"
                continue
            }
            let name = url.deletingPathExtension().lastPathComponent
            edit("Add Part") { character in
                character.images[name] = data
                character.rig = try RigEditor.addingAttachment(
                    character.rig, image: name, pixelSize: Vec2(Float(image.width), Float(image.height)),
                    pixelsPerUnit: session.pixelsPerUnit, bone: bone)
            }
        }
        if let last = document.character.rig.attachments.indices.last { session.selection = .attachment(last) }
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
