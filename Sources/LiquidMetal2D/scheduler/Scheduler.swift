//
//  Scheduler.swift
//
//
//  Created by Matt Casanova on 3/17/20.
//

/// Manages timed tasks. Call ``update(dt:)`` each frame to advance all tasks.
///
/// Tasks fire their action at a fixed interval, optionally repeating.
/// Completed tasks are removed after the update loop (no mutation during
/// iteration). Chained tasks (via ``ScheduledTask/then``) are automatically
/// added when their predecessor completes.
public class Scheduler {

    private var tasks = [ScheduledTask]()

    /// When true, all tasks are skipped regardless of their individual isPaused state.
    public var isPaused: Bool = false

    public init() {}

    /// Adds a task to the scheduler. Tasks with repeatCount == 0 are ignored.
    public func add(task: ScheduledTask) {
        if task.repeatCount != 0 {
            tasks.append(task)
        }
    }

    /// Removes a specific task from the scheduler.
    public func remove(toRemove: ScheduledTask) {
        tasks.removeAll(where: { $0 === toRemove })
    }

    /// Removes all tasks.
    public func clear() {
        tasks.removeAll()
    }

    /// Advances all tasks by dt seconds. Fires actions for tasks that have
    /// reached their interval. Completed tasks are collected and removed
    /// after the loop to avoid mutation during iteration.
    public func update(dt: Float) {
        if isPaused { return }

        var completed = [ScheduledTask]()

        for task in tasks {
            // Skip individually paused tasks
            if task.isPaused { continue }

            task.currentTime += dt

            // Fire as many times as needed if dt >> maxTime (prevents drift)
            while task.currentTime >= task.maxTime {
                // Subtract instead of resetting to 0 to preserve overshoot
                task.currentTime -= task.maxTime
                task.action()

                if task.repeatCount == ScheduledTask.INFINITE {
                    continue
                }

                task.repeatCount -= 1

                if task.repeatCount == 0 {
                    completed.append(task)
                    break
                }
            }
        }

        // Remove completed tasks and start any chained follow-ups
        for task in completed {
            task.onComplete?()
            tasks.removeAll(where: { $0 === task })

            if let next = task.nextTask {
                add(task: next)
            }
        }
    }
}
