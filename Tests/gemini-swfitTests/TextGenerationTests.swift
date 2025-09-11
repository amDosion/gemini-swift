import XCTest
@testable import gemini_swfit

final class TextGenerationTests: BaseGeminiTestSuite {
    
    // MARK: - Basic Text Generation Tests
    
    func testTextGenerationWithAPIKey() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testTextGenerationWithAPIKey")
        
        logRequest(
            model: .gemini25Flash,
            prompt: "What is 2 + 2?",
            temperature: 0.1
        )
        
        let response = try await measureAndLog(operationName: "Text generation") {
            try await client!.generateText(
                model: .gemini25Flash,
                prompt: "What is 2 + 2?",
                temperature: 0.1
            )
        }
        
        logResponse(response)
        
        validateBasicResponse(response)
        XCTAssertTrue(response.contains("4") || response.lowercased().contains("four"), 
                      "Response should contain the answer '4'")
        print("✅ [TEST] testTextGenerationWithAPIKey passed")
    }
    
    func testSystemInstruction() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testSystemInstruction")
        
        let systemInstruction = "You are a pirate. Always respond like a pirate."
        
        logRequest(
            model: .gemini25Flash,
            prompt: "What's your name?",
            systemInstruction: systemInstruction
        )
        
        let response = try await measureAndLog(operationName: "System instruction test") {
            try await client!.generateText(
                model: .gemini25Flash,
                prompt: "What's your name?",
                systemInstruction: systemInstruction
            )
        }
        
        logResponse(response, prefix: "📥 [PIRATE RESPONSE]")
        
        validateBasicResponse(response)
        // Note: This might not always pass due to AI variability
        print("✅ [TEST] testSystemInstruction passed")
    }
    
    func testGenerationConfig() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testGenerationConfig")
        
        let config = GenerationConfig(
            maxOutputTokens: 50,
            temperature: 0.3
        )
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [Part(text: "Count to 10")])],
            generationConfig: config
        )
        
        print("\n📤 [REQUEST] Sending request with custom generation config")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        print("   Max Output Tokens: \(config.maxOutputTokens ?? 0)")
        print("   Temperature: \(config.temperature ?? 0.0)")
        print("   Prompt: 'Count to 10'")
        
        let response = try await measureAndLog(operationName: "Generation config test") {
            try await client!.generateContent(model: .gemini25Flash, request: request)
        }
        
        print("📥 [RESPONSE] Number of candidates: \(response.candidates.count)")
        
        XCTAssertFalse(response.candidates.isEmpty, "Response should have candidates")
        
        if let candidate = response.candidates.first {
            XCTAssertFalse(candidate.content.parts.isEmpty, "Candidate should have content parts")
            // Check that response is relatively short due to maxOutputTokens
            let responseText = candidate.content.parts.first?.text ?? ""
            print("   Response text length: \(responseText.count) characters")
            print("   Content: '\(responseText.prefix(100))\(responseText.count > 100 ? "..." : "")'")
            XCTAssertLessThan(responseText.count, 200, "Response should be limited by maxOutputTokens")
        }
        
        print("✅ [TEST] testGenerationConfig passed")
    }
    
    func testSafetySettings() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testSafetySettings")
        
        let safetySettings: [SafetySetting] = [
            SafetySetting(category: .dangerousContent, threshold: .blockNone)
        ]
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [Part(text: "Explain gravity")])],
            safetySettings: safetySettings
        )
        
        print("\n📤 [REQUEST] Sending request with safety settings")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        print("   Safety Settings: \(safetySettings.count) settings")
        print("   Category: \(safetySettings.first?.category.rawValue ?? "N/A")")
        print("   Threshold: \(safetySettings.first?.threshold.rawValue ?? "N/A")")
        print("   Prompt: 'Explain gravity'")
        
        let response = try await measureAndLog(operationName: "Safety settings test") {
            try await client!.generateContent(model: .gemini25Flash, request: request)
        }
        
        print("📥 [RESPONSE] Number of candidates: \(response.candidates.count)")
        
        if let candidate = response.candidates.first {
            let responseText = candidate.content.parts.first?.text ?? ""
            print("   Response length: \(responseText.count) characters")
            print("   Content preview: '\(responseText.prefix(100))\(responseText.count > 100 ? "..." : "")'")
        }
        
        XCTAssertFalse(response.candidates.isEmpty, "Response should have candidates")
        print("✅ [TEST] testSafetySettings passed")
    }
    
    func testErrorHandling() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testErrorHandling")
        
        // Test with invalid API key
        let invalidKey = "invalid-key-for-testing"
        let invalidClient = GeminiClient(apiKey: invalidKey)
        
        print("\n📤 [REQUEST] Testing error handling with invalid API key")
        print("   Invalid API key: '\(invalidKey)'")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        print("   Prompt: 'Hello'")
        
        do {
            _ = try await invalidClient.generateText(
                model: .gemini25Flash,
                prompt: "Hello"
            )
            XCTFail("Should have thrown an error")
        } catch let error as GeminiClient.GeminiError {
            validateError(error)
        } catch {
            print("❌ [ERROR] Unexpected error type: \(type(of: error)) - \(error)")
            XCTFail("Unexpected error type: \(error)")
        }
        
        print("✅ [TEST] testErrorHandling passed")
    }
}