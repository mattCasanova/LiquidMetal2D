//
//  TimelineView+Gestures.swift
//  Motionator
//
//  Created by Matt Casanova on 10/8/26.
//

import AppKit
import LiquidMetal2D
import MotionatorKit
import SwiftUI

extension TimelineView {
    func dragGesture(_ layout: TimelineLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                currentPoint = value.location
                if gesture == nil { gesture = begin(at: value.startLocation, layout: layout) }
                switch gesture {
                case .scrub, .duration: scrub(to: value.location.x, layout: layout)
                case .boxSelect(let from): selectKeys(inBox: from, to: value.location, layout: layout)
                case .moveEvent, .moveKeys, nil: break
                }
            }
            .onEnded { value in
                if let gesture { end(gesture, at: value, layout: layout) }
                gesture = nil
                currentPoint = nil
            }
    }

    // MARK: - Begin

    /// What a mouse-down on `point` starts.
    private func begin(at point: CGPoint, layout: TimelineLayout) -> TimelineGesture {
        guard let clip else { return .scrub }
        switch layout.hit(point, rows: rig.bones.count) {
        case .durationHandle:
            return .duration
        case .labels:
            if case .bone(let row) = layout.hit(CGPoint(x: TimelineLayout.labelWidth + 1, y: point.y),
                                                rows: rig.bones.count) {
                session.selection = .bone(row)
            }
            return .boxSelect(from: point)
        case .ruler, .none:
            return .scrub
        case .events:
            return beginOnEvents(at: point, layout: layout, clip: clip)
        case .bone(let row):
            return beginOnRow(row, at: point, layout: layout, clip: clip)
        }
    }

    private func beginOnEvents(at point: CGPoint, layout: TimelineLayout, clip: AnimationClip) -> TimelineGesture {
        let time = layout.time(for: point.x)
        let nearest = clip.events.indices.min { abs(clip.events[$0].time - time) < abs(clip.events[$1].time - time) }
        if let index = nearest, abs(layout.x(for: clip.events[index].time) - point.x) < 10 {
            session.selectedEvent = index
            return .moveEvent(index)
        }
        session.selectedEvent = nil
        return .scrub
    }

    /// A diamond under the pointer selects (Shift adds) and starts a move
    /// (Option copies); empty space starts a box selection.
    private func beginOnRow(
        _ row: Int, at point: CGPoint, layout: TimelineLayout, clip: AnimationClip
    ) -> TimelineGesture {
        let shift = NSEvent.modifierFlags.contains(.shift)
        let bone = rig.bones[row].name
        let time = layout.time(for: point.x)
        let tolerance = Float(6 / layout.trackWidth) * clip.duration
        let under = ClipEditor.keys(in: clip, at: time, tolerance: tolerance).filter { $0.bone == bone }
        guard !under.isEmpty else {
            if !shift { session.selectedKeys = [] }
            return .boxSelect(from: point)
        }
        session.selection = .bone(row)
        if shift {
            session.selectedKeys.formUnion(under)
        } else if !session.selectedKeys.isSuperset(of: under) {
            session.selectedKeys = under
        }
        return .moveKeys(keys: session.selectedKeys, copy: NSEvent.modifierFlags.contains(.option))
    }

    // MARK: - During

    private func scrub(to x: CGFloat, layout: TimelineLayout) {
        session.isPlaying = false
        session.playhead = ClipEditor.snapped(layout.time(for: x), fps: session.fps)
    }

    private func selectKeys(inBox from: CGPoint, to point: CGPoint, layout: TimelineLayout) {
        guard let clip else { return }
        let xs = min(from.x, point.x)...max(from.x, point.x)
        let ys = min(from.y, point.y)...max(from.y, point.y)
        var found: Set<KeyRef> = []
        for (index, bone) in rig.bones.enumerated() {
            let y = layout.rowY(index) + TimelineLayout.rowHeight / 2
            guard ys.contains(y), let track = clip.tracks.first(where: { $0.bone == bone.name }) else { continue }
            for key in track.rotation where xs.contains(layout.x(for: key.time)) {
                found.insert(KeyRef(bone: bone.name, channel: .rotation, time: key.time))
            }
            for key in track.position where xs.contains(layout.x(for: key.time)) {
                found.insert(KeyRef(bone: bone.name, channel: .position, time: key.time))
            }
        }
        session.selectedKeys = found
    }

    // MARK: - End

    private func end(_ gesture: TimelineGesture, at value: DragGesture.Value, layout: TimelineLayout) {
        guard let clip else { return }
        let moved = Float(value.translation.width / layout.trackWidth) * clip.duration
        switch gesture {
        case .moveKeys(let keys, let copy):
            guard abs(value.translation.width) > 3 else { return }
            let delta = ClipEditor.snapped(moved, fps: session.fps)
            let edited = copy ? ClipEditor.duplicatingKeys(clip, keys, by: delta)
                              : ClipEditor.movingKeys(clip, keys, by: delta)
            replace(edited, named: copy ? "Copy Keys" : "Move Keys")
            session.selectedKeys = Set(keys.map {
                KeyRef(bone: $0.bone, channel: $0.channel,
                       time: GameMath.clamp(value: $0.time + delta, low: 0, high: clip.duration))
            })
        case .moveEvent(let index):
            let time = ClipEditor.snapped(layout.time(for: value.location.x), fps: session.fps)
            replace(ClipEditor.movingEvent(clip, at: index, to: time), named: "Move Event")
        case .duration:
            let duration = max(0.05, ClipEditor.snapped(clip.duration + moved, fps: session.fps))
            replace(ClipEditor.settingDuration(clip, to: duration, scalingKeys: false), named: "Change Duration")
        case .scrub, .boxSelect:
            break
        }
    }

    /// A row keys its bone from the current pose; the events row adds an event.
    func doubleClick(at point: CGPoint, layout: TimelineLayout) {
        guard let clip else { return }
        let time = ClipEditor.snapped(layout.time(for: point.x), fps: session.fps)
        switch layout.hit(point, rows: rig.bones.count) {
        case .bone(let row):
            guard let pose = try? ClipEditor.pose(of: clip, rig: rig, at: session.playhead) else { return }
            replace(ClipEditor.keyingBone(clip, bone: row, pose: pose, rig: rig, at: time), named: "Key Bone")
        case .events:
            let added = ClipEditor.addingEvent(clip, named: "event", at: time)
            replace(added, named: "Add Event")
            session.selectedEvent = added.events.firstIndex { abs($0.time - time) < 1e-4 && $0.name == "event" }
        default:
            break
        }
    }
}
