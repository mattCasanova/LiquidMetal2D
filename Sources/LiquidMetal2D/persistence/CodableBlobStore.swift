//
//  CodableBlobStore.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/20/26.
//

import Foundation

/// Typed wrapper around any ``BlobStore`` for any `Codable` type. Handles
/// JSON encode/decode so callers work with domain types — `Player`,
/// `ParticleConfig`, `Settings` — instead of raw `Data`.
///
/// ```swift
/// let store = try CodableBlobStore<Player>(
///     store: FileBlobStore(subdirectory: "players"))
/// try store.put(player, key: "slot1")
/// let loaded: Player = try store.get(key: "slot1")
/// ```
///
/// Construct the underlying ``BlobStore`` yourself so tests can pass in
/// ``InMemoryBlobStore`` without touching the filesystem.
public final class CodableBlobStore<T: Codable> {
    private let store: BlobStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        store: BlobStore,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.store = store
        self.encoder = encoder
        self.decoder = decoder
    }

    public func put(_ value: T, key: String) throws {
        try store.put(encoder.encode(value), key: key)
    }

    public func get(key: String) throws -> T {
        try decoder.decode(T.self, from: store.get(key: key))
    }

    public func list() throws -> [String] {
        try store.list()
    }

    public func delete(key: String) throws {
        try store.delete(key: key)
    }
}
