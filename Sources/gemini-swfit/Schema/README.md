# Schema Module

This module provides JSON Schema generation for structured output responses.

## Architecture

```
Schema/
├── JSONSchemaGenerator.swift  # Dynamic schema generation
├── SchemaProtocols.swift      # Protocols for schema support
└── README.md                  # This file
```

## Components

### JSONSchemaGenerator

Generates JSON Schema from Swift types:
- Automatic type inference
- Nested object support
- Array handling
- Optional fields
- Custom descriptions

### SchemaProtocols

Protocols for extending schema support:
- `SchemaRepresentable` - Custom schema representation
- `SchemaDescribable` - Add descriptions to fields

## Usage Examples

### Basic Structured Output

```swift
struct Person: Codable {
    let name: String
    let age: Int
    let email: String?
}

let response: Person = try await client.generateStructuredOutput(
    model: .gemini25Flash,
    prompt: "Generate a fictional person",
    responseType: Person.self
)
```

### With Custom Schema

```swift
let schema: [String: Any] = [
    "type": "object",
    "properties": [
        "name": ["type": "string", "description": "Full name"],
        "age": ["type": "integer", "minimum": 0],
        "skills": [
            "type": "array",
            "items": ["type": "string"]
        ]
    ],
    "required": ["name", "age"]
]

let config = StructuredOutputConfig(
    responseMimeType: "application/json",
    responseSchema: schema
)

let response: [String: Any] = try await client.generateStructuredOutput(
    model: .gemini25Flash,
    prompt: "Generate a developer profile",
    structuredConfig: config
)
```

### Complex Nested Types

```swift
struct Company: Codable {
    let name: String
    let employees: [Employee]
    let headquarters: Address
}

struct Employee: Codable {
    let name: String
    let role: String
    let department: String
}

struct Address: Codable {
    let street: String
    let city: String
    let country: String
}

let company: Company = try await client.generateStructuredOutput(
    model: .gemini25Flash,
    prompt: "Generate a tech company profile with 3 employees",
    responseType: Company.self
)
```

### Using Schema Protocol

```swift
struct ProductReview: Codable, SchemaDescribable {
    let rating: Int
    let title: String
    let content: String
    let pros: [String]
    let cons: [String]

    static var schemaDescription: String {
        "A detailed product review with ratings and feedback"
    }

    static var propertyDescriptions: [String: String] {
        [
            "rating": "Rating from 1-5 stars",
            "title": "Short review title",
            "content": "Detailed review text",
            "pros": "List of positive aspects",
            "cons": "List of negative aspects"
        ]
    }
}
```

## Schema Generation

The `generateJSONSchema` function automatically generates schemas:

```swift
let schema = try generateJSONSchema(for: MyType.self)
// Returns: [String: Any] representing JSON Schema
```

### Supported Types

| Swift Type | JSON Schema Type |
|------------|------------------|
| String | string |
| Int, Int32, Int64 | integer |
| Double, Float | number |
| Bool | boolean |
| Array<T> | array |
| Optional<T> | nullable field |
| Struct/Class | object |
| Enum (String) | enum |

## Best Practices

1. **Use specific types** - Prefer `Int` over `Any` for better schema generation
2. **Add descriptions** - Implement `SchemaDescribable` for complex types
3. **Validate responses** - Always validate decoded responses
4. **Handle optionals** - Mark truly optional fields as `Optional` in Swift
5. **Test schemas** - Verify generated schemas match your expectations
