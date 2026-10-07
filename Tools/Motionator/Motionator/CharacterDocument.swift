//
//  CharacterDocument.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import Combine
import LiquidMetal2D
import MotionatorKit
import SwiftUI
import UniformTypeIdentifiers

nonisolated extension UTType {
    /// A `.character` folder: the rig, its clips and its images.
    static let character = UTType(exportedAs: "com.mattcasanova.motionator.character", conformingTo: .package)
}

/// The document: a `Character` read and written through `CharacterFiles`.
/// Every edit goes through ``apply(_:named:undoManager:)``, which keeps the
/// old value for undo; `version` ticks so the viewport knows to rebuild.
final class CharacterDocument: ReferenceFileDocument {
    /// What the writer gets: the character and the rig file's stem.
    struct Snapshot: Sendable {
        var character: Character
        var rigName: String
    }

    nonisolated static let readableContentTypes: [UTType] = [.character]

    @Published private(set) var character: Character
    /// Goes up on every change, so a viewer can tell "the rig changed" from "a frame passed".
    @Published private(set) var version = 0
    /// The rig file's stem inside the folder; a new document's is `character`.
    private(set) var rigName = "character"

    init() {
        character = Character(rig: SkeletonDefinition(
            bones: [Bone(name: "root", parent: nil, length: 1, rest: .identity)], attachments: []))
    }

    init(configuration: ReadConfiguration) throws {
        character = try CharacterFiles.read(configuration.file, name: "the document")
        rigName = Self.rigName(in: configuration.file) ?? "character"
    }

    /// The stem of the folder's rig file, or nil when it has none.
    nonisolated static func rigName(in folder: FileWrapper) -> String? {
        folder.fileWrappers?.keys.sorted().first { $0.hasSuffix(CharacterFiles.rigSuffix) }
            .map { String($0.dropLast(CharacterFiles.rigSuffix.count)) }
    }

    func snapshot(contentType: UTType) throws -> Snapshot {
        Snapshot(character: character, rigName: rigName)
    }

    nonisolated func fileWrapper(snapshot: Snapshot, configuration: WriteConfiguration) throws -> FileWrapper {
        try CharacterFiles.wrapper(for: snapshot.character, rigName: snapshot.rigName)
    }

    /// Replaces the character with `edit`'s result and registers the old
    /// value with `undoManager`, so undo and redo are one snapshot each. An
    /// edit that throws changes nothing.
    func apply(
        _ edit: (Character) throws -> Character, named name: String, undoManager: UndoManager?
    ) rethrows {
        replace(with: try edit(character), named: name, undoManager: undoManager)
    }

    private func replace(with new: Character, named name: String, undoManager: UndoManager?) {
        let old = character
        character = new
        version += 1
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.replace(with: old, named: name, undoManager: undoManager)
            }
        }
        undoManager?.setActionName(name)
    }
}
