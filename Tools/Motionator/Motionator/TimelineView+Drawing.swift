//
//  TimelineView+Drawing.swift
//  Motionator
//
//  Created by Matt Casanova on 10/8/26.
//

import LiquidMetal2D
import MotionatorKit
import SwiftUI

extension TimelineView {
    func draw(in context: inout GraphicsContext, size: CGSize, layout: TimelineLayout) {
        guard let clip else {
            context.draw(Text("No clip. Add one with the + beside the clip menu.").foregroundStyle(.secondary),
                         at: CGPoint(x: size.width / 2, y: size.height / 2))
            return
        }
        drawRows(in: &context, size: size, layout: layout)
        drawGrid(in: &context, size: size, layout: layout, clip: clip)
        drawEvents(in: &context, layout: layout, clip: clip)
        drawKeys(in: &context, layout: layout, clip: clip)
        drawCursors(in: &context, size: size, layout: layout, clip: clip)
    }

    private func drawRows(in context: inout GraphicsContext, size: CGSize, layout: TimelineLayout) {
        for (index, bone) in rig.bones.enumerated() {
            let y = layout.rowY(index)
            if index.isMultiple(of: 2) {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: TimelineLayout.rowHeight)),
                             with: .color(Color(white: 0.16)))
            }
            let colour: Color = session.selectedBone == index ? .orange
                : session.pendingBones.contains(bone.name) ? .orange.opacity(0.8) : .primary
            context.draw(Text(bone.name).font(.system(size: 11)).foregroundStyle(colour),
                         at: CGPoint(x: 8 + CGFloat(depth(of: index)) * 10, y: y + TimelineLayout.rowHeight / 2),
                         anchor: .leading)
        }
    }

    /// Frame lines when they fit, then the ruler's ticks and labels.
    private func drawGrid(
        in context: inout GraphicsContext, size: CGSize, layout: TimelineLayout, clip: AnimationClip
    ) {
        if let fps = session.fps {
            let frames = Int((clip.duration * Float(fps)).rounded(.down))
            if frames <= Int(layout.trackWidth / 4) {
                for frame in 0...frames {
                    let x = layout.x(for: Float(frame) / Float(fps))
                    context.stroke(verticalLine(at: x, from: TimelineLayout.rulerHeight, to: size.height),
                                   with: .color(Color(white: 0.2)), lineWidth: 1)
                }
            }
        }
        var tick: Float = 0
        while tick <= clip.duration + 1e-4 {
            let x = layout.x(for: tick)
            context.stroke(verticalLine(at: x, from: 0, to: size.height),
                           with: .color(Color(white: 0.28)), lineWidth: 1)
            context.draw(Text(String(format: "%.2f", tick)).font(.system(size: 9)).foregroundStyle(.secondary),
                         at: CGPoint(x: x + 3, y: 4), anchor: .topLeading)
            tick += layout.tickStep
        }
    }

    private func drawEvents(in context: inout GraphicsContext, layout: TimelineLayout, clip: AnimationClip) {
        let top = TimelineLayout.rulerHeight
        context.fill(Path(CGRect(x: TimelineLayout.labelWidth, y: top, width: layout.trackWidth,
                                 height: TimelineLayout.eventsHeight)), with: .color(Color(white: 0.11)))
        context.draw(Text("events").font(.system(size: 10)).foregroundStyle(.secondary),
                     at: CGPoint(x: 8, y: top + TimelineLayout.eventsHeight / 2), anchor: .leading)
        for (index, event) in clip.events.enumerated() {
            let x = layout.x(for: event.time)
            let flag = Path { path in
                path.move(to: CGPoint(x: x, y: top + 2))
                path.addLine(to: CGPoint(x: x + 8, y: top + 6))
                path.addLine(to: CGPoint(x: x, y: top + 10))
                path.closeSubpath()
                path.move(to: CGPoint(x: x, y: top + 2))
                path.addLine(to: CGPoint(x: x, y: top + TimelineLayout.eventsHeight - 2))
            }
            let colour: Color = session.selectedEvent == index ? .orange : .yellow
            context.fill(flag, with: .color(colour))
            context.stroke(flag, with: .color(colour), lineWidth: 1)
            context.draw(Text(event.name).font(.system(size: 9)).foregroundStyle(colour),
                         at: CGPoint(x: x + 11, y: top + TimelineLayout.eventsHeight / 2), anchor: .leading)
        }
    }

    /// One diamond per bone and time; rotation and position keys at the same time share it.
    private func drawKeys(in context: inout GraphicsContext, layout: TimelineLayout, clip: AnimationClip) {
        for (index, bone) in rig.bones.enumerated() {
            guard let track = clip.tracks.first(where: { $0.bone == bone.name }) else { continue }
            let all = track.rotation.map(\.time) + track.position.map(\.time)
            let times = Set(all.map { ($0 * 1e4).rounded() / 1e4 })
            for time in times {
                let selected = session.selectedKeys.contains { $0.bone == bone.name && abs($0.time - time) < 1e-3 }
                let centre = CGPoint(x: layout.x(for: time), y: layout.rowY(index) + TimelineLayout.rowHeight / 2)
                context.fill(diamond(at: centre), with: .color(selected ? .orange : Color(white: 0.85)))
            }
        }
    }

    /// The box selection, the clip's end and the playhead.
    private func drawCursors(
        in context: inout GraphicsContext, size: CGSize, layout: TimelineLayout, clip: AnimationClip
    ) {
        if case .boxSelect(let from) = gesture, let current = currentPoint {
            let box = CGRect(x: min(from.x, current.x), y: min(from.y, current.y),
                             width: abs(current.x - from.x), height: abs(current.y - from.y))
            context.stroke(Path(box), with: .color(.orange.opacity(0.7)), lineWidth: 1)
        }
        let endX = layout.x(for: clip.duration)
        context.fill(Path(CGRect(x: endX, y: 0, width: size.width - endX, height: size.height)),
                     with: .color(Color.black.opacity(0.35)))
        context.fill(Path(CGRect(x: endX - 2, y: 0, width: 4, height: TimelineLayout.rulerHeight)), with: .color(.gray))
        context.stroke(verticalLine(at: layout.x(for: session.playhead), from: 0, to: size.height),
                       with: .color(.red), lineWidth: 1.5)
    }

    private func verticalLine(at x: CGFloat, from top: CGFloat, to bottom: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: x, y: top))
            path.addLine(to: CGPoint(x: x, y: bottom))
        }
    }

    private func diamond(at centre: CGPoint) -> Path {
        Path { path in
            path.move(to: CGPoint(x: centre.x, y: centre.y - 5))
            path.addLine(to: CGPoint(x: centre.x + 5, y: centre.y))
            path.addLine(to: CGPoint(x: centre.x, y: centre.y + 5))
            path.addLine(to: CGPoint(x: centre.x - 5, y: centre.y))
            path.closeSubpath()
        }
    }
}
