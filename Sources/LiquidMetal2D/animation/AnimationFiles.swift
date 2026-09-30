//
//  AnimationFiles.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/29/26.
//

import Foundation

/// Rig and clip files: one ``SkeletonDefinition`` per `name.rig.json`, one
/// ``AnimationClip`` per `name.clip.json`.
///
/// Inside a rig, a bone's `parent` and an attachment's `bone` are indices into
/// the rig's `bones`. Clips name their bones instead, so a clip works with any
/// rig that has bones of those names.
///
/// Reading accepts JSON5 (comments, trailing commas, unquoted keys) for hand
/// edits. Writing gives plain JSON, pretty-printed with sorted keys so files
/// diff cleanly, listing every field that has a value. A file may leave out
/// any field that has a default in code:
/// - a key's `easing` (linear)
/// - a clip's `events` and a track's `rotation` / `position` keys (none)
/// - an attachment's `rotation` (0), `textureName` (the default texture),
///   `region` (the whole texture), `tint` (white) and `drawOrder` (0)
/// - a bone's rest `position` and `rotation` (zero)
///
/// Angles are radians. Vectors are arrays: `[x, y]`, colours `[r, g, b, a]`.
/// Files carry no version number yet; one without it is version 1.
public enum AnimationFiles {

    /// A decoder for rig and clip files, JSON5 allowed.
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return decoder
    }

    /// An encoder for rig and clip files: pretty-printed, keys sorted.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// Decodes a rig and checks it with ``SkeletonDefinition/validate()``.
    /// - Throws: `DecodingError` for malformed JSON or a missing field; a
    ///   ``SkeletonError`` for a rig that decodes but is invalid.
    public static func rig(from data: Data) throws -> SkeletonDefinition {
        let rig = try makeDecoder().decode(SkeletonDefinition.self, from: data)
        try rig.validate()
        return rig
    }

    /// Decodes a clip. Its bones and keys are checked against a rig when it is
    /// resolved: ``AnimationClip/resolved(for:)``.
    /// - Throws: `DecodingError` for malformed JSON or a missing field.
    public static func clip(from data: Data) throws -> AnimationClip {
        try makeDecoder().decode(AnimationClip.self, from: data)
    }

    /// Reads and checks a rig file. See ``rig(from:)``.
    public static func loadRig(at url: URL) throws -> SkeletonDefinition {
        try rig(from: Data(contentsOf: url))
    }

    /// Reads a clip file. See ``clip(from:)``.
    public static func loadClip(at url: URL) throws -> AnimationClip {
        try clip(from: Data(contentsOf: url))
    }

    /// A rig as file contents: every field with a value, ending in a newline.
    public static func data(for rig: SkeletonDefinition) throws -> Data {
        try fileContents(makeEncoder().encode(rig))
    }

    /// A clip as file contents: every field with a value, ending in a newline.
    public static func data(for clip: AnimationClip) throws -> Data {
        try fileContents(makeEncoder().encode(clip))
    }

    private static func fileContents(_ json: Data) -> Data {
        json + Data("\n".utf8)
    }
}
