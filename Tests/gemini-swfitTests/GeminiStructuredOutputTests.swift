import XCTest
@testable import gemini_swfit

final class GeminiStructuredOutputTests: BaseGeminiTestSuite {
    
    // MARK: - Test Models
    
    struct Recipe: Codable, Equatable {
        let recipeName: String
        let ingredients: [String]
    }
    
    struct Person: Codable, Equatable {
        let name: String
        let age: Int
        let email: String?
    }
    
    struct RecipeList: Codable, Equatable {
        let recipes: [Recipe]
    }
    
    // MARK: - Gemini Structured Output Tests
    
    func testGeminiStructuredOutputWithManualSchema() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testGeminiStructuredOutputWithManualSchema")
        
        let schema: [String: Any] = [
            "type": "ARRAY",
            "items": [
                "type": "OBJECT",
                "properties": [
                    "recipeName": ["type": "STRING"],
                    "ingredients": [
                        "type": "ARRAY",
                        "items": ["type": "STRING"]
                    ]
                ],
                "propertyOrdering": ["recipeName", "ingredients"]
            ]
        ]
        
        logRequest(
            model: .gemini25Flash,
            prompt: "List 2 popular cookie recipes, and include the amounts of ingredients.",
            schema: schema
        )
        
        let response: [Recipe] = try await measureAndLog(operationName: "Gemini structured output with manual schema") {
            try await client!.generateStructuredOutput(
                model: .gemini25Flash,
                prompt: "List 2 popular cookie recipes, and include the amounts of ingredients.",
                responseSchema: schema,
                temperature: 0.1
            )
        }
        
        logStructuredResponse(response)
        
        XCTAssertFalse(response.isEmpty, "Response should not be empty")
        XCTAssertLessThanOrEqual(response.count, 2, "Should return at most 2 recipes")
        
        for recipe in response {
            XCTAssertFalse(recipe.recipeName.isEmpty, "Recipe name should not be empty")
            XCTAssertFalse(recipe.ingredients.isEmpty, "Ingredients should not be empty")
        }
        
        print("✅ [TEST] testGeminiStructuredOutputWithManualSchema passed")
    }
    
    func testGeminiStructuredOutputWithCodableType() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testGeminiStructuredOutputWithCodableType")
        
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "name": ["type": "STRING"],
                "age": ["type": "INTEGER"],
                "email": ["type": "STRING"]
            ],
            "required": ["name", "age"]
        ]
        
        logRequest(
            model: .gemini25Flash,
            prompt: "Create a person profile with name, age, and optional email.",
            responseType: Person.self
        )
        
        let response: Person = try await measureAndLog(operationName: "Gemini structured output with Codable type") {
            try await client!.generateStructuredOutput(
                model: .gemini25Flash,
                prompt: "Create a person profile with name, age, and optional email.",
                responseSchema: schema,
                temperature: 0.1
            )
        }
        
        logStructuredResponse(response)
        
        XCTAssertFalse(response.name.isEmpty, "Name should not be empty")
        XCTAssertGreaterThan(response.age, 0, "Age should be greater than 0")
        
        print("✅ [TEST] testGeminiStructuredOutputWithCodableType passed")
    }
    
    func testGeminiStructuredOutputWithSystemInstruction() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testGeminiStructuredOutputWithSystemInstruction")
        
        let systemInstruction = "You are a professional chef. Always provide detailed ingredient measurements."
        
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "recipeName": ["type": "STRING"],
                "ingredients": [
                    "type": "ARRAY",
                    "items": ["type": "STRING"]
                ]
            ],
            "required": ["recipeName", "ingredients"]
        ]
        
        logRequest(
            model: .gemini25Flash,
            prompt: "Provide one chocolate chip cookie recipe with precise measurements.",
            responseType: Recipe.self,
            systemInstruction: systemInstruction
        )
        
        let response: Recipe = try await measureAndLog(operationName: "Gemini structured output with system instruction") {
            try await client!.generateStructuredOutput(
                model: .gemini25Flash,
                prompt: "Provide one chocolate chip cookie recipe with precise measurements.",
                systemInstruction: systemInstruction,
                responseSchema: schema,
                temperature: 0.1
            )
        }
        
        logStructuredResponse(response)
        
        XCTAssertFalse(response.recipeName.isEmpty, "Recipe name should not be empty")
        XCTAssertFalse(response.ingredients.isEmpty, "Ingredients should not be empty")
        
        // Check for specific ingredients in chocolate chip cookies
        let hasChocolate = response.ingredients.contains { $0.lowercased().contains("chocolate") }
        let hasFlour = response.ingredients.contains { $0.lowercased().contains("flour") }
        XCTAssertTrue(hasChocolate, "Should contain chocolate")
        XCTAssertTrue(hasFlour, "Should contain flour")
        
        print("✅ [TEST] testGeminiStructuredOutputWithSystemInstruction passed")
    }
    
    func testGeminiStructuredOutputWithNestedStructure() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testGeminiStructuredOutputWithNestedStructure")
        
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "recipes": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "recipeName": ["type": "STRING"],
                            "ingredients": [
                                "type": "ARRAY",
                                "items": ["type": "STRING"]
                            ]
                        ],
                        "required": ["recipeName", "ingredients"]
                    ]
                ]
            ],
            "required": ["recipes"]
        ]
        
        logRequest(
            model: .gemini25Flash,
            prompt: "Create a recipe list containing exactly 2 dessert recipes.",
            responseType: RecipeList.self
        )
        
        let response: RecipeList = try await measureAndLog(operationName: "Gemini structured output with nested structure") {
            try await client!.generateStructuredOutput(
                model: .gemini25Flash,
                prompt: "Create a recipe list containing exactly 2 dessert recipes.",
                responseSchema: schema,
                temperature: 0.1
            )
        }
        
        logStructuredResponse(response)
        
        XCTAssertEqual(response.recipes.count, 2, "Should contain exactly 2 recipes")
        
        for recipe in response.recipes {
            XCTAssertFalse(recipe.recipeName.isEmpty, "Recipe name should not be empty")
            XCTAssertFalse(recipe.ingredients.isEmpty, "Ingredients should not be empty")
        }
        
        print("✅ [TEST] testGeminiStructuredOutputWithNestedStructure passed")
    }
    
    func testGeminiStructuredOutputErrorHandling() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testGeminiStructuredOutputErrorHandling")
        
        // Test with invalid API key
        let invalidKey = "invalid-key-for-testing"
        let invalidClient = GeminiClient(apiKey: invalidKey)
        
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "name": ["type": "STRING"],
                "value": ["type": "INTEGER"]
            ]
        ]
        
        print("\n📤 [REQUEST] Testing Gemini structured output error handling with invalid API key")
        print("   Invalid API key: '\(invalidKey)'")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        print("   Prompt: 'What is 2 + 2?'")
        
        struct TestResponse: Codable {}
        
        do {
            let _: TestResponse = try await invalidClient.generateStructuredOutput(
                model: .gemini25Flash,
                prompt: "What is 2 + 2?",
                responseSchema: schema
            )
            XCTFail("Should have thrown an error")
        } catch let error as GeminiClient.GeminiError {
            validateError(error)
        } catch {
            print("❌ [ERROR] Unexpected error type: \(type(of: error)) - \(error)")
            XCTFail("Unexpected error type: \(error)")
        }
        
        print("✅ [TEST] testGeminiStructuredOutputErrorHandling passed")
    }
    
    func testGeminiStructuredOutputConfig() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testGeminiStructuredOutputConfig")
        
        struct Answer: Codable {
            let answer: String
            let confidence: Double
            
            // Provide a default instance for schema generation
            static let `default` = Answer(answer: "", confidence: 0.0)
        }
        
        // Create config using Codable type with default instance
        let config = StructuredOutputConfig(for: Answer.self, defaultInstance: Answer.default)
        
        logRequest(
            model: .gemini25Flash,
            prompt: "What is the capital of France? Provide your answer and a confidence score between 0 and 1.",
            config: config
        )
        
        let response: Answer = try await measureAndLog(operationName: "Gemini structured output with config object") {
            try await client!.generateStructuredOutput(
                model: .gemini25Flash,
                prompt: "What is the capital of France? Provide your answer and a confidence score between 0 and 1.",
                structuredConfig: config,
                temperature: 0.1
            )
        }
        
        logStructuredResponse(response)
        
        XCTAssertFalse(response.answer.isEmpty, "Answer should not be empty")
        XCTAssertGreaterThanOrEqual(response.confidence, 0.0, "Confidence should be >= 0")
        XCTAssertLessThanOrEqual(response.confidence, 1.0, "Confidence should be <= 1")
        
        print("✅ [TEST] testGeminiStructuredOutputConfig passed")
    }
    
    // MARK: - Helper Methods
    
    private func logStructuredResponse<T>(_ response: T) {
        print("\n📥 [STRUCTURED RESPONSE]")
        print("   Type: \(type(of: response))")
        
        // Try to encode as JSON if possible
        if let encodableResponse = response as? any Encodable,
           let data = try? JSONEncoder().encode(encodableResponse),
           let jsonString = try? JSONSerialization.jsonObject(with: data, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonString, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print("   Content:\n\(prettyString)")
        } else {
            print("   Content: \(response)")
        }
    }
    
    private func logRequest(model: GeminiClient.Model, prompt: String, schema: [String: Any]? = nil, responseType: Any.Type? = nil, config: StructuredOutputConfig? = nil, systemInstruction: String? = nil) {
        print("\n📤 [REQUEST] Sending Gemini structured output request")
        print("   Model: \(model.displayName)")
        print("   Prompt: '\(prompt)'")
        
        if let systemInstruction = systemInstruction {
            print("   System Instruction: '\(systemInstruction)'")
        }
        
        if let responseType = responseType {
            print("   Response Type: \(responseType)")
        }
        
        if let config = config {
            print("   Response MIME Type: \(config.responseMimeType)")
            print("   Schema provided: Yes")
        } else if schema != nil {
            print("   Response MIME Type: application/json")
            print("   Schema provided: Yes")
        }
    }
}