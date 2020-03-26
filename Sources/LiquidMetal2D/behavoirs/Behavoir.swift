//
//  Behavoir.swift
//  
//
//  Created by Matt Casanova on 3/20/20.
//

public protocol Behavoir: class {
  var current: State! { get set }

  func setStartState(startState: State)
  func setNext(next: State)
  func update(dt: Float)
}


public extension Behavoir {
  func setStartState(startState: State = NilState()) {
    current = startState
    current.enter()
  }
    
  func setNext(next: State) {
    current.exit()
    current = next
    current.enter()
  }
  
  func update(dt: Float) {
    current.update(dt: dt)
  }
}


public class NilBehavoir: Behavoir {
  public var current: State!

  public init() {
    setStartState()
  }

}


