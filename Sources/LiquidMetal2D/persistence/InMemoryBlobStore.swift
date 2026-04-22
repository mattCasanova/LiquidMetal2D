//
//  InMemoryBlobStore.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/20/26.
//

import Foundation

/// Dictionary-backed ``BlobStore`` for tests. Zero I/O, zero cleanup,
/// nothing to mock. Pass into ``CodableBlobStore`` in place of
/// ``FileBlobStore`` to unit-test save/load logic without touching disk.
public final class InMemoryBlobStore: BlobStore {

    /// Thrown by ``get(key:)`` and ``delete(key:)`` when the key isn't
    /// present. Mirrors the "file not found" failure ``FileBlobStore``
    /// surfaces from `Data(contentsOf:)` / `removeItem(at:)`.
    public struct KeyNotFoundError: Error, Equatable {
        public let key: String
    }

    private var storage: [String: Data] = [:]

    public init() {}

    public func put(_ data: Data, key: String) throws {
        storage[key] = data
    }

    public func get(key: String) throws -> Data {
        guard let data = storage[key] else {
            throw KeyNotFoundError(key: key)
        }
        return data
    }

    public func list() throws -> [String] {
        Array(storage.keys)
    }

    public func delete(key: String) throws {
        guard storage.removeValue(forKey: key) != nil else {
            throw KeyNotFoundError(key: key)
        }
    }
}
