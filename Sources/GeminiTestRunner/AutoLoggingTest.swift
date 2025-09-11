import Foundation
import SwiftyBeaver
import gemini_swfit

/// Test auto-logging functionality without requiring API key
class AutoLoggingTest {
    
    static func run() {
        print("🧪 Testing Auto-Logging Functionality")
        print("=====================================")
        
        // Test 1: Create client without any manual logger setup
        print("\n1. Creating GeminiClient (should auto-initialize logging)...")
        
        // Create client with dummy API key
        let client = GeminiClient(apiKey: "dummy-key-for-testing")
        
        // Test 2: Verify logging is working
        print("\n2. Testing if logging is working...")
        
        // Use the logger directly
        SwiftyBeaver.debug("This is a debug message")
        SwiftyBeaver.info("This is an info message")
        SwiftyBeaver.warning("This is a warning message")
        SwiftyBeaver.error("This is an error message")
        
        // Test 3: Try to make a request (will fail but should show logs)
        print("\n3. Testing request logging (expecting API error)...")
        
        Task {
            do {
                let _ = try await client.generateContent(
                    model: .gemini25Flash,
                    text: "Test message"
                )
            } catch {
                print("✅ Expected error occurred, check logs above for request details")
            }
        }
        
        print("\n✅ Auto-logging test completed!")
        print("💡 You should see colored log messages above with timestamps")
    }
}