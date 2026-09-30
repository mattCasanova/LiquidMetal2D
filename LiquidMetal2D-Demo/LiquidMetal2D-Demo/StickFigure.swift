//
//  StickFigure.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 9/21/26.
//

import Foundation
import LiquidMetal2D

/// A white-box stick figure rig and its clips.
///
/// The demo loads them from files, as a game would: `Animations/stickfigure.rig.json`
/// and one `Animations/<name>.clip.json` per clip. The builders below made those files
/// (with `AnimationFiles.data(for:)`) and stay as their reference: a Debug build
/// checks the two still match, so change them together.
///
/// Facing +x. Units are world units at `SkeletonComponent.scale == 1`:
/// 8.4 tall, feet 4 below the hips. Far-side limbs are tinted darker
/// than near-side ones so the depth reads.
enum StickFigure {

    /// The bone the sword hangs off, and the sword's attachment name, for throwing it.
    static let swordHandBone = 10
    static let swordAttachment = "sword"
    /// Where the sword's centre sits along the forearm, before scale.
    static let swordOffset = Vec2(1.5 + 1.1, 0)
    static let swordSize = Vec2(2.6, 0.18)

    /// Bones in rig order. Rest rotations are local: the spine points up
    /// (+90°), arms hang down along the body (180° from the spine), legs point down (-90°).
    private static let bones: [(name: String, parent: Int?, length: Float, at: Vec2, degrees: Float)] = [
        ("hips", nil, 0, Vec2(0, 0), 0),
        ("spine", 0, 3.0, Vec2(0, 0), 90),
        ("head", 1, 1.4, Vec2(3.0, 0), 0),
        ("upperArmFar", 1, 1.6, Vec2(2.7, 0), 180),
        ("lowerArmFar", 3, 1.5, Vec2(1.6, 0), 0),
        ("thighFar", 0, 2.0, Vec2(0, 0), -90),
        ("shinFar", 5, 2.0, Vec2(2.0, 0), 0),
        ("thighNear", 0, 2.0, Vec2(0, 0), -90),
        ("shinNear", 7, 2.0, Vec2(2.0, 0), 0),
        ("upperArmNear", 1, 1.6, Vec2(2.7, 0), 180),
        ("lowerArmNear", 9, 1.5, Vec2(1.6, 0), 0),
    ]

    static func makeDefinition() -> SkeletonDefinition {
        let rigBones = bones.map {
            Bone(name: $0.name, parent: $0.parent, length: $0.length,
                 rest: RigidTransform2D(position: $0.at, rotation: $0.degrees * degree))
        }

        func box(_ bone: Int, thickness: Float = 0.5, tint: Vec4, order: Int) -> Attachment {
            let length = bones[bone].length
            return Attachment(
                name: bones[bone].name, bone: bone, size: Vec2(length, thickness),
                offset: Vec2(length / 2, 0), tint: tint, drawOrder: order)
        }

        let far = TokyoNight.comment
        let near = TokyoNight.fg
        let sword = Attachment(
            name: swordAttachment, bone: swordHandBone, size: swordSize, offset: swordOffset,
            tint: TokyoNight.cyan, drawOrder: 11)

        return SkeletonDefinition(
            bones: rigBones,
            attachments: [
                box(3, tint: far, order: 0), box(4, tint: far, order: 1),
                box(5, tint: far, order: 2), box(6, tint: far, order: 3),
                box(1, tint: near, order: 5),
                box(2, thickness: 1.4, tint: near, order: 6),
                box(7, tint: near, order: 7), box(8, tint: near, order: 8),
                box(9, tint: near, order: 9), box(10, tint: near, order: 10),
                sword,
            ])
    }

    // MARK: - Clips

    struct Clips {
        let idle: ResolvedClip
        let walk: ResolvedClip
        let jump: ResolvedClip
        /// Keys only the near arm, so it plays on an override layer over walk or idle.
        let slash: ResolvedClip
        /// Near arm only, like `slash`. Fires "throw" at the moment the sword leaves the hand.
        let throwSword: ResolvedClip
    }

    // MARK: - Files

    enum LoadError: Error {
        case missingFile(String)
    }

    /// Reads the rig and clips from the app bundle and resolves the clips against the rig.
    /// - Throws: ``LoadError/missingFile(_:)`` for a file not in the bundle; the engine's
    ///   decoding and ``SkeletonError`` errors for a bad one.
    static func load(from bundle: Bundle = .main) throws -> (rig: SkeletonDefinition, clips: Clips) {
        func url(_ name: String) throws -> URL {
            guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Animations") else {
                throw LoadError.missingFile("Animations/\(name).json")
            }
            return url
        }

        let rig = try AnimationFiles.loadRig(at: url("stickfigure.rig"))
        let files = try ["idle", "walk", "jump", "slash", "throw"].map {
            try AnimationFiles.loadClip(at: url("\($0).clip"))
        }
        assert(rig == makeDefinition(), "Animations/stickfigure.rig.json no longer matches makeDefinition()")
        assert(files == [idle(), walk(), jump(), slash(), throwSword()],
               "An Animations/*.clip.json file no longer matches its builder")

        return (rig, Clips(
            idle: try files[0].resolved(for: rig),
            walk: try files[1].resolved(for: rig),
            jump: try files[2].resolved(for: rig),
            slash: try files[3].resolved(for: rig),
            throwSword: try files[4].resolved(for: rig)))
    }

    private static let degree = Float.pi / 180

    /// Rotation keys for `bone`, given as degrees *added to* the bone's rest rotation.
    private static func turn(
        _ bone: String, _ keys: [(time: Float, degrees: Float)], easing: EasingType = .easeInOutSine
    ) -> BoneTrack {
        guard let rest = bones.first(where: { $0.name == bone })?.degrees else {
            preconditionFailure("StickFigure has no bone named \(bone)")
        }
        return BoneTrack(bone: bone, rotation: keys.map {
            Keyframe(time: $0.time, value: (rest + $0.degrees) * degree, easing: easing)
        })
    }

    /// Hip height keys, which move the whole figure up and down.
    private static func bob(_ keys: [(time: Float, y: Float)], easing: EasingType = .easeInOutSine) -> BoneTrack {
        BoneTrack(bone: "hips", position: keys.map { Keyframe(time: $0.time, value: Vec2(0, $0.y), easing: easing) })
    }

    private static func idle() -> AnimationClip {
        AnimationClip(name: "idle", duration: 2, loops: true, tracks: [
            turn("spine", [(0, 0), (1, 2), (2, 0)]),
            turn("upperArmNear", [(0, 0), (1, 3), (2, 0)]),
            turn("upperArmFar", [(0, 0), (1, 3), (2, 0)]),
            turn("lowerArmNear", [(0, 10)]),
            turn("lowerArmFar", [(0, 10)]),
            bob([(0, 0), (1, -0.08), (2, 0)]),
        ])
    }

    /// Near and far limbs run half a cycle apart; arms swing against the legs.
    private static func walk() -> AnimationClip {
        AnimationClip(name: "walk", duration: 1, loops: true, tracks: [
            turn("thighNear", [(0, 30), (0.5, -30), (1, 30)]),
            turn("thighFar", [(0, -30), (0.5, 30), (1, -30)]),
            turn("shinNear", [(0, -5), (0.25, -10), (0.5, -5), (0.75, -55), (1, -5)]),
            turn("shinFar", [(0, -5), (0.25, -55), (0.5, -5), (0.75, -10), (1, -5)]),
            turn("upperArmNear", [(0, -25), (0.5, 25), (1, -25)]),
            turn("upperArmFar", [(0, 25), (0.5, -25), (1, 25)]),
            turn("lowerArmNear", [(0, 20)]),
            turn("lowerArmFar", [(0, 20)]),
            turn("spine", [(0, -5)]),
            bob([(0, 0), (0.25, -0.25), (0.5, 0), (0.75, -0.25), (1, 0)]),
        ], events: [
            // Each thigh is furthest forward as its foot lands.
            AnimationEvent(time: 0, name: "step"),
            AnimationEvent(time: 0.5, name: "step"),
        ])
    }

    /// Crouch, launch, tuck at the top, reach for the ground, absorb, stand.
    private static func jump() -> AnimationClip {
        let times: [Float] = [0, 0.15, 0.30, 0.50, 0.75, 0.85, 0.90]
        func keys(_ values: [Float]) -> [(time: Float, degrees: Float)] {
            zip(times, values).map { (time: $0, degrees: $1) }
        }

        let thighs = keys([0, 50, -10, 70, 10, 30, 0])
        let shins = keys([0, -90, -5, -100, -10, -55, 0])
        let arms = keys([0, -40, 160, 100, 60, 20, 0])

        return AnimationClip(name: "jump", duration: 0.9, loops: false, tracks: [
            turn("thighNear", thighs), turn("thighFar", thighs),
            turn("shinNear", shins), turn("shinFar", shins),
            turn("upperArmNear", arms), turn("upperArmFar", arms),
            turn("lowerArmNear", keys([20, 30, 10, 60, 30, 20, 20])),
            turn("lowerArmFar", keys([20, 30, 10, 60, 30, 20, 20])),
            turn("spine", keys([0, -15, 5, -20, -5, -10, 0])),
            BoneTrack(bone: "hips", position: zip(times, [0, -1.0, 1.5, 3.0, 0.5, -0.5, 0]).map {
                Keyframe(time: $0, value: Vec2(0, $1), easing: .easeInOutSine)
            }),
        ], events: [
            AnimationEvent(time: 0.30, name: "jump"),
            AnimationEvent(time: 0.80, name: "land"),
        ])
    }

    /// Raise the sword forward and up, cut down and back, settle. Near arm only.
    private static func slash() -> AnimationClip {
        AnimationClip(name: "slash", duration: 0.4, loops: false, tracks: [
            turn("upperArmNear", [(0, 0), (0.12, 150), (0.24, -30), (0.4, -10)], easing: .easeOutCubic),
            turn("lowerArmNear", [(0, 20), (0.12, 10), (0.24, 5), (0.4, 20)], easing: .easeOutCubic),
        ], events: [
            AnimationEvent(time: 0.12, name: "swing"),
        ])
    }

    /// Wind the arm back, whip it forward, let go at the top of the swing. Near arm only.
    private static func throwSword() -> AnimationClip {
        AnimationClip(name: "throw", duration: 0.45, loops: false, tracks: [
            turn("upperArmNear", [(0, 0), (0.12, -70), (0.2, 70), (0.32, 30), (0.45, 0)], easing: .easeOutCubic),
            turn("lowerArmNear", [(0, 20), (0.12, 40), (0.2, 5), (0.32, 20), (0.45, 20)], easing: .easeOutCubic),
        ], events: [
            AnimationEvent(time: 0.18, name: "throw"),
        ])
    }
}
