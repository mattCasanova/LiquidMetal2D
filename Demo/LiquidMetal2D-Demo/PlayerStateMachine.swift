//
//  PlayerStateMachine.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 3/20/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import LiquidMetal2D

/// An input-driven single-state Behavior that reads touch input to rotate a ship.
///
/// **Input-driven Behavior pattern:**
/// Unlike `RandomAngleBehavior` and `MoveRightBehavior` which are autonomous (no player input),
/// this Behavior passes an `InputReader` reference to its State so the state can query touch
/// input each frame.
///
/// **InputReader in the Behavior/State pattern:**
/// The engine's `InputReader` protocol provides methods like `getWorldTouch(forZ:)` for reading
/// touch state. To use it in a State, pass the `InputReader` reference from the scene's
/// `initialize(services:)` method through the Behavior to the State.
///
/// **Note:** This Behavior is not currently used by any demo scene, but demonstrates the pattern
/// for creating player-controlled objects with the Behavior/State system.
class PlayerStateMachine: Behavior {
  /// Required by the Behavior protocol. Holds the currently active State.
  var current: State!

  unowned let parent: GameObj

  private let playerState: PlayerState

  /// - Parameters:
  ///   - parent: The game object this behavior controls
  ///   - inputReader: The engine's input reader for querying touch state each frame
  init(parent: GameObj, inputReader: InputReader) {
    self.parent = parent
    self.playerState = PlayerState(obj: self.parent, inputReader: inputReader)
    // Activate the single player state
    setStartState(startState: playerState)
  }

}
