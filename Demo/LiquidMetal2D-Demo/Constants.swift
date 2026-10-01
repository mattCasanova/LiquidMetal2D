//
//  Constants.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 3/8/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Foundation

/// Game-wide constants shared across scenes.
///
/// `MAX_OBJECTS` determines the renderer's triple-buffered uniform ring buffer size
/// (set in ViewController when creating `DefaultRenderer`). It defines the maximum number
/// of textured quads that can be drawn in a single frame. Several demo scenes use this
/// value directly to allocate their object arrays.
///
/// **Why this matters for the renderer:**
/// The Metal renderer pre-allocates a GPU buffer large enough to hold `MAX_OBJECTS` worth
/// of `AlphaBlendUniform` data (transform matrices). If you try to draw more objects than this
/// in a single frame, the renderer will not have enough buffer space. Set this value to
/// the maximum number of objects any scene in your game needs to draw simultaneously.
class GameConstants {
  public static let MAX_OBJECTS = 10000
}
