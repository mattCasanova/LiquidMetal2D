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
import Synchronization
import UniformTypeIdentifiers

nonisolated extension UTType {
    /// A `.character` folder: the rig, its clips and its images.
    static let character = UTType(exportedAs: "com.mattcasanova.motionator.character", conformingTo: .package)
}

/// The document: a `Character` read and written through `CharacterFiles`.
/// Every edit goes through ``apply(_:named:undoManager:)``, which keeps the
/// old value for undo; `version` ticks so the viewport knows to rebuild.
/// ``reloadIfChanged(at:undoManager:)`` takes a change someone else made to
/// the folder, telling it from the document's own writes by the bytes.
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
    /// The folder's files as last read from or handed to the system for
    /// writing, so a change on disk that matches is the document's own.
    private let knownFiles = Mutex<[String: Data]>([:])

    init() {
        character = Character(rig: SkeletonDefinition(
            bones: [Bone(name: "root", parent: nil, length: 1, rest: .identity)], attachments: []))
    }

    convenience init(configuration: ReadConfiguration) throws {
        try self.init(file: configuration.file)
    }

    /// The document for a folder on disk: the path `init(configuration:)` takes, for tests.
    convenience init(contentsOf url: URL) throws {
        try self.init(file: try FileWrapper(url: url, options: .immediate))
    }

    private init(file: FileWrapper) throws {
        character = try CharacterFiles.read(file, name: "the document")
        rigName = Self.rigName(in: file) ?? "character"
        knownFiles.withLock { $0 = CharacterFiles.contents(of: file) }
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
        try wrapper(for: snapshot)
    }

    /// The folder the system writes for a save; its bytes are remembered so
    /// the write is recognised as the document's own when the watcher sees it.
    nonisolated func wrapper(for snapshot: Snapshot) throws -> FileWrapper {
        let wrapper = try CharacterFiles.wrapper(for: snapshot.character, rigName: snapshot.rigName)
        knownFiles.withLock { $0 = CharacterFiles.contents(of: wrapper) }
        return wrapper
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

    // MARK: - Changes on disk

    /// Whether the folder holds files this document neither read nor wrote.
    func hasChangedOnDisk(at url: URL) throws -> Bool {
        let files = try CharacterFiles.contents(at: url)
        return knownFiles.withLock { $0 != files }
    }

    /// Reads the folder again when it holds files this document neither read
    /// nor wrote. Returns the character shown before, or nil when the folder
    /// already matched. The undo stack is dropped: its steps lead back to a
    /// character that is no longer on disk. A folder that does not read
    /// throws and is left for the next change.
    func reloadIfChanged(at url: URL, undoManager: UndoManager?) throws -> Character? {
        let file = try FileWrapper(url: url, options: .immediate)
        let files = CharacterFiles.contents(of: file)
        guard knownFiles.withLock({ $0 != files }) else { return nil }
        let loaded = try CharacterFiles.read(file, name: url.lastPathComponent)
        knownFiles.withLock { $0 = files }
        let previous = character
        character = loaded
        rigName = Self.rigName(in: file) ?? rigName
        version += 1
        undoManager?.removeAllActions()
        return previous
    }
}
