//
//  SceneBuilder.swift
//
//
//  Created by Matt Casanova on 3/6/20.
//

/// Builds a ``Scene`` instance. Registered with ``SceneFactory`` and
/// called by ``SceneManager`` during scene transitions.
///
/// For most cases, use ``TSceneBuilder`` which provides a generic
/// implementation that calls the scene's static `build()` method.
@MainActor
public protocol SceneBuilder {
    /// Creates and returns a new scene instance.
    func build() -> Scene
}
