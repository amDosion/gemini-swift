import XCTest
@testable import gemini_swfit
#if canImport(UIKit)
import UIKit
#endif

/// Main integration test suite that serves as the entry point
/// All individual test suites will be discovered and run automatically by XCTest
final class GeminiAPIIntegrationTests: XCTestCase {
    
    // MARK: - Test Suite Configuration
    
    override class func setUp() {
        super.setUp()
        print("\n🚀 [TEST SUITE] Starting Gemini API Integration Tests")
        print("📋 [TEST SUITE] Available test categories:")
        print("   • TextGenerationTests - Basic text generation functionality")
        print("   • ConversationManagerTests - Conversation management features")
        print("   • ImageAnalysisTests - Multimodal image analysis capabilities")
        print("   • BatchProcessingTests - Batch processing for text and images")
        print("   • GeminiAPIIntegrationTests - Integration and demo tests")
    }
    
    override class func tearDown() {
        print("\n✅ [TEST SUITE] Gemini API Integration Tests completed")
        super.tearDown()
    }
    
    // MARK: - Environment Check
    
    func testEnvironmentSetup() {
        print("\n🔍 [ENV] Checking test environment...")
        
        // Check if API key is available
        let hasApiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] != nil
        print("   API Key available: \(hasApiKey ? "✅" : "❌")")
        
        // Check if test image is available
        let testImagePath = Bundle.module.path(forResource: "image", ofType: "png")
        let hasTestImage = testImagePath != nil
        print("   Test image available: \(hasTestImage ? "✅" : "❌")")
        
        // Log test environment info
        print("   Test bundle path: \(Bundle.module.bundlePath)")
        #if canImport(UIKit)
        print("   Platform: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        #else
        print("   Platform: macOS (Swift Package Manager)")
        #endif
        
        if !hasApiKey {
            print("\n⚠️  [WARNING] GEMINI_API_KEY environment variable not set!")
            print("   Integration tests will be skipped.")
            print("   Set the environment variable to run full test suite:")
            print("   export GEMINI_API_KEY=your_api_key_here")
        }
    }
    
    // MARK: - Integration Demo
    
    /// This test demonstrates a quick integration check without making actual API calls
    func testClientInitialization() {
        print("\n🔧 [TEST] Testing client initialization...")
        
        // Test that we can import and create the client type
        let clientType = GeminiClient.self
        XCTAssertNotNil(clientType, "GeminiClient type should be available")
        
        // Test model enum
        let model = GeminiClient.Model.gemini25Flash
        XCTAssertEqual(model.displayName, "Gemini 2.5 Flash", "Model display name should match")
        
        // Test conversation manager
        let conversationType = GeminiConversationManager.self
        XCTAssertNotNil(conversationType, "GeminiConversationManager type should be available")
        
        print("✅ [TEST] All types are properly imported and accessible")
    }
    
    // MARK: - Performance Benchmark (Optional)
    
    func testTestExecutionSpeed() {
        measure {
            // Measure how quickly we can initialize the client
            let model = GeminiClient.Model.gemini25Flash
            _ = model.displayName
        }
    }
}