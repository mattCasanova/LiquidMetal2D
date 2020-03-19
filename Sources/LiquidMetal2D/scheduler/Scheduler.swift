//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/17/20.
//

import Foundation

public class Scheduler {
  
  private var tasks = [Task]()
  
  public init() {}
  
  public func add(task: Task) {
    if task.repeatCount != 0 {
      tasks.append(task)
    }
  }
  
  public func remove(toRemove: Task) {
    tasks.removeAll(where: { $0 === toRemove })
  }
  
  public func clear() {
    tasks.removeAll()
  }
  
  public func update(dt: Float) {
    for task in tasks {
      task.currentTime += dt
  
      if task.currentTime < task.maxTime {
        continue
      }
        
      task.currentTime = 0
      task.action()
        
      if task.repeatCount == Task.INFINITE {
        continue
      }
      
      task.repeatCount -= 1
        
      if task.repeatCount == 0 {
        task.onComplete?()
        remove(toRemove: task)
      }
      
    }
  }
  
}
