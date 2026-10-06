//
//  ClipEditor.swift
//  MotionatorKit
//
//  Created by Matt Casanova on 10/6/26.
//

import Foundation
import LiquidMetal2D

/// Edits on a clip. Every function returns the new clip and leaves the old
/// one alone, so undo is keeping the old value.
public enum ClipEditor {
    public enum Channel: Hashable, Sendable {
        case rotation, position
    }

    /// A key's value; it says which channel it belongs to.
    public enum KeyValue: Equatable, Sendable {
        case rotation(Float)
        case position(Vec2)

        public var channel: Channel {
            switch self {
            case .rotation: .rotation
            case .position: .position
            }
        }
    }

    /// Two keys closer than this in time are the same key.
    public static let timeTolerance: Float = 1e-4

    // MARK: - Keys

    /// Writes a key, replacing one at the same time. A new key takes
    /// `easing` or, when nil, the easing of the key it replaces, else of the
    /// key before it, else linear. A bone with no track gets one.
    public static func settingKey(
        _ clip: AnimationClip, bone: String, time: Float, value: KeyValue, easing: EasingType? = nil
    ) -> AnimationClip {
        var clip = clip
        let trackIndex = indexOfTrack(for: bone, in: &clip)
        switch value {
        case .rotation(let rotation):
            clip.tracks[trackIndex].rotation = inserting(
                Keyframe(time: time, value: rotation), easing: easing, into: clip.tracks[trackIndex].rotation)
        case .position(let position):
            clip.tracks[trackIndex].position = inserting(
                Keyframe(time: time, value: position), easing: easing, into: clip.tracks[trackIndex].position)
        }
        return clip
    }

    public static func removingKey(
        _ clip: AnimationClip, bone: String, channel: Channel, time: Float
    ) -> AnimationClip {
        removingKeys(clip, [KeyRef(bone: bone, channel: channel, time: time)])
    }

    public static func removingKeys(_ clip: AnimationClip, _ keys: Set<KeyRef>) -> AnimationClip {
        var clip = clip
        for key in keys {
            guard let trackIndex = clip.tracks.firstIndex(where: { $0.bone == key.bone }) else { continue }
            switch key.channel {
            case .rotation: clip.tracks[trackIndex].rotation.removeAll { isSameTime($0.time, key.time) }
            case .position: clip.tracks[trackIndex].position.removeAll { isSameTime($0.time, key.time) }
            }
        }
        clip.tracks.removeAll { $0.rotation.isEmpty && $0.position.isEmpty }
        return clip
    }

    /// Shifts the keys by `delta`, clamped to the clip; a moved key replaces
    /// a stationary one it lands on.
    public static func movingKeys(_ clip: AnimationClip, _ keys: Set<KeyRef>, by delta: Float) -> AnimationClip {
        var moved = removingKeys(clip, keys)
        for key in keys {
            guard let track = clip.tracks.first(where: { $0.bone == key.bone }) else { continue }
            let time = GameMath.clamp(value: key.time + delta, low: 0, high: clip.duration)
            switch key.channel {
            case .rotation:
                guard let frame = track.rotation.first(where: { isSameTime($0.time, key.time) }) else { continue }
                moved = settingKey(
                    moved, bone: key.bone, time: time, value: .rotation(frame.value), easing: frame.easing)
            case .position:
                guard let frame = track.position.first(where: { isSameTime($0.time, key.time) }) else { continue }
                moved = settingKey(
                    moved, bone: key.bone, time: time, value: .position(frame.value), easing: frame.easing)
            }
        }
        return moved
    }

    public static func settingEasing(
        _ clip: AnimationClip, _ keys: Set<KeyRef>, to easing: EasingType
    ) -> AnimationClip {
        var clip = clip
        for key in keys {
            guard let trackIndex = clip.tracks.firstIndex(where: { $0.bone == key.bone }) else { continue }
            switch key.channel {
            case .rotation:
                for index in clip.tracks[trackIndex].rotation.indices
                where isSameTime(clip.tracks[trackIndex].rotation[index].time, key.time) {
                    clip.tracks[trackIndex].rotation[index].easing = easing
                }
            case .position:
                for index in clip.tracks[trackIndex].position.indices
                where isSameTime(clip.tracks[trackIndex].position[index].time, key.time) {
                    clip.tracks[trackIndex].position[index].easing = easing
                }
            }
        }
        return clip
    }

    /// Every key within `tolerance` of `time`.
    public static func keys(in clip: AnimationClip, at time: Float, tolerance: Float = timeTolerance) -> Set<KeyRef> {
        var found: Set<KeyRef> = []
        for track in clip.tracks {
            for frame in track.rotation where abs(frame.time - time) <= tolerance {
                found.insert(KeyRef(bone: track.bone, channel: .rotation, time: frame.time))
            }
            for frame in track.position where abs(frame.time - time) <= tolerance {
                found.insert(KeyRef(bone: track.bone, channel: .position, time: frame.time))
            }
        }
        return found
    }

    /// All the clip's keys.
    public static func allKeys(in clip: AnimationClip) -> Set<KeyRef> {
        var found: Set<KeyRef> = []
        for track in clip.tracks {
            for frame in track.rotation { found.insert(KeyRef(bone: track.bone, channel: .rotation, time: frame.time)) }
            for frame in track.position { found.insert(KeyRef(bone: track.bone, channel: .position, time: frame.time)) }
        }
        return found
    }

    /// The key's value and easing, if it exists.
    public static func key(in clip: AnimationClip, _ ref: KeyRef) -> (value: KeyValue, easing: EasingType)? {
        guard let track = clip.tracks.first(where: { $0.bone == ref.bone }) else { return nil }
        switch ref.channel {
        case .rotation:
            return track.rotation.first { isSameTime($0.time, ref.time) }.map { (.rotation($0.value), $0.easing) }
        case .position:
            return track.position.first { isSameTime($0.time, ref.time) }.map { (.position($0.value), $0.easing) }
        }
    }

    // MARK: - Poses

    /// The clip's pose at `time`, as the engine would play it.
    public static func pose(of clip: AnimationClip, rig: SkeletonDefinition, at time: Float) throws -> Pose {
        var pose = Pose(restOf: rig)
        try clip.resolved(for: rig).sample(at: time, definition: rig, into: &pose)
        return pose
    }

    /// Keys every channel of `pose` that differs from the rig's rest at
    /// `time`; channels at rest get no key.
    public static func pastingPose(
        _ pose: Pose, into clip: AnimationClip, rig: SkeletonDefinition, at time: Float
    ) -> AnimationClip {
        var clip = clip
        for (index, bone) in rig.bones.enumerated() where index < pose.local.count {
            let local = pose.local[index]
            if abs(local.rotation - bone.rest.rotation) > 1e-6 {
                clip = settingKey(clip, bone: bone.name, time: time, value: .rotation(local.rotation))
            }
            if simd_length(local.position - bone.rest.position) > 1e-6 {
                clip = settingKey(clip, bone: bone.name, time: time, value: .position(local.position))
            }
        }
        return clip
    }

    // MARK: - Duration and events

    /// Changes the length. `scalingKeys` stretches every key and event time
    /// in proportion; otherwise times stay and what lies past the end is dropped.
    public static func settingDuration(_ clip: AnimationClip, to duration: Float, scalingKeys: Bool) -> AnimationClip {
        precondition(duration > 0, "a clip needs a duration above zero")
        var clip = clip
        let factor = duration / clip.duration
        for index in clip.tracks.indices {
            if scalingKeys {
                for key in clip.tracks[index].rotation.indices { clip.tracks[index].rotation[key].time *= factor }
                for key in clip.tracks[index].position.indices { clip.tracks[index].position[key].time *= factor }
            } else {
                clip.tracks[index].rotation.removeAll { $0.time > duration + timeTolerance }
                clip.tracks[index].position.removeAll { $0.time > duration + timeTolerance }
            }
        }
        clip.tracks.removeAll { $0.rotation.isEmpty && $0.position.isEmpty }
        if scalingKeys {
            for index in clip.events.indices { clip.events[index].time *= factor }
        } else {
            clip.events.removeAll { $0.time > duration + timeTolerance }
        }
        clip.duration = duration
        return clip
    }

    public static func addingEvent(_ clip: AnimationClip, named name: String, at time: Float) -> AnimationClip {
        var clip = clip
        clip.events.append(AnimationEvent(time: time, name: name))
        clip.events.sort { $0.time < $1.time }
        return clip
    }

    public static func movingEvent(_ clip: AnimationClip, at index: Int, to time: Float) -> AnimationClip {
        var clip = clip
        clip.events[index].time = GameMath.clamp(value: time, low: 0, high: clip.duration)
        clip.events.sort { $0.time < $1.time }
        return clip
    }

    public static func renamingEvent(_ clip: AnimationClip, at index: Int, to name: String) -> AnimationClip {
        var clip = clip
        clip.events[index].name = name
        return clip
    }

    public static func removingEvent(_ clip: AnimationClip, at index: Int) -> AnimationClip {
        var clip = clip
        clip.events.remove(at: index)
        return clip
    }

    // MARK: - Private

    static func isSameTime(_ a: Float, _ b: Float) -> Bool { abs(a - b) <= timeTolerance }

    private static func indexOfTrack(for bone: String, in clip: inout AnimationClip) -> Int {
        if let index = clip.tracks.firstIndex(where: { $0.bone == bone }) { return index }
        clip.tracks.append(BoneTrack(bone: bone))
        return clip.tracks.count - 1
    }

    private static func inserting<Value>(
        _ key: Keyframe<Value>, easing: EasingType?, into keys: [Keyframe<Value>]
    ) -> [Keyframe<Value>] {
        var keys = keys
        var key = key
        if let existing = keys.firstIndex(where: { isSameTime($0.time, key.time) }) {
            key.easing = easing ?? keys[existing].easing
            keys[existing] = key
            return keys
        }
        let insertAt = keys.firstIndex { $0.time > key.time } ?? keys.count
        key.easing = easing ?? (insertAt > 0 ? keys[insertAt - 1].easing : .linear)
        keys.insert(key, at: insertAt)
        return keys
    }
}

/// One key: a bone, a channel and a time.
public struct KeyRef: Hashable, Sendable {
    public var bone: String
    public var channel: ClipEditor.Channel
    public var time: Float

    public init(bone: String, channel: ClipEditor.Channel, time: Float) {
        self.bone = bone
        self.channel = channel
        self.time = time
    }
}
