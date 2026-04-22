//
//  FileBlobStore.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/20/26.
//

import Foundation

/// Sandbox-backed ``BlobStore`` writing to `Documents/<subdirectory>/<key>`.
/// Files are invisible to the user — for save games, settings, caches,
/// anything app-managed. Use ``DocumentIO`` for user-visible exports.
public final class FileBlobStore: BlobStore {
    private let baseURL: URL

    /// Creates (or opens) the store. Pass a `subdirectory` to partition
    /// multiple stores inside the same app — `"saves"`, `"settings"`,
    /// `"presets"`. When `nil`, writes directly to the Documents root.
    public init(subdirectory: String? = nil) throws {
        let docs = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        self.baseURL = subdirectory
            .map { docs.appendingPathComponent($0) } ?? docs
        try FileManager.default.createDirectory(
            at: baseURL, withIntermediateDirectories: true)
    }

    public func put(_ data: Data, key: String) throws {
        try data.write(to: url(for: key), options: .atomic)
    }

    public func get(key: String) throws -> Data {
        try Data(contentsOf: url(for: key))
    }

    public func list() throws -> [String] {
        try FileManager.default
            .contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
            .map { $0.lastPathComponent }
    }

    public func delete(key: String) throws {
        try FileManager.default.removeItem(at: url(for: key))
    }

    private func url(for key: String) -> URL {
        baseURL.appendingPathComponent(key)
    }
}
