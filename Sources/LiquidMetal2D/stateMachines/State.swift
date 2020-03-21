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
