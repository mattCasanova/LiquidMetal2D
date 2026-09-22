//
//  Animator.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/21/26.
//

/// Plays clips on a stack of layers and blends them into one ``pose``.
///
/// **Layer 0** is the base: it starts from the rest pose, so bones its clip
/// has no keys for sit at rest. **Higher layers override**: each one changes
/// only the bones its clip has keys for and leaves the rest as the layers
/// below set them. Run on layer 0 with a slash on layer 1 that keys only the
/// arms gives running legs and slashing arms, with no run-slash clip.
///
/// Two kinds of blend:
/// - **Crossfade** — `play` on a layer that is already playing blends from the
///   old clip to the new one over `crossfade` seconds. Both keep advancing.
/// - **Layer weight** — a layer fades in from nothing when it starts, and out
///   again on ``stop(layer:fadeOut:)``.
///
/// The pose is recomputed in ``update(dt:)``. In steady play nothing allocates there.
public final class Animator {

    public private(set) var pose: Pose
    /// Multiplies `dt` for clip time and for fades.
    public var speed: Float = 1
    /// Fires once when a one-shot clip reaches its end, with the layer and
    /// clip name. Called from ``update(dt:)`` before the pose is computed, so
    /// playing the next clip from here shows up the same frame.
    public var onClipFinished: ((_ layer: Int, _ clipName: String) -> Void)?

    private let definition: SkeletonDefinition
    private var layers: [Layer]

    // Scratch poses, sized once.
    private var lowerPose: Pose
    private var currentPose: Pose
    private var previousPose: Pose
    private var blendedPose: Pose

    public init(definition: SkeletonDefinition, layerCount: Int = 2) {
        precondition(layerCount > 0, "An animator needs at least one layer")
        self.definition = definition
        self.layers = Array(repeating: Layer(), count: layerCount)
        let rest = Pose(restOf: definition)
        pose = rest
        lowerPose = rest
        currentPose = rest
        previousPose = rest
        blendedPose = rest
    }

    public var layerCount: Int { layers.count }

    // MARK: - Control

    /// Starts `clip` on `layer`.
    ///
    /// - Parameters:
    ///   - crossfade: Seconds to blend in. From the layer's old clip if it has
    ///     one; from whatever is below if the layer was empty.
    ///   - restart: When `false` and `clip` is already playing on this layer,
    ///     does nothing, so a scene can call `play(walk, restart: false)` every frame.
    ///   - fadeOutWhenFinished: For one-shot clips on override layers: once the
    ///     clip ends, fade the layer out over this many seconds.
    public func play(
        _ clip: ResolvedClip,
        layer index: Int = 0,
        crossfade: Float = 0,
        restart: Bool = true,
        fadeOutWhenFinished: Float? = nil
    ) {
        checkLayer(index)
        precondition(clip.boneCount == definition.bones.count,
                     "Clip \(clip.name) was resolved for a different rig")

        if !restart, let playing = layers[index].current, playing.clip.name == clip.name {
            if layers[index].isStopping {
                layers[index].isStopping = false
                layers[index].weight = Fade(from: layers[index].weight.value, to: 1, duration: crossfade)
            }
            return
        }

        let isAudible = layers[index].current != nil && layers[index].weight.value > 0
        if isAudible && crossfade > 0 {
            layers[index].previous = layers[index].current
            layers[index].clipBlend = Fade(from: 0, to: 1, duration: crossfade)
        } else {
            layers[index].previous = nil
            layers[index].clipBlend = .settled(at: 1)
        }

        layers[index].current = Playback(clip: clip, fadeOutWhenFinished: fadeOutWhenFinished)
        if layers[index].isStopping || layers[index].weight.target < 1 {
            layers[index].weight = Fade(from: layers[index].weight.value, to: 1, duration: crossfade)
        }
        layers[index].isStopping = false
    }

    /// Fades `layer` out over `fadeOut` seconds, then empties it.
    public func stop(layer index: Int, fadeOut: Float = 0) {
        checkLayer(index)
        guard layers[index].current != nil else { return }

        if fadeOut > 0 {
            layers[index].isStopping = true
            layers[index].weight = Fade(from: layers[index].weight.value, to: 0, duration: fadeOut)
        } else {
            layers[index] = Layer()
        }
    }

    /// Advances every layer by `dt * speed`, fires finished callbacks, and recomputes ``pose``.
    public func update(dt: Float) {
        let step = dt * speed
        var finished: [(layer: Int, clip: String)] = []

        for index in layers.indices {
            layers[index].advance(by: step)
            if let playback = layers[index].takeNewlyFinishedClip() {
                finished.append((index, playback.clip.name))
                if let fadeOut = playback.fadeOutWhenFinished {
                    stop(layer: index, fadeOut: fadeOut)
                }
            }
        }

        for event in finished {
            onClipFinished?(event.layer, event.clip)
        }

        computePose()
    }

    // MARK: - Queries

    public func currentClipName(layer index: Int = 0) -> String? {
        checkLayer(index)
        return layers[index].current?.clip.name
    }

    /// True once a one-shot clip on `layer` has reached its end. Looping clips never finish.
    public func isFinished(layer index: Int = 0) -> Bool {
        checkLayer(index)
        guard let playing = layers[index].current else { return false }
        return !playing.clip.loops && playing.time >= playing.clip.duration
    }

    /// How much `layer` counts right now, 0–1.
    public func weight(layer index: Int) -> Float {
        checkLayer(index)
        return layers[index].current == nil ? 0 : layers[index].weight.value
    }

    // MARK: - Blending

    private func computePose() {
        pose.reset(to: definition)

        for layer in layers {
            guard let playing = layer.current else { continue }
            let weight = layer.weight.value
            guard weight > 0 else { continue }

            lowerPose.copyValues(from: pose)
            currentPose.copyValues(from: lowerPose)
            playing.clip.apply(at: playing.time, onto: &currentPose)

            if let fading = layer.previous {
                previousPose.copyValues(from: lowerPose)
                fading.clip.apply(at: fading.time, onto: &previousPose)
                blendedPose.setBlend(from: previousPose, to: currentPose, t: layer.clipBlend.value)
            } else {
                blendedPose.copyValues(from: currentPose)
            }

            pose.setBlend(from: lowerPose, to: blendedPose, t: weight)
        }
    }

    private func checkLayer(_ index: Int) {
        precondition(layers.indices.contains(index),
                     "Animator has \(layers.count) layers; there is no layer \(index)")
    }
}

// MARK: - Layer state

private struct Playback {
    let clip: ResolvedClip
    var time: Float = 0
    var hasReportedFinish = false
    let fadeOutWhenFinished: Float?

    init(clip: ResolvedClip, fadeOutWhenFinished: Float?) {
        self.clip = clip
        self.fadeOutWhenFinished = fadeOutWhenFinished
    }
}

/// A value moving from `from` to `target` over `duration` seconds.
private struct Fade {
    let from: Float
    let target: Float
    let duration: Float
    var elapsed: Float = 0

    init(from: Float, to target: Float, duration: Float) {
        self.from = from
        self.target = target
        self.duration = duration
    }

    static func settled(at value: Float) -> Fade {
        Fade(from: value, to: value, duration: 0)
    }

    var isDone: Bool { duration <= 0 || elapsed >= duration }

    var value: Float {
        isDone ? target : GameMath.lerp(a: from, b: target, t: elapsed / duration)
    }
}

private struct Layer {
    var current: Playback?
    /// The clip being crossfaded away from; `nil` once the crossfade ends.
    var previous: Playback?
    var clipBlend = Fade.settled(at: 1)
    var weight = Fade.settled(at: 0)
    var isStopping = false

    mutating func advance(by step: Float) {
        current?.time += step
        previous?.time += step
        clipBlend.elapsed += step
        weight.elapsed += step

        if clipBlend.isDone {
            previous = nil
        }
        if isStopping && weight.isDone {
            self = Layer()
        }
    }

    /// The current clip, once, the first time it is seen past its end.
    mutating func takeNewlyFinishedClip() -> Playback? {
        guard let playing = current, !playing.clip.loops,
              playing.time >= playing.clip.duration, !playing.hasReportedFinish else {
            return nil
        }
        current?.hasReportedFinish = true
        return playing
    }
}
