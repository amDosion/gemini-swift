import XCTest
@testable import gemini_swfit

/// Base test suite class providing common setup and utilities for all Gemini API integration tests
open class BaseGeminiTestSuite: XCTestCase {
    
    // MARK: - Properties
    
    /// API key loaded from environment variable
    var apiKey: String?
    
    /// Gemini client instance for testing
    var client: GeminiClient?
    
    // MARK: - Setup & Teardown
    
    override open func setUp() {
        super.setUp()
        
        // Setup logging
        GeminiLogger.shared.setup()
        
        print("\n🔧 [SETUP] Initializing \(type(of: self))")
        
        // Get API key from environment variable
        if let keyFromEnv = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            apiKey = keyFromEnv
            print("✅ [SETUP] Using API key from GEMINI_API_KEY environment variable (length: \(apiKey?.count ?? 0))")
            client = GeminiClient(apiKey: apiKey!)
            print("✅ [SETUP] GeminiClient initialized successfully")
        } else {
            print("❌ [SETUP] GEMINI_API_KEY environment variable not found!")
            print("⚠️  [SETUP] Please set GEMINI_API_KEY environment variable to run integration tests")
            apiKey = nil
            client = nil
        }
    }
    
    override open func setUpWithError() throws {
        try super.setUpWithError()
        
        // Setup logging
        GeminiLogger.shared.setup()
        
        print("\n🔧 [SETUP] Initializing \(type(of: self))")
        
        // Get API key from environment variable
        if let keyFromEnv = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            apiKey = keyFromEnv
            print("✅ [SETUP] Using API key from GEMINI_API_KEY environment variable (length: \(apiKey?.count ?? 0))")
            client = GeminiClient(apiKey: apiKey!)
            print("✅ [SETUP] GeminiClient initialized successfully")
        } else {
            print("❌ [SETUP] GEMINI_API_KEY environment variable not found!")
            print("⚠️  [SETUP] Please set GEMINI_API_KEY environment variable to run integration tests")
            apiKey = nil
            client = nil
        }
    }
    
    // Async setup for tests that need it
    func asyncSetUp() async {
        // Setup logging
        GeminiLogger.shared.setup()
        
        print("\n🔧 [ASYNC SETUP] Initializing \(type(of: self))")
        
        // Get API key from environment variable
        if let keyFromEnv = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            apiKey = keyFromEnv
            print("✅ [ASYNC SETUP] Using API key from GEMINI_API_KEY environment variable (length: \(apiKey?.count ?? 0))")
            client = GeminiClient(apiKey: apiKey!)
            print("✅ [ASYNC SETUP] GeminiClient initialized successfully")
        } else {
            print("❌ [ASYNC SETUP] GEMINI_API_KEY environment variable not found!")
            print("⚠️  [ASYNC SETUP] Please set GEMINI_API_KEY environment variable to run integration tests")
            apiKey = nil
            client = nil
        }
    }
    
    override open func tearDown() {
        print("\n🧹 [TEARDOWN] Cleaning up \(type(of: self))")
        client = nil
        apiKey = nil
        super.tearDown()
    }
    
    // MARK: - Test Utilities
    
    /// Helper method to skip tests if API key is not available
    func skipIfNoAPIKey() throws {
        try XCTSkipIf(apiKey == nil, "GEMINI_API_KEY environment variable not set")
    }
    
    /// Helper method to measure and log execution time
    func measureAndLog<T>(
        operationName: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        print("\n⏱️ [MEASURE] Starting \(operationName)")
        let startTime = Date()
        let result = try await operation()
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        print("⏱️ [MEASURE] \(operationName) completed in \(duration * 1000)ms")
        return result
    }
    
    /// Helper method to log request details
    func logRequest(
        model: GeminiClient.Model,
        prompt: String,
        temperature: Double? = nil,
        systemInstruction: String? = nil
    ) {
        print("\n📤 [REQUEST] Sending request")
        print("   Model: \(model.displayName)")
        print("   Prompt: '\(prompt)'")
        if let temp = temperature {
            print("   Temperature: \(temp)")
        }
        if let instruction = systemInstruction {
            print("   System Instruction: '\(instruction)'")
        }
    }
    
    /// Helper method to log response details
    func logResponse(_ response: String, prefix: String = "📥 [RESPONSE]") {
        print("\(prefix) Response length: \(response.count) characters")
        print("   Content: '\(response.prefix(100))\(response.count > 100 ? "..." : "")'")
    }
    
    /// Helper method to log image request details
    func logImageRequest(
        model: GeminiClient.Model,
        prompt: String,
        imageSize: Int,
        mimeType: String
    ) {
        print("\n📤 [REQUEST] Sending image analysis request")
        print("   Model: \(model.displayName)")
        print("   Prompt: '\(prompt)'")
        print("   Image size: \(imageSize) bytes")
        print("   MIME type: \(mimeType)")
    }
    
    /// Helper method to validate basic response
    func validateBasicResponse(_ response: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(response.isEmpty, "Response should not be empty", file: file, line: line)
    }
    
    /// Helper method to validate error handling
    func validateError(_ error: Error, expectedErrorType: AnyClass? = nil, file: StaticString = #filePath, line: UInt = #line) {
        if let expectedType = expectedErrorType {
            XCTAssertTrue(type(of: error) == expectedType, "Expected \(expectedType), got \(type(of: error))", file: file, line: line)
        }
        
        if let geminiError = error as? GeminiClient.GeminiError {
            print("✅ [ERROR] Correctly caught GeminiError: \(geminiError.localizedDescription)")
            switch geminiError {
            case .apiError(let message, let code):
                print("   API Error - Message: \(message)")
                print("   API Error - Code: \(code ?? 0)")
            default:
                break
            }
        }
    }
}