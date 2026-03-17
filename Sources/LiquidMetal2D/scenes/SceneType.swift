//
//  SceneType.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/26/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

/// Marker protocol for scene identifiers. Conform your scene enum to this:
///
/// ```swift
/// enum MyScenes: SceneType {
///     case menu
///     case gameplay
///     case gameOver
/// }
/// ```
///
/// Requires `Hashable` so scene types can be used as dictionary keys
/// in ``SceneFactory``.
public protocol SceneType: Hashable {}
