import Foundation
import SwiftyBeaver
import gemini_swfit

class LoggingTest {
    
    static func run() async {
        // Setup logging first
        let logger = GeminiLogger.shared
        logger.setupCustomConsole(format: "$DHH:mm:ss.SSS$d $C$L$c $N.$F:$l - $M")
        
        // Create client (you'll need to set GEMINI_API_KEY environment variable)
        let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        
        guard !apiKey.isEmpty else {
            print("❌ Please set GEMINI_API_KEY environment variable")
            print("Example: export GEMINI_API_KEY=your_api_key_here")
            return
        }
        
        print("🚀 Testing GeminiClient logging...")
        print("📝 API Key length: \(apiKey.count)")
        
        // Create Gemini client
        let client = GeminiClient(apiKey: apiKey)
        
        // Test a simple request
        do {
            print("\n📤 Sending test request...")
            let response = try await client.generateContent(
                model: .gemini25Flash,
                text: "Hello! Please respond with just the word 'LOGGING_TEST'"
            )
            
            print("\n📥 Response received!")
            if let text = response.candidates.first?.content.parts.first?.text {
                print("📄 Response: \(text)")
            }
            
            print("\n✅ Test completed successfully!")
            
        } catch {
            print("\n❌ Error occurred: \(error)")
            if let geminiError = error as? GeminiClient.GeminiError {
                print("   GeminiError: \(geminiError.localizedDescription)")
            }
        }
    }
}