//
//  State.swift
//  
//
//  Created by Matt Casanova on 3/20/20.
//

import Foundation

public protocol State: class {
  func enter()
  func update(dt: Float)
  func exit()
}

public class NilState: State {
  
  public init() {}
  
  public func enter() {}
  public func exit() {}
  public func update(dt: Float) {}
}
