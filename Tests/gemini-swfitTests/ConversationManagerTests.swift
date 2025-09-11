import XCTest
@testable import gemini_swfit

final class ConversationManagerTests: BaseGeminiTestSuite {
    
    // MARK: - Basic Conversation Tests
    
    func testChatConversation() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testChatConversation")
        
        // Use new conversation manager
        let conversation = GeminiConversationManager(
            apiKey: apiKey!,
            model: .gemini25Flash
        )
        
        let firstMessage = "My favorite color is blue."
        print("\n📤 [REQUEST] Sending first chat message")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        print("   Message: '\(firstMessage)'")
        print("   Message count: \(conversation.messageCount)")
        
        // First message - simplified API
        let response1 = try await measureAndLog(operationName: "First message") {
            try await conversation.sendMessage(firstMessage)
        }
        
        print("📥 [RESPONSE 1] Length: \(response1.count) characters")
        print("   Content: '\(response1.prefix(100))\(response1.count > 100 ? "..." : "")'")
        print("📝 [HISTORY] History now contains \(conversation.messageCount) messages")
        
        validateBasicResponse(response1)
        XCTAssertEqual(conversation.messageCount, 2, "History should contain user and assistant messages")
        
        let followUpMessage = "What did I just tell you?"
        print("\n📤 [REQUEST] Sending follow-up message")
        print("   Message: '\(followUpMessage)'")
        print("   Message count: \(conversation.messageCount)")
        
        // Follow-up - simpler way
        let response2 = try await measureAndLog(operationName: "Follow-up message") {
            try await conversation.sendMessage(followUpMessage)
        }
        
        print("📥 [RESPONSE 2] Length: \(response2.count) characters")
        print("   Content: '\(response2.prefix(100))\(response2.count > 100 ? "..." : "")'")
        print("📝 [HISTORY] Final history contains \(conversation.messageCount) messages")
        
        validateBasicResponse(response2)
        XCTAssertTrue(response2.lowercased().contains("blue"), "Second response should remember the color blue")
        
        // Show formatted history
        print("\n📋 [FORMATTED HISTORY]")
        print(conversation.getFormattedHistory())
        
        print("✅ [TEST] testChatConversation passed")
    }
    
    // MARK: - Advanced Conversation Features Tests
    
    func testConversationManagerFeatures() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testConversationManagerFeatures")
        
        // Test convenience method
        let conversation = GeminiConversationManager.startConversation(
            apiKey: apiKey!,
            systemInstruction: "You are a helpful math tutor. Explain concepts clearly."
        )
        
        print("\n📤 [REQUEST] Testing conversation manager features")
        print("   System Instruction: '\(conversation.systemInstruction ?? "None")'")
        
        // Test chain calls (get each response)
        print("\n📤 [CHAIN] Starting chain conversation with responses")
        
        let response1 = try await conversation.continueConversationWithResponse("What is algebra?")
        print("📥 [RESPONSE 1] '\(response1.response.prefix(100))...'")
        
        let response2 = try await response1.conversation.continueConversationWithResponse("Can you give me a simple example?")
        print("📥 [RESPONSE 2] '\(response2.response.prefix(100))...'")
        
        let response3 = try await response2.conversation.continueConversationWithResponse("How is this used in real life?")
        print("📥 [RESPONSE 3] '\(response3.response.prefix(100))...'")
        
        print("📊 [STATS] Total messages: \(response3.conversation.messageCount)")
        
        // Test batch message sending
        print("\n📤 [BATCH] Testing batch message sending")
        let batchMessages = [
            "What is geometry?",
            "Explain Pythagorean theorem",
            "Give me a real world application"
        ]
        
        let batchResponses = try await measureAndLog(operationName: "Batch messages") {
            try await response3.conversation.sendBatchMessagesWithDetails(batchMessages)
        }
        
        for (index, batchResponse) in batchResponses.enumerated() {
            print("📥 [BATCH \(index + 1)] '\(batchResponse.aiResponse.prefix(80))...' (\(String(format: "%.1f", batchResponse.duration * 1000))ms)")
        }
        
        // Test metadata response
        let metadataResponse = try await response3.conversation.sendMessageWithMetadata(
            "Summarize our conversation in one sentence."
        )
        
        print("\n📥 [METADATA RESPONSE]")
        print("   Message: '\(metadataResponse.message.prefix(100))...'")
        print("   Duration: \(metadataResponse.duration * 1000)ms")
        print("   Total messages in conversation: \(metadataResponse.messageCount)")
        
        // Test getting specific messages
        if let lastUser = conversation.lastUserMessage, let text = lastUser.text {
            print("👤 [LAST USER] \(text.prefix(50))...")
        }
        
        if let lastAssistant = conversation.lastAssistantMessage, let text = lastAssistant.text {
            print("🤖 [LAST ASSISTANT] \(text.prefix(50))...")
        }
        
        // Test export functionality
        let export = conversation.exportConversation()
        print("\n💾 [EXPORT] Exported conversation with \(export.messages.count) messages")
        print("   Export date: \(export.exportDate)")
        print("   Model: \(export.model.displayName)")
        
        // Test import functionality
        let newConversation = GeminiConversationManager(apiKey: apiKey!)
        newConversation.importConversation(export)
        
        XCTAssertEqual(newConversation.messageCount, conversation.messageCount, 
                      "Imported conversation should have same message count")
        
        print("✅ [TEST] testConversationManagerFeatures passed")
    }
    
    func testRolePlayConversation() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testRolePlayConversation")
        
        // Test role-play convenience method
        let pirateConversation = GeminiConversationManager.rolePlayConversation(
            apiKey: apiKey!,
            role: "pirate captain",
            personality: "You love treasure and say 'arr' a lot. You're friendly but mysterious."
        )
        
        print("\n🏴‍☠️ [ROLE PLAY] Starting pirate conversation")
        
        let response = try await measureAndLog(operationName: "Pirate conversation") {
            try await pirateConversation.sendMessage(
                "Ahoy captain! What's the best way to find treasure?"
            )
        }
        
        print("📥 [PIRATE RESPONSE]")
        print("   '\(response)'")
        
        // Verify role-play effect
        let pirateWords = ["arr", "matey", "treasure", "captain", "ahoy"]
        let containsPirateWord = pirateWords.contains { response.lowercased().contains($0) }
        print("🏴‍☠️ [ROLE CHECK] Contains pirate words: \(containsPirateWord)")
        
        // Test configuration with system instruction
        let scientistConversation = GeminiConversationManager(
            apiKey: apiKey!,
            systemInstruction: "You are a quantum physicist. Explain complex topics simply."
        )
        
        let physicsResponse = try await measureAndLog(operationName: "Scientist conversation") {
            try await scientistConversation.sendMessage(
                "Explain quantum entanglement like I'm 10 years old."
            )
        }
        
        print("\n🔬 [SCIENTIST RESPONSE]")
        print("   Response length: \(physicsResponse.count) characters")
        print("   Preview: '\(physicsResponse.prefix(150))...'")
        
        print("✅ [TEST] testRolePlayConversation passed")
    }
    
    // MARK: - Conversation with Images Test
    
    func testImageWithConversation() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testImageWithConversation")
        
        // Load the existing test image
        guard let imagePath = Bundle.module.path(forResource: "image", ofType: "png") else {
            XCTFail("Test image file not found in bundle")
            return
        }
        let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        
        print("\n📤 [REQUEST] Starting multimodal conversation")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        print("   Image: Test image, \(imageData.count) bytes")
        
        var conversationHistory: [Content] = []
        
        // First message with image
        print("\n👤 [USER] Sending image with question")
        let response1 = try await measureAndLog(operationName: "Image message") {
            try await client!.generateContentWithImage(
                model: .gemini25Flash,
                text: "What shape and color is this?",
                imageData: imageData,
                mimeType: "image/png"
            )
        }
        
        guard let firstResponse = response1.candidates.first?.content.parts.first?.text else {
            XCTFail("First response should contain text")
            return
        }
        
        print("🤖 [ASSISTANT] '\(firstResponse)'")
        
        // Update conversation history
        conversationHistory.append(Content.multimodalMessage(text: "What shape and color is this?", imageData: imageData))
        conversationHistory.append(Content.modelMessage(firstResponse))
        
        // Follow-up question without image
        print("\n👤 [USER] Follow-up question")
        let response2 = try await measureAndLog(operationName: "Follow-up without image") {
            try await client!.sendMessage(
                model: .gemini25Flash,
                message: "What would be a common use for this type of shape in design?",
                history: conversationHistory
            )
        }
        
        guard let secondResponse = response2.candidates.first?.content.parts.first?.text else {
            XCTFail("Second response should contain text")
            return
        }
        
        print("🤖 [ASSISTANT] '\(secondResponse)'")
        
        // Verify responses
        validateBasicResponse(firstResponse)
        validateBasicResponse(secondResponse)
        XCTAssertTrue(firstResponse.lowercased().contains("image") || firstResponse.lowercased().contains("picture"), 
                     "First response should mention that it's an image or picture")
        
        print("📊 [CONVERSATION] Total history length: \(conversationHistory.count + 2) messages")
        print("✅ [TEST] testImageWithConversation passed")
    }
}