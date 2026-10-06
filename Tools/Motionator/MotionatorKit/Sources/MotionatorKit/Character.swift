//
//  Character.swift
//  MotionatorKit
//
//  Created by Matt Casanova on 10/6/26.
//

import Foundation
import LiquidMetal2D

/// One rig, its clips and its part images: the whole document, a value.
public struct Character: Equatable, Sendable {
    public var rig: SkeletonDefinition
    /// Unique names.
    public var clips: [AnimationClip]
    /// PNG bytes by name; an `Attachment.textureName` names one of these.
    public var images: [String: Data]

    public init(rig: SkeletonDefinition, clips: [AnimationClip] = [], images: [String: Data] = [:]) {
        self.rig = rig
        self.clips = clips
        self.images = images
    }

    public func clip(named name: String) -> AnimationClip? {
        clips.first { $0.name == name }
    }

    /// Texture names the rig uses that have no image. The renderer draws
    /// those parts white.
    public var missingImages: [String] {
        var names: [String] = []
        for attachment in rig.attachments {
            if let name = attachment.textureName, images[name] == nil, !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }
}

public enum CharacterError: Error, CustomStringConvertible, Equatable {
    case notAFolder(String)
    case noRig(String)
    case severalRigs([String])
    case clipDoesNotFit(clip: String, reason: String)
    case duplicateClip(String)

    public var description: String {
        switch self {
        case .notAFolder(let path): "\(path) is not a folder"
        case .noRig(let path): "no *\(CharacterFiles.rigSuffix) in \(path)"
        case .severalRigs(let names): "more than one rig: \(names.joined(separator: ", "))"
        case .clipDoesNotFit(let clip, let reason): "clip \(clip) does not fit the rig: \(reason)"
        case .duplicateClip(let name): "two clips named \(name)"
        }
    }
}

/// A character on disk: a folder (`Hero.character/`) holding the files the
/// engine already reads, in the places the tool and the game agree on.
///
/// ```
/// Hero.character/
///   Hero.rig.json
///   clips/walk.clip.json
///   images/torso.png
/// ```
public enum CharacterFiles {
    public static let packageExtension = "character"
    public static let rigSuffix = ".rig.json"
    public static let clipSuffix = ".clip.json"
    public static let clipsFolder = "clips"
    public static let imagesFolder = "images"

    // MARK: - FileWrapper (the app's document and the CLI share this)

    public static func read(_ wrapper: FileWrapper, name: String = "") throws -> Character {
        guard wrapper.isDirectory, let entries = wrapper.fileWrappers else { throw CharacterError.notAFolder(name) }
        let rigNames = entries.keys.filter { $0.hasSuffix(rigSuffix) }.sorted()
        guard let rigName = rigNames.first else { throw CharacterError.noRig(name) }
        guard rigNames.count == 1 else { throw CharacterError.severalRigs(rigNames) }
        let rig = try AnimationFiles.rig(from: try data(of: entries[rigName], named: rigName))

        var clips: [AnimationClip] = []
        if let clipEntries = entries[clipsFolder]?.fileWrappers {
            for clipName in clipEntries.keys.sorted() where clipName.hasSuffix(clipSuffix) {
                clips.append(try AnimationFiles.clip(from: try data(of: clipEntries[clipName], named: clipName)))
            }
        }
        var images: [String: Data] = [:]
        if let imageEntries = entries[imagesFolder]?.fileWrappers {
            for (fileName, entry) in imageEntries where fileName.lowercased().hasSuffix(".png") {
                images[String(fileName.dropLast(4))] = try data(of: entry, named: fileName)
            }
        }
        let character = Character(rig: rig, clips: clips, images: images)
        try validate(character)
        return character
    }

    /// `rigName` is the rig file's stem, usually the folder's.
    public static func wrapper(for character: Character, rigName: String) throws -> FileWrapper {
        try validate(character)
        var entries: [String: FileWrapper] = [:]
        entries[rigName + rigSuffix] = FileWrapper(regularFileWithContents: try AnimationFiles.data(for: character.rig))
        var clipEntries: [String: FileWrapper] = [:]
        for clip in character.clips {
            clipEntries[clip.name + clipSuffix] = FileWrapper(
                regularFileWithContents: try AnimationFiles.data(for: clip))
        }
        entries[clipsFolder] = FileWrapper(directoryWithFileWrappers: clipEntries)
        var imageEntries: [String: FileWrapper] = [:]
        for (name, data) in character.images {
            imageEntries[name + ".png"] = FileWrapper(regularFileWithContents: data)
        }
        entries[imagesFolder] = FileWrapper(directoryWithFileWrappers: imageEntries)
        return FileWrapper(directoryWithFileWrappers: entries)
    }

    // MARK: - URLs

    public static func load(at url: URL) throws -> Character {
        try read(try FileWrapper(url: url, options: .immediate), name: url.lastPathComponent)
    }

    /// Writes the whole folder. `rigName` defaults to the folder's stem.
    public static func save(_ character: Character, to url: URL, rigName: String? = nil) throws {
        let name = rigName ?? url.deletingPathExtension().lastPathComponent
        try wrapper(for: character, rigName: name).write(to: url, options: .atomic, originalContentsURL: nil)
    }

    /// A rig file with clips given by path and images looked up by name next
    /// to the rig, in an `images/` folder beside it, or one folder up: the
    /// demo's `Animations/` folder works without a `.character`.
    public static func load(rigAt rigURL: URL, clips clipURLs: [URL]) throws -> Character {
        let rig = try AnimationFiles.loadRig(at: rigURL)
        let clips = try clipURLs.map { try AnimationFiles.loadClip(at: $0) }
        let folder = rigURL.deletingLastPathComponent()
        var images: [String: Data] = [:]
        for attachment in rig.attachments {
            guard let name = attachment.textureName, images[name] == nil else { continue }
            for candidate in [folder, folder.appendingPathComponent(imagesFolder), folder.deletingLastPathComponent()] {
                let file = candidate.appendingPathComponent(name + ".png")
                if let data = try? Data(contentsOf: file) {
                    images[name] = data
                    break
                }
            }
        }
        let character = Character(rig: rig, clips: clips, images: images)
        try validate(character)
        return character
    }

    /// Every clip in a folder beside `rigURL` (or in its `clips/` folder).
    public static func clipURLs(besideRig rigURL: URL) -> [URL] {
        let folder = rigURL.deletingLastPathComponent()
        var urls: [URL] = []
        for candidate in [folder, folder.appendingPathComponent(clipsFolder)] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: candidate.path)) ?? []
            urls += names.filter { $0.hasSuffix(clipSuffix) }.sorted().map { candidate.appendingPathComponent($0) }
        }
        return urls
    }

    // MARK: - Checks

    /// The rig validates and every clip resolves against it.
    public static func validate(_ character: Character) throws {
        try character.rig.validate()
        var seen: Set<String> = []
        for clip in character.clips {
            guard seen.insert(clip.name).inserted else { throw CharacterError.duplicateClip(clip.name) }
            do {
                _ = try clip.resolved(for: character.rig)
            } catch {
                throw CharacterError.clipDoesNotFit(clip: clip.name, reason: "\(error)")
            }
        }
    }

    private static func data(of wrapper: FileWrapper?, named name: String) throws -> Data {
        guard let data = wrapper?.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: name])
        }
        return data
    }
}
