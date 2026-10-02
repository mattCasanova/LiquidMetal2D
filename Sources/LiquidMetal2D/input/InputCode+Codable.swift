//
//  InputCode+Codable.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

import Foundation

/// Saved by case name (`"space"`, `"gamepadA"`), never by raw value. The raw
/// value is the index into the input system's tables and shifts whenever a
/// code is added in the middle of the enum; a binding saved as a number would
/// silently come back as a different key. Renaming a case breaks saved files
/// the same way renaming an animation-file key does, so it needs a decode
/// path for the old name.
extension InputCode: Codable {
    /// The case name, as written to files.
    public var name: String {
        InputCode.names[rawValue]
    }

    /// Looks a code up by its saved name; `nil` for a name this engine does not know.
    public init?(name: String) {
        guard let code = InputCode.byName[name] else { return nil }
        self = code
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        guard let code = InputCode(name: name) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unknown InputCode name \"\(name)\"")
        }
        self = code
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }

    /// Case names in raw-value order. `String(describing:)` of a plain enum
    /// case is its name; `InputCodeCodableTests` pins that.
    private static let names: [String] = allCases.map { String(describing: $0) }

    private static let byName: [String: InputCode] = {
        var map: [String: InputCode] = [:]
        for code in allCases {
            map[String(describing: code)] = code
        }
        return map
    }()
}
