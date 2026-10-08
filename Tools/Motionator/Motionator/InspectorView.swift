//
//  InspectorView.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import LiquidMetal2D
import MotionatorKit
import SwiftUI

/// The selection's fields. Number fields commit on Return or focus loss;
/// each commit is one undo step. A refused edit shows its reason at the top.
struct InspectorView: View {
    @ObservedObject var document: CharacterDocument
    let session: EditorSession
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        Form {
            if let problem = session.problem {
                Text(problem).foregroundStyle(.red).font(.callout)
            }
            if session.mode == .animate {
                animateSections
            }
            switch session.selection {
            case .bone(let index) where document.character.rig.bones.indices.contains(index):
                if session.mode == .animate { poseFields(index) } else { boneFields(index) }
            case .attachment(let index) where document.character.rig.attachments.indices.contains(index):
                attachmentFields(index)
            default:
                Text("Select a bone or a part").foregroundStyle(.secondary)
            }
            Section("Import") {
                TextField("Pixels per unit", value: Bindable(session).pixelsPerUnit, format: .number)
                if session.referenceImage != nil {
                    Slider(value: Bindable(session).referenceOpacity, in: 0...1) { Text("Reference opacity") }
                    Button("Remove Reference") { session.referenceImage = nil }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Animate

    private var clip: AnimationClip? { session.clip(in: document.character) }

    @ViewBuilder
    private var animateSections: some View {
        if let clip, !session.selectedKeys.isEmpty {
            let keys = session.selectedKeys
            Section(keys.count == 1 ? "Key" : "\(keys.count) keys") {
                if keys.count == 1, let key = keys.first, let found = ClipEditor.key(in: clip, key) {
                    Text("\(key.bone), \(key.channel == .rotation ? "rotation" : "position")")
                    TextField("Time", value: Binding(get: { key.time }, set: { time in
                        let delta = ClipEditor.snapped(time, fps: session.fps) - key.time
                        guard abs(delta) > 1e-5 else { return }
                        replace(ClipEditor.movingKeys(clip, [key], by: delta), named: "Move Key")
                        session.selectedKeys = [KeyRef(bone: key.bone, channel: key.channel, time: key.time + delta)]
                    }), format: .number.precision(.fractionLength(0...3)))
                    keyValueFields(key, found.value, clip: clip)
                }
                Picker("Easing", selection: Binding(get: {
                    keys.count == 1 ? keys.first.flatMap { ClipEditor.key(in: clip, $0)?.easing } ?? .linear : .linear
                }, set: { easing in
                    replace(ClipEditor.settingEasing(clip, keys, to: easing), named: "Set Easing")
                })) {
                    ForEach(EasingType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Button("Delete \(keys.count == 1 ? "Key" : "Keys")", role: .destructive) {
                    replace(ClipEditor.removingKeys(clip, keys), named: "Delete Keys")
                    session.selectedKeys = []
                }
            }
        }
        if let clip, let index = session.selectedEvent, clip.events.indices.contains(index) {
            let event = clip.events[index]
            Section("Event") {
                TextField("Name", text: Binding(get: { event.name }, set: { name in
                    guard !name.isEmpty, name != event.name else { return }
                    replace(ClipEditor.renamingEvent(clip, at: index, to: name), named: "Rename Event")
                }))
                TextField("Time", value: Binding(get: { event.time }, set: { time in
                    replace(ClipEditor.movingEvent(clip, at: index, to: ClipEditor.snapped(time, fps: session.fps)),
                            named: "Move Event")
                }), format: .number.precision(.fractionLength(0...3)))
                Button("Delete Event", role: .destructive) {
                    replace(ClipEditor.removingEvent(clip, at: index), named: "Delete Event")
                    session.selectedEvent = nil
                }
            }
        }
    }

    @ViewBuilder
    private func keyValueFields(_ key: KeyRef, _ value: ClipEditor.KeyValue, clip: AnimationClip) -> some View {
        switch value {
        case .rotation(let radians):
            TextField("Angle (degrees)", value: Binding(get: { radians * 180 / .pi }, set: { degrees in
                let value = ClipEditor.KeyValue.rotation(degrees * .pi / 180)
                replace(ClipEditor.settingKey(clip, bone: key.bone, time: key.time, value: value), named: "Edit Key")
            }), format: .number.precision(.fractionLength(0...1)))
        case .position(let position):
            TextField("X", value: Binding(get: { position.x }, set: { x in
                let value = ClipEditor.KeyValue.position(Vec2(x, position.y))
                replace(ClipEditor.settingKey(clip, bone: key.bone, time: key.time, value: value), named: "Edit Key")
            }), format: .number.precision(.fractionLength(0...3)))
            TextField("Y", value: Binding(get: { position.y }, set: { y in
                let value = ClipEditor.KeyValue.position(Vec2(position.x, y))
                replace(ClipEditor.settingKey(clip, bone: key.bone, time: key.time, value: value), named: "Edit Key")
            }), format: .number.precision(.fractionLength(0...3)))
        }
    }

    /// The bone's pose at the playhead; a change writes a key there.
    @ViewBuilder
    private func poseFields(_ index: Int) -> some View {
        let rig = document.character.rig
        let bone = rig.bones[index]
        if let clip, let pose = try? ClipEditor.pose(of: clip, rig: rig, at: session.playhead) {
            let local = pose.local[index]
            Section("\(bone.name) at \(String(format: "%.3f", session.playhead)) s") {
                TextField("Angle (degrees)", value: Binding(get: { local.rotation * 180 / .pi }, set: { degrees in
                    let radians = degrees * .pi / 180
                    guard abs(radians - local.rotation) > 1e-6 else { return }
                    let value = ClipEditor.KeyValue.rotation(radians)
                    replace(ClipEditor.settingKey(clip, bone: bone.name, time: session.playhead, value: value),
                            named: "Key Bone")
                }), format: .number.precision(.fractionLength(0...1)))
                TextField("X", value: Binding(get: { local.position.x }, set: { x in
                    replace(ClipEditor.settingKey(clip, bone: bone.name, time: session.playhead,
                                                  value: .position(Vec2(x, local.position.y))), named: "Key Bone")
                }), format: .number.precision(.fractionLength(0...3)))
                TextField("Y", value: Binding(get: { local.position.y }, set: { y in
                    replace(ClipEditor.settingKey(clip, bone: bone.name, time: session.playhead,
                                                  value: .position(Vec2(local.position.x, y))), named: "Key Bone")
                }), format: .number.precision(.fractionLength(0...3)))
                Text("Edits here key the bone at the playhead.").font(.caption).foregroundStyle(.secondary)
            }
            keyList(for: bone.name, in: clip)
        } else {
            Text("No clip selected").foregroundStyle(.secondary)
        }
    }

    /// The bone's key times: click one to jump to it, delete beside each.
    @ViewBuilder
    private func keyList(for bone: String, in clip: AnimationClip) -> some View {
        let keys = ClipEditor.allKeys(in: clip).filter { $0.bone == bone }
        let times = Array(Set(keys.map { ($0.time * 1e4).rounded() / 1e4 })).sorted()
        let noun = times.count == 1 ? "key" : "keys"
        let title = times.isEmpty ? "No keys on \(bone)" : "\(times.count) \(noun) on \(bone)"
        Section(title) {
            if times.count == 1 {
                Text("One key holds its pose for the whole clip. Scrub elsewhere and pose again to blend.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(times, id: \.self) { time in
                HStack {
                    Button(String(format: "%.3f s", time)) {
                        session.isPlaying = false
                        session.playhead = time
                        session.selectedKeys = keys.filter { abs($0.time - time) < 1e-3 }
                    }
                    .buttonStyle(.link)
                    Spacer()
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        replace(ClipEditor.removingKeys(clip, keys.filter { abs($0.time - time) < 1e-3 }),
                                named: "Delete Keys")
                        session.selectedKeys = []
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
    }

    private func replace(_ edited: AnimationClip, named name: String) {
        edit(name) { character in
            if let index = character.clips.firstIndex(where: { $0.name == edited.name }) {
                character.clips[index] = edited
            }
        }
    }

    // MARK: - Bone

    @ViewBuilder
    private func boneFields(_ index: Int) -> some View {
        let rig = document.character.rig
        let bone = rig.bones[index]
        Section("Bone") {
            TextField("Name", text: Binding(get: { bone.name }, set: { name in
                guard name != bone.name, !name.isEmpty else { return }
                edit("Rename Bone") { character in
                    (character.rig, character.clips) = try RigEditor.renamingBone(
                        character.rig, index, to: name, in: character.clips)
                }
            }))
            Picker("Parent", selection: Binding(get: { bone.parent ?? -1 }, set: { parent in
                guard parent != (bone.parent ?? -1) else { return }
                edit("Reparent Bone") {
                    $0.rig = try RigEditor.reparenting($0.rig, index, to: parent < 0 ? nil : parent)
                }
            })) {
                Text("None (a root)").tag(-1)
                ForEach(rig.bones.indices.filter { $0 != index }, id: \.self) { other in
                    Text(rig.bones[other].name).tag(other)
                }
            }
            TextField("Length", value: Binding(get: { bone.length }, set: { length in
                guard length > 0, length != bone.length else { return }
                edit("Resize Bone") { $0.rig = try RigEditor.settingLength($0.rig, index, length) }
            }), format: .number.precision(.fractionLength(0...3)))
        }
        Section("Rest pose") {
            TextField("X", value: restBinding(index, \.position.x), format: .number.precision(.fractionLength(0...3)))
            TextField("Y", value: restBinding(index, \.position.y), format: .number.precision(.fractionLength(0...3)))
            TextField("Angle (degrees)", value: Binding(get: { bone.rest.rotation * 180 / .pi }, set: { degrees in
                var rest = bone.rest
                rest.rotation = degrees * .pi / 180
                guard rest != bone.rest else { return }
                edit("Rotate Bone") { $0.rig = try RigEditor.settingRest($0.rig, index, rest) }
            }), format: .number.precision(.fractionLength(0...1)))
        }
    }

    private func restBinding(_ index: Int, _ keyPath: WritableKeyPath<RigidTransform2D, Float>) -> Binding<Float> {
        Binding(get: { document.character.rig.bones[index].rest[keyPath: keyPath] }, set: { value in
            var rest = document.character.rig.bones[index].rest
            rest[keyPath: keyPath] = value
            guard rest != document.character.rig.bones[index].rest else { return }
            edit("Move Bone") { $0.rig = try RigEditor.settingRest($0.rig, index, rest) }
        })
    }

    // MARK: - Attachment

    @ViewBuilder
    private func attachmentFields(_ index: Int) -> some View {
        let rig = document.character.rig
        let attachment = rig.attachments[index]
        Section("Part") {
            TextField("Name", text: Binding(get: { attachment.name }, set: { name in
                guard !name.isEmpty, name != attachment.name else { return }
                var changed = attachment
                changed.name = name
                set(index, changed, named: "Rename Part")
            }))
            Picker("Bone", selection: Binding(get: { attachment.bone }, set: { bone in
                var changed = attachment
                changed.bone = bone
                set(index, changed, named: "Move Part")
            })) {
                ForEach(rig.bones.indices, id: \.self) { Text(rig.bones[$0].name).tag($0) }
            }
            Picker("Image", selection: Binding(get: { attachment.textureName ?? "" }, set: { name in
                var changed = attachment
                changed.textureName = name.isEmpty ? nil : name
                set(index, changed, named: "Change Image")
            })) {
                Text("White").tag("")
                ForEach(document.character.images.keys.sorted(), id: \.self) { Text($0).tag($0) }
            }
            ColorPicker("Tint", selection: Binding(get: { Color(attachment.tint) }, set: { colour in
                var changed = attachment
                changed.tint = colour.vec4
                set(index, changed, named: "Tint Part")
            }))
        }
        Section("Placement") {
            TextField("Width", value: field(index, \.size.x), format: .number.precision(.fractionLength(0...3)))
            TextField("Height", value: field(index, \.size.y), format: .number.precision(.fractionLength(0...3)))
            TextField("Offset X", value: field(index, \.offset.x), format: .number.precision(.fractionLength(0...3)))
            TextField("Offset Y", value: field(index, \.offset.y), format: .number.precision(.fractionLength(0...3)))
            TextField("Angle (degrees)", value: Binding(get: { attachment.rotation * 180 / .pi }, set: { degrees in
                var changed = attachment
                changed.rotation = degrees * .pi / 180
                set(index, changed, named: "Rotate Part")
            }), format: .number.precision(.fractionLength(0...1)))
        }
    }

    private func field(_ index: Int, _ keyPath: WritableKeyPath<Attachment, Float>) -> Binding<Float> {
        Binding(get: { document.character.rig.attachments[index][keyPath: keyPath] }, set: { value in
            var changed = document.character.rig.attachments[index]
            changed[keyPath: keyPath] = value
            set(index, changed, named: "Edit Part")
        })
    }

    private func set(_ index: Int, _ attachment: Attachment, named name: String) {
        guard attachment != document.character.rig.attachments[index] else { return }
        edit(name) { $0.rig = try RigEditor.settingAttachment($0.rig, index, attachment) }
    }

    // MARK: - Edits

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
}

extension Color {
    init(_ tint: Vec4) {
        self.init(red: Double(tint.x), green: Double(tint.y), blue: Double(tint.z), opacity: Double(tint.w))
    }

    var vec4: Vec4 {
        let resolved = resolve(in: EnvironmentValues())
        return Vec4(resolved.red, resolved.green, resolved.blue, resolved.opacity)
    }
}
