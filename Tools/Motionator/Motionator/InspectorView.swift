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
            switch session.selection {
            case .bone(let index) where document.character.rig.bones.indices.contains(index):
                boneFields(index)
            case .attachment(let index) where document.character.rig.attachments.indices.contains(index):
                attachmentFields(index)
            default:
                Text("Select a bone or a part").foregroundStyle(.secondary)
            }
            Section("Import") {
                TextField("Pixels per unit", value: Bindable(session).pixelsPerUnit, format: .number)
            }
        }
        .formStyle(.grouped)
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
