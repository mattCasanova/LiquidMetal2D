//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/17/20.
//

import Foundation

public class Schedular {
  
  private var tasks = [Task]()
  
  public init() {}
  
  public func add(task: Task) {
    tasks.append(task)
  }
  
  public func remove(toRemove: Task) {
    tasks.removeAll(where: { $0.repeatCount == toRemove.repeatCount})
  }
  
  public func update(dt: Float) {
    for task in tasks {
      task.currentTime += dt
    }
  }
  
}
