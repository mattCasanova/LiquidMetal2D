//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/17/20.
//

import Foundation

public typealias TaskMethod = @escaping () -> Void

public class Task {
  public let INFINITE = -1
  
  public let maxTime: Float
  public let taskMethod: TaskMethod
  
  public var currentTime: Float = 0
  public var repeatCount: Int
  

  
  public init(time: Float, task: TaskMethod, count: Int = Task.INFINITE) {
    self.maxTime = time
    self.TaskMethod = task
  }
  
}
