//
//  AnyCodable.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// A type-erased Codable value using a Sendable-safe representation
public struct AnyCodable: Codable, Sendable, Equatable {
    /// The underlying sendable value
    private let storage: SendableValue

    /// Enum to store values in a Sendable-safe way
    private enum SendableValue: Sendable, Equatable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([AnyCodable])
        case dictionary([String: AnyCodable])
    }

    /// The underlying value as Any (for compatibility)
    public var value: Any {
        switch storage {
        case .null:
            return NSNull()
        case .bool(let v):
            return v
        case .int(let v):
            return v
        case .double(let v):
            return v
        case .string(let v):
            return v
        case .array(let v):
            return v.map { $0.value }
        case .dictionary(let v):
            return v.mapValues { $0.value }
        }
    }

    public init(_ value: Any) {
        switch value {
        case is NSNull:
            self.storage = .null
        case let bool as Bool:
            self.storage = .bool(bool)
        case let int as Int:
            self.storage = .int(int)
        case let double as Double:
            self.storage = .double(double)
        case let string as String:
            self.storage = .string(string)
        case let array as [Any]:
            self.storage = .array(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            self.storage = .dictionary(dictionary.mapValues { AnyCodable($0) })
        case let codable as AnyCodable:
            self.storage = codable.storage
        default:
            self.storage = .null
        }
    }

    private init(storage: SendableValue) {
        self.storage = storage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.storage = .null
        } else if let bool = try? container.decode(Bool.self) {
            self.storage = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self.storage = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self.storage = .double(double)
        } else if let string = try? container.decode(String.self) {
            self.storage = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self.storage = .array(array)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.storage = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode AnyCodable"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch storage {
        case .null:
            try container.encodeNil()
        case .bool(let v):
            try container.encode(v)
        case .int(let v):
            try container.encode(v)
        case .double(let v):
            try container.encode(v)
        case .string(let v):
            try container.encode(v)
        case .array(let v):
            try container.encode(v)
        case .dictionary(let v):
            try container.encode(v)
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        lhs.storage == rhs.storage
    }
}

// MARK: - ExpressibleBy Protocols

extension AnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.storage = .null
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.storage = .bool(value)
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.storage = .int(value)
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.storage = .double(value)
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.storage = .string(value)
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self.storage = .array(elements.map { AnyCodable($0) })
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        self.storage = .dictionary(Dictionary(uniqueKeysWithValues: elements.map { ($0, AnyCodable($1)) }))
    }
}
