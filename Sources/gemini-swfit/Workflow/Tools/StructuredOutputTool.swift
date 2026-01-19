//
//  StructuredOutputTool.swift
//  gemini-swfit
//
//  Tool for generating structured output with JSON Schema
//

import Foundation
import SwiftyBeaver

/// Tool for generating structured JSON output using Gemini's JSON mode
public final class StructuredOutputTool: AgentTool, @unchecked Sendable {

    // MARK: - Properties

    public let id: String
    public let name: String = "structured_output"
    public let description: String = "Generates structured JSON output based on a schema"
    public let inputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "prompt": ["type": "string", "description": "The prompt for structured output generation"],
            "schema": ["type": "object", "description": "JSON Schema defining the output structure"]
        ],
        "required": ["prompt", "schema"]
    ]

    private let client: GeminiClient
    private let logger: SwiftyBeaver.Type

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        client: GeminiClient,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.client = client
        self.logger = logger
    }

    // MARK: - AgentTool Protocol

    public func execute(parameters: [String: AnySendable]) async throws -> AnySendable {
        guard let promptValue = parameters["prompt"], let prompt = promptValue.stringValue else {
            throw ToolError.missingParameter("prompt")
        }

        guard let schemaValue = parameters["schema"], let schemaDict = schemaValue.dictValue else {
            throw ToolError.missingParameter("schema")
        }

        let jsonSchema = buildJSONSchema(from: schemaDict)

        let response = try await client.generateContent(
            model: .gemini25Flash,
            prompt: prompt,
            generationConfig: GeminiClient.GenerationConfig(
                temperature: 0.2,
                responseMimeType: "application/json",
                responseSchema: jsonSchema
            )
        )

        guard let text = response.text else {
            throw ToolError.executionFailed("No response generated")
        }

        // Parse and validate JSON
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            throw ToolError.executionFailed("Invalid JSON response")
        }

        return AnySendable(json)
    }

    // MARK: - Helper Methods

    private func buildJSONSchema(from dict: [String: AnySendable]) -> [String: Any] {
        // Convert dictionary to Gemini-compatible JSON Schema
        var schema: [String: Any] = [:]
        schema["type"] = dict["type"]?.stringValue ?? "object"

        if let propertiesValue = dict["properties"],
           let properties = propertiesValue.dictValue {
            // Convert [String: AnySendable] to [String: Any]
            var propsAny: [String: Any] = [:]
            for (key, value) in properties {
                propsAny[key] = value.value
            }
            schema["properties"] = propsAny
        }

        if let requiredValue = dict["required"],
           let required = requiredValue.arrayValue {
            schema["required"] = required.compactMap { $0.stringValue }
        }

        return schema
    }
}

// MARK: - Schema Builder

/// Builder for creating JSON schemas for structured output
public struct SchemaBuilder {

    // MARK: - Types

    public enum SchemaType: String {
        case string = "string"
        case number = "number"
        case integer = "integer"
        case boolean = "boolean"
        case array = "array"
        case object = "object"
    }

    public struct Property {
        public let name: String
        public let type: SchemaType
        public let description: String?
        public let enumValues: [String]?
        public let items: SchemaType?
        public let required: Bool

        public init(
            name: String,
            type: SchemaType,
            description: String? = nil,
            enumValues: [String]? = nil,
            items: SchemaType? = nil,
            required: Bool = true
        ) {
            self.name = name
            self.type = type
            self.description = description
            self.enumValues = enumValues
            self.items = items
            self.required = required
        }
    }

    // MARK: - Properties

    private var properties: [Property] = []
    private var schemaDescription: String?

    // MARK: - Builder Methods

    public init() {}

    public mutating func description(_ description: String) -> SchemaBuilder {
        self.schemaDescription = description
        return self
    }

    public mutating func addProperty(_ property: Property) -> SchemaBuilder {
        properties.append(property)
        return self
    }

    public mutating func addString(
        _ name: String,
        description: String? = nil,
        required: Bool = true
    ) -> SchemaBuilder {
        properties.append(Property(
            name: name,
            type: .string,
            description: description,
            required: required
        ))
        return self
    }

    public mutating func addNumber(
        _ name: String,
        description: String? = nil,
        required: Bool = true
    ) -> SchemaBuilder {
        properties.append(Property(
            name: name,
            type: .number,
            description: description,
            required: required
        ))
        return self
    }

    public mutating func addInteger(
        _ name: String,
        description: String? = nil,
        required: Bool = true
    ) -> SchemaBuilder {
        properties.append(Property(
            name: name,
            type: .integer,
            description: description,
            required: required
        ))
        return self
    }

    public mutating func addBoolean(
        _ name: String,
        description: String? = nil,
        required: Bool = true
    ) -> SchemaBuilder {
        properties.append(Property(
            name: name,
            type: .boolean,
            description: description,
            required: required
        ))
        return self
    }

    public mutating func addEnum(
        _ name: String,
        values: [String],
        description: String? = nil,
        required: Bool = true
    ) -> SchemaBuilder {
        properties.append(Property(
            name: name,
            type: .string,
            description: description,
            enumValues: values,
            required: required
        ))
        return self
    }

    public mutating func addArray(
        _ name: String,
        itemType: SchemaType,
        description: String? = nil,
        required: Bool = true
    ) -> SchemaBuilder {
        properties.append(Property(
            name: name,
            type: .array,
            description: description,
            items: itemType,
            required: required
        ))
        return self
    }

    // MARK: - Build

    public func build() -> [String: Any] {
        var schema: [String: Any] = [
            "type": "object"
        ]

        if let desc = schemaDescription {
            schema["description"] = desc
        }

        var props: [String: Any] = [:]
        var requiredFields: [String] = []

        for property in properties {
            var propSchema: [String: Any] = [
                "type": property.type.rawValue
            ]

            if let desc = property.description {
                propSchema["description"] = desc
            }

            if let enumValues = property.enumValues {
                propSchema["enum"] = enumValues
            }

            if property.type == .array, let items = property.items {
                propSchema["items"] = ["type": items.rawValue]
            }

            props[property.name] = propSchema

            if property.required {
                requiredFields.append(property.name)
            }
        }

        schema["properties"] = props
        if !requiredFields.isEmpty {
            schema["required"] = requiredFields
        }

        return schema
    }
}

// MARK: - Predefined Schemas

public extension SchemaBuilder {
    /// Schema for analysis results
    static var analysisResult: [String: Any] {
        var builder = SchemaBuilder()
        _ = builder.description("Analysis result with findings and recommendations")
            .addString("summary", description: "Brief summary of analysis")
            .addArray("findings", itemType: .string, description: "Key findings")
            .addArray("recommendations", itemType: .string, description: "Action items")
            .addNumber("confidence", description: "Confidence score 0-1")

        return builder.build()
    }

    /// Schema for entity extraction
    static var entityExtraction: [String: Any] {
        var builder = SchemaBuilder()
        _ = builder.description("Extracted entities from text")
            .addArray("persons", itemType: .string, description: "Person names")
            .addArray("organizations", itemType: .string, description: "Organization names")
            .addArray("locations", itemType: .string, description: "Location names")
            .addArray("dates", itemType: .string, description: "Date references")
            .addArray("amounts", itemType: .string, description: "Monetary amounts")

        return builder.build()
    }

    /// Schema for sentiment analysis
    static var sentimentAnalysis: [String: Any] {
        var builder = SchemaBuilder()
        _ = builder.description("Sentiment analysis result")
            .addEnum("sentiment", values: ["positive", "negative", "neutral", "mixed"])
            .addNumber("score", description: "Sentiment score -1 to 1")
            .addString("summary", description: "Explanation of sentiment")
            .addArray("keywords", itemType: .string, description: "Key emotion words")

        return builder.build()
    }

    /// Schema for document classification
    static var documentClassification: [String: Any] {
        var builder = SchemaBuilder()
        _ = builder.description("Document classification result")
            .addString("category", description: "Primary document category")
            .addArray("subcategories", itemType: .string, description: "Secondary categories")
            .addNumber("confidence", description: "Classification confidence")
            .addArray("topics", itemType: .string, description: "Key topics")

        return builder.build()
    }
}

// MARK: - Tool Error

public enum ToolError: Error, Sendable {
    case missingParameter(String)
    case invalidParameter(String, String)
    case executionFailed(String)
    case timeout
}
