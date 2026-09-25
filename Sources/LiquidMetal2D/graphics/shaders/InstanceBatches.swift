//
//  InstanceBatches.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 9/25/26.
//

/// One frame's instances for a textured shader: how many were written, and
/// the runs of consecutive instances that share a texture. Each run becomes
/// one instanced draw call.
///
/// A value type on purpose. Every access to a stored `var` of a class pays
/// an exclusivity check at run time, so a shader's `submit` swaps this into
/// a local for its per-instance loop instead of updating its own properties
/// once or twice per instance.
struct InstanceBatches {
    struct Batch: Equatable {
        let textureId: Int
        let startIndex: Int
        var count: Int
    }

    private(set) var batches: [Batch] = []
    /// Instances written this frame, which is also the slot the next one takes.
    private(set) var count = 0

    /// Starts a new frame: no instances, no runs. Keeps the array's capacity.
    mutating func reset() {
        batches.removeAll(keepingCapacity: true)
        count = 0
    }

    /// Drops the runs once they're drawn. ``count`` carries on, so instances
    /// submitted later in the frame take the slots after the drawn ones.
    mutating func removeDrawnBatches() {
        batches.removeAll(keepingCapacity: true)
    }

    /// Records the instance just written to slot ``count``: extends the last
    /// run if it uses the same texture, otherwise starts a new run.
    mutating func append(textureId: Int) {
        if let last = batches.last, last.textureId == textureId {
            batches[batches.count - 1].count += 1
        } else {
            batches.append(Batch(textureId: textureId, startIndex: count, count: 1))
        }
        count += 1
    }
}
