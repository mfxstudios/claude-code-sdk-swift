//
//  OutputConfig.swift
//  ClaudeCodeSDK
//
//  Structured output configuration for Claude API
//

import Foundation

/// Configuration for structured output (JSON schema validation).
///
/// When set, Claude will produce output conforming to the specified JSON schema.
public struct OutputConfig: Sendable, Codable, Equatable {
    /// The output format configuration
    public let format: Format

    public init(format: Format) {
        self.format = format
    }

    /// Output format types
    public enum Format: Sendable, Codable, Equatable {
        /// Plain text output
        case text

        /// JSON output conforming to a schema
        case jsonSchema(JSONSchemaDefinition)

        private enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "text":
                self = .text
            case "json_schema":
                let schema = try container.decode(JSONSchemaDefinition.self, forKey: .jsonSchema)
                self = .jsonSchema(schema)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown output format type: \(type)"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .text:
                try container.encode("text", forKey: .type)
            case .jsonSchema(let schema):
                try container.encode("json_schema", forKey: .type)
                try container.encode(schema, forKey: .jsonSchema)
            }
        }
    }
}

/// A JSON schema definition for structured output
public struct JSONSchemaDefinition: Sendable, Codable, Equatable {
    /// Name of the schema
    public let name: String

    /// The JSON schema as a dictionary
    public let schema: [String: AnyCodable]

    /// Whether to enforce strict schema validation
    public let strict: Bool?

    public init(name: String, schema: [String: AnyCodable], strict: Bool? = nil) {
        self.name = name
        self.schema = schema
        self.strict = strict
    }
}
