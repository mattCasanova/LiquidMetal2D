//
//  Task.swift
//
//
//  Created by Matt Casanova on 3/17/20.
//

public typealias TaskMethod = () -> Void

/// A scheduled task that fires an action at a timed interval.
///
/// Tasks can repeat a fixed number of times, run infinitely, be paused/resumed,
/// and chain to a follow-up task on completion.
///
/// ```swift
/// let flash = ScheduledTask(time: 0.1, action: { obj.flash() }, count: 3)
///     .then(time: 0.5, action: { obj.fadeOut() })
/// scheduler.add(task: flash)
///
/// flash.pause()
/// flash.resume()
/// ```
public class ScheduledTask {
    public static let INFINITE = -1

    /// Time interval between firings in seconds.
    public let maxTime: Float

    /// Called each time the task fires.
    public let action: TaskMethod

    /// Called once when the task completes all repeats (not called for INFINITE tasks).
    public let onComplete: TaskMethod?

    /// Accumulated time since last firing.
    public var currentTime: Float = 0

    /// Remaining repeat count. Decremented each firing. 0 = done, INFINITE = never stops.
    public var repeatCount: Int

    /// When true, the task skips updates but retains its position in the scheduler.
    public var isPaused: Bool = false

    /// Optional follow-up task added to the scheduler when this task completes.
    public var nextTask: ScheduledTask?

    public init(
        time: Float, action: @escaping TaskMethod,
        count: Int = ScheduledTask.INFINITE, onComplete: TaskMethod? = nil
    ) {
        self.maxTime = time
        self.action = action
        self.repeatCount = count
        self.onComplete = onComplete
    }

    /// Pause this task. It stays in the scheduler but stops accumulating time.
    public func pause() { isPaused = true }

    /// Resume a paused task.
    public func resume() { isPaused = false }

    /// Chain a follow-up task that starts when this one completes.
    /// Returns the new task so you can chain further.
    @discardableResult
    public func then(time: Float, action: @escaping TaskMethod,
                     count: Int = 1, onComplete: TaskMethod? = nil) -> ScheduledTask {
        let chained = ScheduledTask(time: time, action: action, count: count, onComplete: onComplete)
        self.nextTask = chained
        return chained
    }
}
