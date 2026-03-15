//
//  ScheduledTask.swift
//
//
//  Created by Matt Casanova on 3/17/20.
//

import Foundation

public typealias TaskMethod = () -> Void

public class ScheduledTask {
    static public let INFINITE = -1

    public let maxTime: Float
    public let action: TaskMethod
    public let onComplete: TaskMethod?

    public var currentTime: Float = 0
    public var repeatCount: Int

    public init(
        time: Float, action: @escaping TaskMethod,
        count: Int = ScheduledTask.INFINITE, onComplete: TaskMethod? = nil
    ) {
        self.maxTime = time
        self.action = action
        self.repeatCount = count
        self.onComplete = onComplete
    }
}
