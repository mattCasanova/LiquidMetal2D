//
//  AnimationClip.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

/// The keys for one bone. Either channel may be empty, which leaves that
/// part of the bone at its rest transform.
///
/// Values are the bone's full local rotation and position, not offsets from rest.
public struct BoneTrack: Codable, Equatable, Sendable {
    /// Bone name. Files refer to bones by name; ``AnimationClip/resolved(for:)`` turns it into an index.
    public var bone: String
    public var rotation: [Keyframe<Float>]
    public var position: [Keyframe<Vec2>]

    public init(bone: String, rotation: [Keyframe<Float>] = [], position: [Keyframe<Vec2>] = []) {
        self.bone = bone
        self.rotation = rotation
        self.position = position
    }
}

/// A named, keyframed animation, as stored in a file.
///
/// Resolve it against a rig once at load time, then play the ``ResolvedClip``.
public struct AnimationClip: Codable, Equatable, Sendable {
    public var name: String
    /// Length in seconds. Must be greater than zero.
    public var duration: Float
    public var loops: Bool
    public var tracks: [BoneTrack]

    public init(name: String, duration: Float, loops: Bool, tracks: [BoneTrack]) {
        self.name = name
        self.duration = duration
        self.loops = loops
        self.tracks = tracks
    }

    /// Checks the clip against `definition` and swaps bone names for indices,
    /// so sampling does no string lookups.
    public func resolved(for definition: SkeletonDefinition) throws -> ResolvedClip {
        guard duration > 0 else { throw SkeletonError.invalidDuration(clip: name) }

        let resolvedTracks = try tracks.map { track in
            guard track.rotation.isSortedByTime(), track.position.isSortedByTime() else {
                throw SkeletonError.keysNotSorted(bone: track.bone)
            }
            return ResolvedClip.Track(
                boneIndex: try definition.boneIndex(named: track.bone),
                rotation: track.rotation,
                position: track.position)
        }

        return ResolvedClip(
            name: name, duration: duration, loops: loops,
            boneCount: definition.bones.count, tracks: resolvedTracks)
    }
}

/// A clip ready to play against one rig: bone names already turned into indices.
public struct ResolvedClip: Equatable, Sendable {
    struct Track: Equatable, Sendable {
        let boneIndex: Int
        let rotation: [Keyframe<Float>]
        let position: [Keyframe<Vec2>]
    }

    public let name: String
    public let duration: Float
    public let loops: Bool
    let boneCount: Int
    let tracks: [Track]

    /// Writes the clip's pose at `time` into `pose`.
    ///
    /// Every bone starts from rest, then keyed channels overwrite it. A looping
    /// clip wraps `time`; a one-shot clip clamps it to `0...duration`.
    public func sample(at time: Float, definition: SkeletonDefinition, into pose: inout Pose) {
        precondition(
            definition.bones.count == boneCount,
            "Clip \(name) was resolved for \(boneCount) bones, sampled with \(definition.bones.count)")

        let t = loops
            ? GameMath.wrap(value: time, low: 0, high: duration)
            : GameMath.clamp(value: time, low: 0, high: duration)

        pose.reset(to: definition)
        for track in tracks {
            if let rotation = track.rotation.sample(at: t, lerp: { GameMath.lerp(a: $0, b: $1, t: $2) }) {
                pose.local[track.boneIndex].rotation = rotation
            }
            if let position = track.position.sample(at: t, lerp: { GameMath.lerp(a: $0, b: $1, t: $2) }) {
                pose.local[track.boneIndex].position = position
            }
        }
    }
}
