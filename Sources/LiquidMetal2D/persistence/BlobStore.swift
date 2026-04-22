//
//  BlobStore.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/20/26.
//

import Foundation

/// A key-value byte store for app-controlled persistence. Conformers decide
/// *how* `Data` is stored (filesystem, memory, HTTP, iCloud, etc.); the
/// protocol exposes only the four CRUD operations. Keys are opaque
/// strings — the caller picks the naming convention.
///
/// For typed access, wrap a `BlobStore` in ``CodableBlobStore`` instead
/// of re-implementing the JSON dance. Swap ``FileBlobStore`` for
/// ``InMemoryBlobStore`` in tests to avoid touching the filesystem.
public protocol BlobStore {
    /// Writes `data` at `key`, overwriting any existing value.
    func put(_ data: Data, key: String) throws

    /// Reads the data stored at `key`. Throws if no such key exists.
    func get(key: String) throws -> Data

    /// Lists every key currently stored.
    func list() throws -> [String]

    /// Removes the value at `key`. Throws if the key doesn't exist.
    func delete(key: String) throws
}
