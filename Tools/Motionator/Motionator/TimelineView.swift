//
//  TimelineView.swift
//  Motionator
//
//  Created by Matt Casanova on 10/8/26.
//

import LiquidMetal2D
import MotionatorKit
import SwiftUI

/// Where things sit in the timeline, in points. Pure, so it can be tested.
nonisolated struct TimelineLayout: Equatable {
    var width: CGFloat
    var duration: Float
    static let labelWidth: CGFloat = 140
    static let rulerHeight: CGFloat = 22
    static let eventsHeight: CGFloat = 18
    static let rowHeight: CGFloat = 18
    static let rightMargin: CGFloat = 12

    enum Hit: Equatable {
        case ruler
        case events
        case bone(Int)
        case durationHandle
        case labels
        case none
    }

    var trackWidth: CGFloat { max(1, width - Self.labelWidth - Self.rightMargin) }

    func x(for time: Float) -> CGFloat {
        Self.labelWidth + CGFloat(time / max(duration, 1e-4)) * trackWidth
    }

    func time(for x: CGFloat) -> Float {
        let fraction = Float((x - Self.labelWidth) / trackWidth)
        return GameMath.clamp(value: fraction * duration, low: 0, high: duration)
    }

    func rowY(_ row: Int) -> CGFloat {
        Self.rulerHeight + Self.eventsHeight + CGFloat(row) * Self.rowHeight
    }

    func hit(_ point: CGPoint, rows: Int) -> Hit {
        if point.y < Self.rulerHeight {
            return abs(point.x - x(for: duration)) < 6 ? .durationHandle : .ruler
        }
        if point.x < Self.labelWidth { return .labels }
        if point.y < Self.rulerHeight + Self.eventsHeight { return .events }
        let row = Int((point.y - Self.rulerHeight - Self.eventsHeight) / Self.rowHeight)
        return row >= 0 && row < rows ? .bone(row) : .none
    }

    /// Seconds between ruler labels: about one every 60 points.
    var tickStep: Float {
        let steps: [Float] = [0.05, 0.1, 0.25, 0.5, 1, 2, 5]
        let wanted = duration / Float(trackWidth / 60)
        return steps.first { $0 >= wanted } ?? 5
    }
}

/// The clip's keys: a row per bone, a diamond per key time, an events row,
/// a ruler with the playhead. Click the ruler to scrub, drag a diamond to
/// move keys (Option copies), drag empty space to box-select, double-click
/// a row to key that bone at that time, double-click the events row to add
/// an event, drag the clip's end to change its length. Drawing is in
/// `TimelineView+Drawing`, the gestures in `TimelineView+Gestures`.
struct TimelineView: View {
    @ObservedObject var document: CharacterDocument
    let session: EditorSession
    @Environment(\.undoManager) var undoManager
    @State var gesture: TimelineGesture?
    @State var currentPoint: CGPoint?

    enum TimelineGesture {
        case scrub
        case moveKeys(keys: Set<KeyRef>, copy: Bool)
        case boxSelect(from: CGPoint)
        case moveEvent(Int)
        case duration
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = TimelineLayout(width: geometry.size.width, duration: clip?.duration ?? 1)
            Canvas { context, size in
                draw(in: &context, size: size, layout: layout)
            }
            .gesture(dragGesture(layout))
            .onTapGesture(count: 2) { point in doubleClick(at: point, layout: layout) }
            .contextMenu { contextMenu }
            .onDeleteCommand { deleteSelectedKeys() }
        }
        .background(Color(white: 0.13))
    }

    var clip: AnimationClip? { session.clip(in: document.character) }
    var rig: SkeletonDefinition { document.character.rig }

    @ViewBuilder
    private var contextMenu: some View {
        Menu("Easing") {
            ForEach(EasingType.allCases, id: \.self) { easing in
                Button(easing.rawValue) {
                    guard let clip else { return }
                    replace(ClipEditor.settingEasing(clip, session.selectedKeys, to: easing), named: "Set Easing")
                }
            }
        }
        .disabled(session.selectedKeys.isEmpty)
        Button("Delete Keys") { deleteSelectedKeys() }.disabled(session.selectedKeys.isEmpty)
        Button("Select All Keys") { if let clip { session.selectedKeys = ClipEditor.allKeys(in: clip) } }
    }

    func deleteSelectedKeys() {
        guard let clip, !session.selectedKeys.isEmpty else { return }
        replace(ClipEditor.removingKeys(clip, session.selectedKeys), named: "Delete Keys")
        session.selectedKeys = []
    }

    func replace(_ edited: AnimationClip, named name: String) {
        document.apply({ character in
            var character = character
            if let index = character.clips.firstIndex(where: { $0.name == edited.name }) {
                character.clips[index] = edited
            }
            return character
        }, named: name, undoManager: undoManager)
    }

    func depth(of bone: Int) -> Int {
        var depth = 0
        var parent = rig.bones[bone].parent
        while let current = parent {
            depth += 1
            parent = rig.bones[current].parent
        }
        return depth
    }
}
