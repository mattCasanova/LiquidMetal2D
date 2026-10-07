//
//  EditorScene+Pointer.swift
//  Motionator
//
//  Created by Matt Casanova on 10/8/26.
//

import LiquidMetal2D
import MotionatorKit

/// Clicks and drags in the viewport.
extension EditorScene {
    func handlePointer(_ rig: SkeletonDefinition, pose: Pose) {
        let session = editor.session
        let scroll = input.pointer.scrollDelta.y
        if scroll != 0 {
            session.cameraDistance = GameMath.clamp(
                value: session.cameraDistance * pow(1.05, -scroll), low: 2, high: 400)
        }
        let world = input.pointerWorld(forZ: 0).map { Vec2($0.x, $0.y) }

        if input.isTriggered(.pointerPrimary), let point = world {
            drag = beginDrag(at: point, rig: rig, pose: pose)
            lastPointer = point
        } else if input.isPressed(.pointerPrimary), let point = world, let drag {
            continueDrag(drag, to: point, rig: rig)
        } else if input.isReleased(.pointerPrimary) {
            endDrag(rig: rig)
        }
        renderer.setCamera(point: Vec3(session.cameraCentre.x, session.cameraCentre.y, session.cameraDistance))
    }

    /// A few pixels, in world units at the current zoom.
    var hitTolerance: Float { editor.session.cameraDistance * 0.02 }

    // MARK: - Begin

    /// What is under the pointer decides the drag; empty space pans. The
    /// selected bone keeps a drag when it is under the pointer, even beneath
    /// bones drawn over it.
    private func beginDrag(at point: Vec2, rig: SkeletonDefinition, pose: Pose) -> Drag {
        let session = editor.session
        clickStack = nil
        let world = session.mode == .setup
            ? RigEditor.restWorld(of: rig) : PoseSampler.worldTransforms(rig: rig, pose: pose)
        if session.mode == .animate,
           let chain = PoseSampler.chainTip(near: point, rig: rig, world: world, tolerance: hitTolerance * 1.5) {
            session.selection = .bone(chain.lower)
            dragStartPose = pose
            return .poseReach(chain, bendPositive: PoseSampler.bendsPositive(chain: chain, rig: rig, pose: pose))
        }
        let stack = PoseSampler.bones(near: point, rig: rig, world: world, tolerance: hitTolerance)
        guard let top = stack.first else { return .pan }
        let bone = session.selectedBone.flatMap { stack.contains($0) ? $0 : nil } ?? top
        clickStack = (stack, bone)
        session.selection = .bone(bone)
        return session.mode == .setup
            ? restDrag(of: bone, at: point, rig: rig) : poseDrag(of: bone, at: point, pose: pose)
    }

    private func restDrag(of bone: Int, at point: Vec2, rig: SkeletonDefinition) -> Drag {
        if input.isPressed(.command) { return .restTranslate(bone, startRest: rig.bones[bone].rest, from: point) }
        if input.isPressed(.option) { return .restLength(bone) }
        return .restRotate(bone)
    }

    private func poseDrag(of bone: Int, at point: Vec2, pose: Pose) -> Drag {
        dragStartPose = pose
        return input.isPressed(.command) ? .poseTranslate(bone, from: point) : .poseRotate(bone)
    }

    // MARK: - Continue

    private func continueDrag(_ drag: Drag, to point: Vec2, rig: SkeletonDefinition) {
        switch drag {
        case .pan:
            pan(to: point)
        case .restRotate(let bone):
            let world = RigEditor.restWorld(of: rig)
            var rest = rig.bones[bone].rest
            rest.rotation = PoseSampler.rotationPointing(bone: bone, at: point, rig: rig, world: world)
            draftRig = try? RigEditor.settingRest(rig, bone, rest)
        case .restTranslate(let bone, let startRest, let from):
            var rest = startRest
            let world = RigEditor.restWorld(of: rig)
            rest.position = startRest.position + localDelta(point - from, parentOf: bone, rig: rig, world: world)
            draftRig = try? RigEditor.settingRest(rig, bone, rest)
        case .restLength(let bone):
            let world = RigEditor.restWorld(of: rig)
            let length = max(0.05, simd_length(point - PoseSampler.joint(of: bone, world: world)))
            draftRig = try? RigEditor.settingLength(rig, bone, length)
        case .poseRotate, .poseTranslate, .poseReach:
            if let start = dragStartPose { draftPose = posed(drag, to: point, from: start, rig: rig) }
        }
    }

    private func pan(to point: Vec2) {
        let session = editor.session
        guard let last = lastPointer else { return }
        session.cameraCentre -= point - last
        renderer.setCamera(point: Vec3(session.cameraCentre.x, session.cameraCentre.y, session.cameraDistance))
        // After the camera moved the pointer sits on a new world point: remember that one.
        lastPointer = input.pointerWorld(forZ: 0).map { Vec2($0.x, $0.y) }
    }

    /// The drag's pose: one bone turned or moved, or a chain reaching for the pointer.
    private func posed(_ drag: Drag, to point: Vec2, from start: Pose, rig: SkeletonDefinition) -> Pose {
        var draft = start
        let world = PoseSampler.worldTransforms(rig: rig, pose: start)
        switch drag {
        case .poseRotate(let bone):
            draft.local[bone].rotation = PoseSampler.rotationPointing(bone: bone, at: point, rig: rig, world: world)
        case .poseTranslate(let bone, let from):
            draft.local[bone].position = start.local[bone].position
                + localDelta(point - from, parentOf: bone, rig: rig, world: world)
        case .poseReach(let chain, let bendPositive):
            let bend = input.isPressed(.option) ? !bendPositive : bendPositive
            let solved = PoseSampler.rotationsReaching(point, chain: chain, rig: rig, pose: start, bendPositive: bend)
            draft.local[chain.upper].rotation = solved.upper
            draft.local[chain.lower].rotation = solved.lower
        default:
            break
        }
        return draft
    }

    /// A world delta expressed in the bone's parent's space.
    private func localDelta(
        _ delta: Vec2, parentOf bone: Int, rig: SkeletonDefinition, world: [RigidTransform2D]
    ) -> Vec2 {
        let parentRotation = rig.bones[bone].parent.map { world[$0].rotation } ?? 0
        return Vec2(delta.x * cos(-parentRotation) - delta.y * sin(-parentRotation),
                    delta.x * sin(-parentRotation) + delta.y * cos(-parentRotation))
    }

    // MARK: - End

    /// Commits the drag as one undo step: the rig in Setup mode; keys (or
    /// scratch edits, with auto-key off) in Animate mode.
    private func endDrag(rig: SkeletonDefinition) {
        defer {
            drag = nil
            draftRig = nil
            draftPose = nil
            dragStartPose = nil
            lastPointer = nil
        }
        guard let drag else { return }
        if let draft = draftRig, draft != editor.document.character.rig {
            commitRig(draft, for: drag)
        } else if let draft = draftPose, let start = dragStartPose, draft != start {
            commitPose(ClipEditor.PoseChange(from: start, to: draft), bones: bones(of: drag), rig: rig)
        } else {
            cycleSelection()
        }
    }

    private func commitRig(_ draft: SkeletonDefinition, for drag: Drag) {
        let name: String
        switch drag {
        case .restRotate: name = "Rotate Bone"
        case .restTranslate: name = "Move Bone"
        default: name = "Resize Bone"
        }
        editor.document.apply({ character in
            var character = character
            character.rig = draft
            return character
        }, named: name, undoManager: editor.session.undoManager)
    }

    private func bones(of drag: Drag) -> [Int] {
        switch drag {
        case .poseRotate(let bone), .poseTranslate(let bone, _): [bone]
        case .poseReach(let chain, _): [chain.upper, chain.lower]
        default: []
        }
    }

    /// Auto-key on: keys the changed channels at the playhead. Off: keeps
    /// the edit as scratch and marks the bones pending.
    private func commitPose(_ change: ClipEditor.PoseChange, bones: [Int], rig: SkeletonDefinition) {
        let session = editor.session
        guard let clip = session.clip(in: editor.document.character) else { return }
        if session.autoKey {
            var keyed = clip
            for bone in bones {
                keyed = ClipEditor.keying(keyed, bone: bone, change: change, rig: rig, at: session.playhead)
            }
            replaceClip(keyed, named: "Key Bone")
            clearScratch()
        } else {
            var scratch = scratchPose ?? change.to
            for bone in bones { scratch.local[bone] = change.to.local[bone] }
            scratchPose = scratch
            scratchBones.formUnion(bones)
            session.pendingBones = Set(scratchBones.map { rig.bones[$0].name })
        }
    }

    /// A click that moved nothing on a stack of bones selects the next one down.
    private func cycleSelection() {
        guard let (stack, chosen) = clickStack, stack.count > 1,
              let position = stack.firstIndex(of: chosen) else { return }
        editor.session.selection = .bone(stack[(position + 1) % stack.count])
    }
}
