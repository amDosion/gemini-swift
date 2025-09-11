import XCTest
@testable import gemini_swfit

final class ImageAnalysisTests: BaseGeminiTestSuite {
    
    // MARK: - Basic Image Analysis Tests
    
    func testBasicImageAnalysis() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testBasicImageAnalysis")
        
        // Load the existing test image
        guard let imagePath = Bundle.module.path(forResource: "image", ofType: "png") else {
            XCTFail("Test image file not found in bundle")
            return
        }
        let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        
        logImageRequest(
            model: .gemini25Flash,
            prompt: "Describe this image in detail. What colors and shapes do you see?",
            imageSize: imageData.count,
            mimeType: "image/png"
        )
        
        let response = try await measureAndLog(operationName: "Basic image analysis") {
            try await client!.analyzeImage(
                model: .gemini25Flash,
                prompt: "Describe this image in detail. What colors and shapes do you see?",
                imageData: imageData,
                mimeType: "image/png"
            )
        }
        
        logResponse(response, prefix: "📥 [ANALYSIS RESULT]")
        
        validateBasicResponse(response)
        XCTAssertTrue(response.lowercased().contains("red") || response.lowercased().contains("square"), 
                     "Response should mention red color or square shape")
        
        print("✅ [TEST] testBasicImageAnalysis passed")
    }
    
    func testMultipleImageModels() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testMultipleImageModels")
        
        // Load the existing test image
        guard let imagePath = Bundle.module.path(forResource: "image", ofType: "png") else {
            XCTFail("Test image file not found in bundle")
            return
        }
        let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        let prompt = "Analyze the visual patterns in this image."
        
        // Test different multimodal models
        let multimodalModels = GeminiClient.Model.allCases.filter { $0.supportsMultimodal }
        print("\n📤 [REQUEST] Testing \(multimodalModels.count) multimodal models")
        
        var results: [(model: GeminiClient.Model, response: String, duration: TimeInterval)] = []
        
        for model in multimodalModels {
            print("\n🔍 [MODEL TEST] Testing \(model.displayName)")
            
            do {
                _ = try await measureAndLog(operationName: "Model \(model.displayName)") {
                    try await client!.analyzeImage(
                        model: model,
                        prompt: prompt,
                        imageData: imageData,
                        mimeType: "image/png"
                    )
                }
                
                // Note: measureAndLog doesn't return duration, so we'll calculate it manually
                let startTime = Date()
                let actualResponse = try await client!.analyzeImage(
                    model: model,
                    prompt: prompt,
                    imageData: imageData,
                    mimeType: "image/png"
                )
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)
                
                results.append((model: model, response: actualResponse, duration: duration))
                
                print("   ✅ Success in \(String(format: "%.2f", duration * 1000))ms")
                print("   📥 Response: \(actualResponse.count) chars - '\(actualResponse.prefix(100))...'")
                
                validateBasicResponse(actualResponse)
                
            } catch {
                print("   ❌ Failed: \(error)")
                // Don't fail the test for individual model failures, as some models might not be available
            }
        }
        
        print("\n📊 [RESULTS] Successfully tested \(results.count) out of \(multimodalModels.count) models")
        XCTAssertGreaterThan(results.count, 0, "At least one multimodal model should work")
        
        print("✅ [TEST] testMultipleImageModels passed")
    }
    
    func testImageAnalysisWithSystemInstruction() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testImageAnalysisWithSystemInstruction")
        
        // Load the existing test image
        guard let imagePath = Bundle.module.path(forResource: "image", ofType: "png") else {
            XCTFail("Test image file not found in bundle")
            return
        }
        let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        let systemInstruction = "You are an art critic. Analyze images with sophisticated artistic terminology."
        
        print("\n📤 [REQUEST] Image analysis with system instruction")
        print("   System Instruction: '\(systemInstruction)'")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        
        let response = try await measureAndLog(operationName: "Art critic analysis") {
            try await client!.generateContentWithImage(
                model: .gemini25Flash,
                text: "Please analyze this artwork.",
                imageData: imageData,
                mimeType: "image/png",
                systemInstruction: systemInstruction
            )
        }
        
        guard let responseText = response.candidates.first?.content.parts.first?.text else {
            XCTFail("Response should contain text")
            return
        }
        
        print("\n📥 [RESPONSE] Art critic analysis:")
        print("   Length: \(responseText.count) characters")
        print("   Content: '\(responseText.prefix(300))\(responseText.count > 300 ? "..." : "")'")
        
        validateBasicResponse(responseText)
        
        print("✅ [TEST] testImageAnalysisWithSystemInstruction passed")
    }
}