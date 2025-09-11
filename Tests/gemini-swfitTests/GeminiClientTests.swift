import XCTest
@testable import gemini_swfit

final class GeminiClientTests: XCTestCase {
    
    var client: GeminiClient!
    
    override func setUp() {
        super.setUp()
        guard let testAPIKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            XCTFail("GEMINI_API_KEY environment variable not set")
            return
        }
        client = GeminiClient(apiKey: testAPIKey)
    }
    
    override func tearDown() {
        client = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testClientInitialization() {
        // Test that client can be initialized without accessing private properties
        XCTAssertNotNil(client)
    }
    
    func testClientInitializationWithMultipleKeys() {
        guard let testKey1 = ProcessInfo.processInfo.environment["GEMINI_API_KEY_1"],
              let testKey2 = ProcessInfo.processInfo.environment["GEMINI_API_KEY_2"] else {
            XCTFail("GEMINI_API_KEY_1 and GEMINI_API_KEY_2 environment variables not set")
            return
        }
        let keys = [testKey1, testKey2]
        let multiKeyClient = GeminiClient(apiKeys: keys)
        XCTAssertNotNil(multiKeyClient)
    }
    
    // MARK: - Model Tests
    
    func testModelProperties() {
        XCTAssertEqual(GeminiClient.Model.gemini25Flash.displayName, "Gemini 2.5 Flash")
        XCTAssertEqual(GeminiClient.Model.gemini25Pro.displayName, "Gemini 2.5 Pro")
        XCTAssertEqual(GeminiClient.Model.gemini25FlashLite.displayName, "Gemini 2.5 Flash Lite")
    }
    
    // MARK: - Configuration Tests
    
    func testGenerationConfig() {
        let config = GenerationConfig(
            maxOutputTokens: 100,
            temperature: 0.7,
            topP: 0.9,
            topK: 40
        )
        
        XCTAssertEqual(config.maxOutputTokens, 100)
        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.topP, 0.9)
        XCTAssertEqual(config.topK, 40)
    }
    
    func testSafetySettings() {
        let setting = SafetySetting(
            category: .harassment,
            threshold: .blockSome
        )
        
        XCTAssertEqual(setting.category, .harassment)
        XCTAssertEqual(setting.threshold, .blockSome)
    }
    
    // MARK: - Content Tests
    
    func testContentCreation() {
        let content = Content(parts: [Part(text: "Hello")])
        XCTAssertEqual(content.parts.count, 1)
        XCTAssertEqual(content.parts.first?.text, "Hello")
    }
    
    func testPartCreation() {
        let textPart = Part(text: "Test text")
        XCTAssertEqual(textPart.text, "Test text")
        
        let inlineData = Part(
            text: nil,
            inlineData: InlineData(mimeType: "image/png", data: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
        )
        XCTAssertEqual(inlineData.inlineData?.mimeType, "image/png")
    }
    
    // MARK: - System Instruction Tests
    
    func testSystemInstruction() {
        let instruction = SystemInstruction(text: "You are a helpful assistant")
        XCTAssertEqual(instruction.parts.count, 1)
        XCTAssertEqual(instruction.parts.first?.text, "You are a helpful assistant")
        
        let partsInstruction = SystemInstruction(
            parts: [Part(text: "Part 1"), Part(text: "Part 2")]
        )
        XCTAssertEqual(partsInstruction.parts.count, 2)
    }
    
    // MARK: - Error Tests
    
    func testGeminiErrorDescription() {
        let apiError = GeminiClient.GeminiError.apiError("Test error", 400)
        XCTAssertEqual(apiError.localizedDescription, "API Error: Test error (Code: 400)")
        
        let requestError = GeminiClient.GeminiError.requestFailed(NSError(domain: "Test", code: -1))
        XCTAssertTrue(requestError.localizedDescription.contains("Request failed"))
    }
    
    // MARK: - Mock Tests (Offline Tests)
    
    func testContentJSONEncoding() throws {
        let content = Content(parts: [Part(text: "Hello, world!")])
        let jsonData = try JSONEncoder().encode(content)
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        XCTAssertTrue(jsonString?.contains("Hello, world!") == true)
    }
    
    func testBatchContentCreation() {
        let contents = [
            Content(parts: [Part(text: "First message")]),
            Content(parts: [Part(text: "Second message")])
        ]
        
        XCTAssertEqual(contents.count, 2)
        XCTAssertEqual(contents[0].parts.first?.text, "First message")
        XCTAssertEqual(contents[1].parts.first?.text, "Second message")
    }
    
    // MARK: - Performance Tests
    
    func testContentEncodingPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = Content(parts: [Part(text: "Performance test content")])
            }
        }
    }
}