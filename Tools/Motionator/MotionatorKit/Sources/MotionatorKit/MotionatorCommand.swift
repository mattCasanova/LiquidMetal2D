//
//  MotionatorCommand.swift
//  MotionatorKit
//
//  Created by Matt Casanova on 10/6/26.
//

import Foundation
import LiquidMetal2D

/// The `motionator` command line: `sheet`, `info` and `validate`. Lives in
/// the Kit so tests can run it; the executable is one line.
public enum MotionatorCommand {
    public static let usage = """
    usage:
      motionator sheet <Hero.character | rig.json> [clip] [--frames 8] [--size 256] [--ghost] [--no-labels]
                       [--out file.png]
      motionator info <Hero.character | rig.json>
      motionator validate <Hero.character | rig.json>
      motionator pack <rig.json> <Hero.character>
    A rig path takes the clips beside it (or in clips/); a clip may be a name or a .clip.json path.
    pack writes a rig and the clips and images beside it as one .character folder.
    """

    public enum ExitCode {
        public static let ok: Int32 = 0
        public static let badArguments: Int32 = 1
        public static let failed: Int32 = 2
    }

    /// Runs one command; returns the exit code. `out` gets stdout lines, `err` stderr lines.
    @MainActor
    public static func run(_ arguments: [String], out: (String) -> Void, err: (String) -> Void) -> Int32 {
        guard let command = arguments.first else {
            err(usage)
            return ExitCode.badArguments
        }
        do {
            switch command {
            case "sheet": return try sheet(Array(arguments.dropFirst()), out: out, err: err)
            case "info": return try info(Array(arguments.dropFirst()), out: out, err: err)
            case "validate": return try validate(Array(arguments.dropFirst()), out: out, err: err)
            case "pack": return try pack(Array(arguments.dropFirst()), out: out, err: err)
            default:
                err("unknown command \(command)\n" + usage)
                return ExitCode.badArguments
            }
        } catch {
            err("\(error)")
            return ExitCode.failed
        }
    }

    // MARK: - Commands

    /// The `sheet` command's arguments, parsed.
    struct SheetOptions {
        var sheet = ContactSheet()
        var outPath: String?
        var positional: [String] = []

        /// Nil with a message when the arguments make no sense.
        static func parse(_ arguments: [String]) -> (options: SheetOptions?, problem: String?) {
            var options = SheetOptions()
            var index = 0
            while index < arguments.count {
                let argument = arguments[index]
                switch argument {
                case "--frames", "--size", "--out":
                    guard index + 1 < arguments.count else { return (nil, "\(argument) needs a value") }
                    let value = arguments[index + 1]
                    index += 1
                    if let problem = options.take(argument, value) { return (nil, problem) }
                case "--ghost": options.sheet.ghost = true
                case "--no-labels": options.sheet.labels = false
                default:
                    guard !argument.hasPrefix("--") else { return (nil, "unknown option \(argument)") }
                    options.positional.append(argument)
                }
                index += 1
            }
            guard !options.positional.isEmpty, options.positional.count <= 2 else { return (nil, usage) }
            return (options, nil)
        }

        private mutating func take(_ option: String, _ value: String) -> String? {
            switch option {
            case "--frames":
                guard let frames = Int(value), frames > 0 else { return "--frames needs a count" }
                sheet.frames = frames
            case "--size":
                guard let size = Int(value), size >= 16 else { return "--size needs pixels (16 or more)" }
                sheet.cellSize = size
            default: outPath = value
            }
            return nil
        }
    }

    @MainActor
    private static func sheet(_ arguments: [String], out: (String) -> Void, err: (String) -> Void) throws -> Int32 {
        let (parsed, problem) = SheetOptions.parse(arguments)
        guard let options = parsed else { return bad(problem ?? usage, err) }
        let sheet = options.sheet
        let positional = options.positional
        var character = try load(positional[0])
        var clipName = positional.count == 2 ? positional[1] : nil
        if let name = clipName, name.hasSuffix(CharacterFiles.clipSuffix) {
            let clip = try AnimationFiles.loadClip(at: URL(fileURLWithPath: name))
            character.clips.removeAll { $0.name == clip.name }
            character.clips.append(clip)
            clipName = clip.name
        }
        if clipName == nil {
            guard character.clips.count == 1 else {
                return bad("which clip? one of: " + character.clips.map(\.name).joined(separator: ", "), err)
            }
            clipName = character.clips[0].name
        }
        guard let clipName else { return bad(usage, err) }
        for name in character.missingImages { err("warning: no image for \(name); drawn white") }
        let image = try sheet.render(character, clip: clipName)
        let url = URL(fileURLWithPath: options.outPath ?? "\(clipName).sheet.png")
        try ContactSheet.writePNG(image, to: url)
        out("wrote \(url.path): \(sheet.frames) frames of \(clipName), \(image.width)×\(image.height)")
        return ExitCode.ok
    }

    private static func info(_ arguments: [String], out: (String) -> Void, err: (String) -> Void) throws -> Int32 {
        guard arguments.count == 1 else { return bad(usage, err) }
        let character = try load(arguments[0])
        let rig = character.rig
        out("bones (\(rig.bones.count)): index name parent length rest(x y deg)")
        for (index, bone) in rig.bones.enumerated() {
            let parent = bone.parent.map { rig.bones[$0].name } ?? "-"
            out(String(format: "  %2d %@ %@ %.3f (%.3f %.3f %.1f°)", index, bone.name, parent, bone.length,
                       bone.rest.position.x, bone.rest.position.y, bone.rest.rotation * 180 / .pi))
        }
        out("attachments (\(rig.attachments.count)): name bone size image order")
        for attachment in rig.attachments.sorted(by: { $0.drawOrder < $1.drawOrder }) {
            out(String(format: "  %@ %@ %.2f×%.2f %@ %d", attachment.name, rig.bones[attachment.bone].name,
                       attachment.size.x, attachment.size.y, attachment.textureName ?? "(white)", attachment.drawOrder))
        }
        out("clips (\(character.clips.count)): name duration loops keys events")
        for clip in character.clips {
            let events = clip.events.map { "\($0.name)@\($0.time)" }.joined(separator: " ")
            out("  \(clip.name) \(clip.duration)s \(clip.loops ? "loops" : "once") "
                + "\(ClipEditor.allKeys(in: clip).count) keys \(events)")
        }
        let missing = character.missingImages
        if !missing.isEmpty { out("missing images: " + missing.joined(separator: ", ")) }
        return ExitCode.ok
    }

    private static func validate(_ arguments: [String], out: (String) -> Void, err: (String) -> Void) throws -> Int32 {
        guard arguments.count == 1 else { return bad(usage, err) }
        let character = try load(arguments[0])    // throws on a bad rig or clip
        let missing = character.missingImages
        guard missing.isEmpty else {
            err("missing images: " + missing.joined(separator: ", "))
            return ExitCode.failed
        }
        out("ok: \(character.rig.bones.count) bones, \(character.rig.attachments.count) parts, "
            + "\(character.clips.count) clips, \(character.images.count) images")
        return ExitCode.ok
    }

    private static func pack(_ arguments: [String], out: (String) -> Void, err: (String) -> Void) throws -> Int32 {
        guard arguments.count == 2, arguments[0].hasSuffix(CharacterFiles.rigSuffix),
              arguments[1].hasSuffix("." + CharacterFiles.packageExtension) else { return bad(usage, err) }
        let character = try load(arguments[0])
        let url = URL(fileURLWithPath: arguments[1])
        try CharacterFiles.save(character, to: url)
        out("wrote \(url.path): \(character.clips.count) clips, \(character.images.count) images")
        return ExitCode.ok
    }

    // MARK: - Helpers

    /// A `.character` folder, or a rig file with the clips beside it.
    public static func load(_ path: String) throws -> Character {
        let url = URL(fileURLWithPath: path)
        if path.hasSuffix(CharacterFiles.rigSuffix) {
            return try CharacterFiles.load(rigAt: url, clips: CharacterFiles.clipURLs(besideRig: url))
        }
        return try CharacterFiles.load(at: url)
    }

    private static func bad(_ message: String, _ err: (String) -> Void) -> Int32 {
        err(message)
        return ExitCode.badArguments
    }
}
