//
//  Shader.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/19/26.
//

import Metal

/// A shader encapsulates a pipeline state, per-instance uniform layout, and
/// batching strategy. Each shader owns its own ``BufferProvider`` sized for
/// its uniform stride, so different shaders can coexist in one pass without
/// sharing buffer layouts.
///
/// Shaders drive rendering via matching ``Component`` types on ``GameObj``.
/// A shader's ``submit(objects:)`` walks the list, looks up its component,
/// and skips objects that don't have one. A single GameObj can carry multiple
/// render components and be rendered by multiple shaders in the same pass.
@MainActor
public protocol Shader: AnyObject {
    /// Upper bound on instances per frame. Sizes the per-shader GPU buffer.
    var maxObjects: Int { get }

    /// Acquire a frame's GPU buffer from the shader's ``BufferProvider`` and
    /// reset per-frame batching state. Returns false if the triple-buffer
    /// semaphore timed out; callers should bail on the frame.
    func beginFrame() -> Bool

    /// Bind pipeline state and per-shader resources onto the pass's encoder.
    /// Called when the shader becomes the active shader on a pass.
    func bind(pass: RenderPass, projectionBuffer: MTLBuffer)

    /// Walk the object list, filter by this shader's matching component,
    /// build uniforms, and accumulate batches. Each shader implements its
    /// own sort/batching strategy internally.
    func submit(objects: [GameObj])

    /// Emit queued draw commands to the encoder and reset batching state.
    /// Called on shader switch and at end of pass. Idempotent.
    func flush(pass: RenderPass)

    /// Signal the shader's buffer semaphore. Attached to the command buffer's
    /// completion handler; runs on an arbitrary thread.
    nonisolated func signalFrameComplete()
}
