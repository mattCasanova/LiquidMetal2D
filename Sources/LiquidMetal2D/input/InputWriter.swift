//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

import simd
@MainActor
public protocol InputWriter {
  func setTouch(location: simd_float2?)
}
