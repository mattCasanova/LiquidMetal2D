//
//  Behavoir.swift
//  
//
//  Created by Matt Casanova on 3/20/20.
//


open class Behavoir {
  private unowned var current: State
  
  public init(startState: State = NilState()) {
    current = startState
    current.enter()
  }
    
  public func setNext(next: State) {
    current.exit()
    current = next
    current.enter()
  }
  
  public func update(dt: Float) {
    current.update(dt: dt)
  }
  
}


