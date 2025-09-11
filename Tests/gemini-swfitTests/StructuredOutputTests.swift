import XCTest
@testable import gemini_swfit

final class StructuredOutputTests: XCTestCase {
    
    // MARK: - Test Models
    
    struct SimpleUser: Codable, Equatable {
        let name: String
        let age: Int
        let email: String?
    }
    
    struct Product: Codable, Equatable {
        let id: String
        let name: String
        let price: Double
        let inStock: Bool
    }
    
    struct Order: Codable, Equatable {
        let orderId: String
        let products: [Product]
        let total: Double
    }
    
    // MARK: - StructuredOutputConfig Tests
    
    func testStructuredOutputConfigInitialization() {
        // Test basic initialization
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "name": ["type": "STRING"],
                "age": ["type": "INTEGER"]
            ]
        ]
        
        let config = StructuredOutputConfig(
            responseMimeType: "application/json",
            responseSchema: schema
        )
        
        XCTAssertEqual(config.responseMimeType, "application/json")
        XCTAssertEqual(config.responseSchema["type"] as? String, "OBJECT")
    }
    
    func testStructuredOutputConfigDefaultMimeType() {
        let schema: [String: Any] = ["type": "STRING"]
        
        let config = StructuredOutputConfig(responseSchema: schema)
        
        XCTAssertEqual(config.responseMimeType, "application/json")
    }
    
    // MARK: - GenerationConfig Tests
    
    func testGenerationConfigWithStructuredOutput() {
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "answer": ["type": "STRING"]
            ]
        ]
        
        let config = GenerationConfig(
            temperature: 0.5,
            responseMimeType: "application/json",
            responseSchema: schema
        )
        
        XCTAssertEqual(config.temperature, 0.5)
        XCTAssertEqual(config.responseMimeType, "application/json")
        XCTAssertNotNil(config.responseSchema)
    }
    
    func testGenerationConfigWithoutStructuredOutput() {
        let config = GenerationConfig()
        
        XCTAssertNil(config.responseMimeType)
        XCTAssertNil(config.responseSchema)
    }
    
    // MARK: - JSON Schema Validation Tests
    
    func testValidObjectSchema() {
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "name": ["type": "STRING"],
                "age": ["type": "INTEGER"],
                "email": ["type": "STRING"]
            ],
            "required": ["name", "age"]
        ]
        
        XCTAssertTrue(validateSchema(schema))
    }
    
    func testValidArraySchema() {
        let schema: [String: Any] = [
            "type": "ARRAY",
            "items": [
                "type": "OBJECT",
                "properties": [
                    "id": ["type": "STRING"],
                    "value": ["type": "NUMBER"]
                ]
            ]
        ]
        
        XCTAssertTrue(validateSchema(schema))
    }
    
    func testInvalidSchemaMissingType() {
        let schema: [String: Any] = [
            "properties": [
                "name": ["type": "STRING"]
            ]
        ]
        
        XCTAssertFalse(validateSchema(schema))
    }
    
    // MARK: - Schema Helper Tests
    
    func testCreateSimpleObjectSchema() {
        let schema = createSimpleObjectSchema(
            properties: ["name": "STRING", "age": "INTEGER"],
            required: ["name"]
        )
        
        XCTAssertEqual(schema["type"] as? String, "OBJECT")
        let properties = schema["properties"] as? [String: [String: String]]
        XCTAssertEqual(properties?["name"]?["type"], "STRING")
        XCTAssertEqual(properties?["age"]?["type"], "INTEGER")
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["name"])
    }
    
    func testCreateArraySchema() {
        let itemSchema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "title": ["type": "STRING"]
            ]
        ]
        
        let arraySchema = createArraySchema(items: itemSchema)
        
        XCTAssertEqual(arraySchema["type"] as? String, "ARRAY")
        let items = arraySchema["items"] as? [String: Any]
        XCTAssertEqual(items?["type"] as? String, "OBJECT")
        let properties = items?["properties"] as? [String: [String: String]]
        XCTAssertEqual(properties?["title"]?["type"], "STRING")
    }
    
    // MARK: - Model Tests
    
    func testSimpleUserEncodingDecoding() throws {
        let user = SimpleUser(name: "John Doe", age: 30, email: "john@example.com")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        
        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(SimpleUser.self, from: data)
        
        XCTAssertEqual(user, decodedUser)
    }
    
    func testOrderWithNestedStructureEncodingDecoding() throws {
        let products = [
            Product(id: "1", name: "Widget", price: 19.99, inStock: true),
            Product(id: "2", name: "Gadget", price: 29.99, inStock: false)
        ]
        
        let order = Order(orderId: "ORD-123", products: products, total: 49.98)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(order)
        
        let decoder = JSONDecoder()
        let decodedOrder = try decoder.decode(Order.self, from: data)
        
        XCTAssertEqual(order, decodedOrder)
    }
    
    // MARK: - Performance Tests
    
    func testSchemaCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = createSimpleObjectSchema(
                    properties: ["name": "STRING", "age": "INTEGER", "email": "STRING"],
                    required: ["name", "age"]
                )
            }
        }
    }
    
    func testConfigCreationPerformance() {
        let schema: [String: Any] = ["type": "STRING"]
        
        measure {
            for _ in 0..<1000 {
                _ = StructuredOutputConfig(responseSchema: schema)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateSchema(_ schema: [String: Any]) -> Bool {
        guard let type = schema["type"] as? String else { return false }
        
        switch type.uppercased() {
        case "OBJECT":
            guard let properties = schema["properties"] as? [String: Any] else { return false }
            for (_, value) in properties {
                guard let property = value as? [String: Any],
                      let _ = property["type"] as? String else {
                    return false
                }
            }
            return true
            
        case "ARRAY":
            guard let items = schema["items"] as? [String: Any] else { return false }
            return validateSchema(items)
            
        case "STRING", "INTEGER", "NUMBER", "BOOLEAN":
            return true
            
        default:
            return false
        }
    }
    
    private func createSimpleObjectSchema(properties: [String: String], required: [String] = []) -> [String: Any] {
        var schemaProperties: [String: [String: String]] = [:]
        for (key, type) in properties {
            schemaProperties[key] = ["type": type]
        }
        
        var schema: [String: Any] = [
            "type": "OBJECT",
            "properties": schemaProperties
        ]
        
        if !required.isEmpty {
            schema["required"] = required
        }
        
        return schema
    }
    
    private func createArraySchema(items: [String: Any]) -> [String: Any] {
        return [
            "type": "ARRAY",
            "items": items
        ]
    }
}