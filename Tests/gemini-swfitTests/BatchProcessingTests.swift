import XCTest
@testable import gemini_swfit

final class BatchProcessingTests: BaseGeminiTestSuite {
    
    // MARK: - Text Batch Processing Tests
    
    func testBatchProcessing() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testBatchProcessing")
        
        let prompts = ["What is 1+1?", "What is 2+2?", "What is 3+3?"]
        
        print("\n📤 [REQUEST] Starting batch processing with \(prompts.count) prompts")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        print("   Temperature: 0.1")
        for (index, prompt) in prompts.enumerated() {
            print("   Prompt \(index + 1): '\(prompt)'")
        }
        
        let capturedApiKey = self.apiKey!
        let results = try await measureAndLog(operationName: "Batch text processing") {
            try await withThrowingTaskGroup(of: String.self) { group in
                for (index, prompt) in prompts.enumerated() {
                    group.addTask { [capturedApiKey] in
                        let taskStartTime = Date()
                        let client = GeminiClient(apiKey: capturedApiKey)
                        let response = try await client.generateText(
                            model: .gemini25Flash,
                            prompt: prompt,
                            temperature: 0.1
                        )
                        let taskEndTime = Date()
                        print("⏱️  [BATCH] Task \(index + 1) completed in \(taskEndTime.timeIntervalSince(taskStartTime) * 1000)ms")
                        return response
                    }
                }
                
                var results: [String] = []
                for try await response in group {
                    results.append(response)
                }
                return results
            }
        }
        
        print("\n📥 [RESPONSE] Received \(results.count) responses")
        
        XCTAssertEqual(results.count, 3, "Should receive exactly 3 responses")
        
        for (index, response) in results.enumerated() {
            print("   Response \(index + 1): \(response.count) characters - '\(response.prefix(50))\(response.count > 50 ? "..." : "")'")
            validateBasicResponse(response)
        }
        
        print("✅ [TEST] testBatchProcessing passed")
    }
    
    // MARK: - Image Batch Processing Tests
    
    func testBatchImageAnalysis() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testBatchImageAnalysis")
        
        // Load the existing test image
        guard let imagePath = Bundle.module.path(forResource: "image", ofType: "png") else {
            XCTFail("Test image file not found in bundle")
            return
        }
        let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        
        // Create test images array with multiple copies of the same image
        let testImages: [(name: String, data: Data, expectedContent: String)] = [
            ("Test Image 1", imageData, "image"),
            ("Test Image 2", imageData, "image"),
            ("Test Image 3", imageData, "image"),
            ("Test Image 4", imageData, "image")
        ]
        
        print("\n📤 [REQUEST] Starting batch analysis of \(testImages.count) images")
        
        let capturedApiKey = self.apiKey! // Capture the API key to avoid data race
        
        let results = try await measureAndLog(operationName: "Batch image analysis") {
            try await withThrowingTaskGroup(of: (name: String, response: String, duration: TimeInterval).self) { group in
                
                for (index, testImage) in testImages.enumerated() {
                    group.addTask {
                        let taskStartTime = Date()
                        let client = GeminiClient(apiKey: capturedApiKey)
                        let response = try await client.analyzeImage(
                            model: .gemini25Flash,
                            prompt: "Describe this image briefly, focusing on colors and shapes.",
                            imageData: testImage.data,
                            mimeType: "image/png"
                        )
                        let taskEndTime = Date()
                        let duration = taskEndTime.timeIntervalSince(taskStartTime)
                        
                        print("⏱️  [BATCH \(index + 1)] \(testImage.name) analyzed in \(String(format: "%.2f", duration * 1000))ms")
                        return (name: testImage.name, response: response, duration: duration)
                    }
                }
                
                var batchResults: [(name: String, response: String, duration: TimeInterval)] = []
                for try await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }
        }
        
        print("\n📥 [RESULTS] Processed \(results.count) images")
        
        // Verify all results
        XCTAssertEqual(results.count, testImages.count, "Should receive response for each image")
        
        for result in results {
            print("\n📷 [RESULT] \(result.name):")
            print("   Duration: \(String(format: "%.2f", result.duration * 1000))ms")
            print("   Response: '\(result.response.prefix(100))\(result.response.count > 100 ? "..." : "")'")
            
            validateBasicResponse(result.response)
        }
        
        print("✅ [TEST] testBatchImageAnalysis passed")
    }
    
    // MARK: - Mixed Batch Processing Tests
    
    func testMixedBatchProcessing() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testMixedBatchProcessing")
        
        // Load the existing test image
        guard let imagePath = Bundle.module.path(forResource: "image", ofType: "png") else {
            XCTFail("Test image file not found in bundle")
            return
        }
        let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        
        // Create mixed batch of text and image requests
        let textPrompts = [
            "What is the capital of France?",
            "Explain photosynthesis in one sentence.",
            "Who wrote Romeo and Juliet?"
        ]
        
        print("\n📤 [REQUEST] Starting mixed batch processing")
        print("   Text prompts: \(textPrompts.count)")
        print("   Image analyses: 2")
        
        let capturedApiKey = self.apiKey!
        
        let capturedImageData = imageData
        let results = try await measureAndLog(operationName: "Mixed batch processing") {
            try await withThrowingTaskGroup(of: (type: String, response: String, duration: TimeInterval).self) { group in
                
                // Add text processing tasks
                for (index, prompt) in textPrompts.enumerated() {
                    group.addTask { [capturedApiKey] in
                        let taskStartTime = Date()
                        let client = GeminiClient(apiKey: capturedApiKey)
                        let response = try await client.generateText(
                            model: .gemini25Flash,
                            prompt: prompt,
                            temperature: 0.1
                        )
                        let taskEndTime = Date()
                        let duration = taskEndTime.timeIntervalSince(taskStartTime)
                        
                        print("⏱️  [TEXT \(index + 1)] Completed in \(String(format: "%.2f", duration * 1000))ms")
                        return (type: "text", response: response, duration: duration)
                    }
                }
                
                // Add image processing tasks
                for i in 1...2 {
                    group.addTask { [capturedApiKey, capturedImageData] in
                        let taskStartTime = Date()
                        let client = GeminiClient(apiKey: capturedApiKey)
                        let response = try await client.analyzeImage(
                            model: .gemini25Flash,
                            prompt: "What do you see in this image?",
                            imageData: capturedImageData,
                            mimeType: "image/png"
                        )
                        let taskEndTime = Date()
                        let duration = taskEndTime.timeIntervalSince(taskStartTime)
                        
                        print("⏱️  [IMAGE \(i)] Completed in \(String(format: "%.2f", duration * 1000))ms")
                        return (type: "image", response: response, duration: duration)
                    }
                }
                
                var batchResults: [(type: String, response: String, duration: TimeInterval)] = []
                for try await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }
        }
        
        print("\n📥 [RESULTS] Processed \(results.count) total requests")
        
        // Verify all results
        XCTAssertEqual(results.count, 5, "Should receive exactly 5 responses (3 text + 2 image)")
        
        let textResults = results.filter { $0.type == "text" }
        let imageResults = results.filter { $0.type == "image" }
        
        XCTAssertEqual(textResults.count, 3, "Should have 3 text responses")
        XCTAssertEqual(imageResults.count, 2, "Should have 2 image responses")
        
        // Calculate average durations
        let avgTextDuration = textResults.reduce(0) { $0 + $1.duration } / Double(textResults.count)
        let avgImageDuration = imageResults.reduce(0) { $0 + $1.duration } / Double(imageResults.count)
        
        print("\n📊 [PERFORMANCE]")
        print("   Average text processing time: \(String(format: "%.2f", avgTextDuration * 1000))ms")
        print("   Average image processing time: \(String(format: "%.2f", avgImageDuration * 1000))ms")
        print("   Image/Text ratio: \(String(format: "%.2f", avgImageDuration / avgTextDuration))x")
        
        // Validate all responses
        for result in results {
            validateBasicResponse(result.response)
        }
        
        print("✅ [TEST] testMixedBatchProcessing passed")
    }
}