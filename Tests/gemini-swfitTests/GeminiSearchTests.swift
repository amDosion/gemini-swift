import XCTest
@testable import gemini_swfit

final class GeminiSearchTests: BaseGeminiTestSuite {
    
    // MARK: - Tool Model Tests (Unit tests that don't require API key)
    
    func testGoogleSearchToolCreation() {
        print("\n🧪 [TEST] Starting testGoogleSearchToolCreation")
        
        let tool = Tool.googleSearch()
        XCTAssertNotNil(tool.googleSearch)
        XCTAssertNil(tool.urlContext)
        
        print("✅ [TEST] testGoogleSearchToolCreation passed")
    }
    
    func testUrlContextToolCreation() {
        print("\n🧪 [TEST] Starting testUrlContextToolCreation")
        
        let tool = Tool.urlContext()
        XCTAssertNotNil(tool.urlContext)
        XCTAssertNil(tool.googleSearch)
        
        print("✅ [TEST] testUrlContextToolCreation passed")
    }
    
    func testToolEncoding() throws {
        print("\n🧪 [TEST] Starting testToolEncoding")
        
        let googleSearchTool = Tool.googleSearch()
        let jsonData = try JSONEncoder().encode(googleSearchTool)
        XCTAssertNotNil(jsonData)
        XCTAssertFalse(jsonData.isEmpty)
        
        // Verify it can be decoded back
        let decodedTool = try JSONDecoder().decode(Tool.self, from: jsonData)
        XCTAssertNotNil(decodedTool.googleSearch)
        
        print("✅ [TEST] testToolEncoding passed")
    }
    
    // MARK: - Request Model Tests (Unit tests that don't require API key)
    
    func testGenerateContentRequestWithTools() {
        print("\n🧪 [TEST] Starting testGenerateContentRequestWithTools")
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [Part(text: "Test query")])],
            tools: [Tool.googleSearch()]
        )
        
        XCTAssertEqual(request.contents.count, 1)
        XCTAssertEqual(request.tools?.count, 1)
        XCTAssertNotNil(request.tools?.first?.googleSearch)
        
        print("✅ [TEST] testGenerateContentRequestWithTools passed")
    }
    
    func testGenerateContentRequestWithoutTools() {
        print("\n🧪 [TEST] Starting testGenerateContentRequestWithoutTools")
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [Part(text: "Test query")])]
        )
        
        XCTAssertEqual(request.contents.count, 1)
        XCTAssertNil(request.tools)
        
        print("✅ [TEST] testGenerateContentRequestWithoutTools passed")
    }
    
    // MARK: - Grounding Metadata Tests (Unit tests that don't require API key)
    
    func testGroundingMetadataDecoding() throws {
        print("\n🧪 [TEST] Starting testGroundingMetadataDecoding")
        
        let json = """
        {
            "webSearchQueries": ["UEFA Euro 2024 winner", "who won euro 2024"],
            "groundingChunks": [
                {
                    "web": {
                        "uri": "https://example.com/article1",
                        "title": "Euro 2024 Final Results"
                    }
                },
                {
                    "web": {
                        "uri": "https://example.com/article2",
                        "title": "Spain's Victory"
                    }
                }
            ],
            "groundingSupports": [
                {
                    "segment": {
                        "startIndex": 0,
                        "endIndex": 85,
                        "text": "Spain won Euro 2024"
                    },
                    "groundingChunkIndices": [0]
                }
            ]
        }
        """.data(using: .utf8)!
        
        let metadata = try JSONDecoder().decode(GroundingMetadata.self, from: json)
        
        XCTAssertEqual(metadata.webSearchQueries?.count, 2)
        XCTAssertEqual(metadata.groundingChunks?.count, 2)
        XCTAssertEqual(metadata.groundingSupports?.count, 1)
        
        if let firstChunk = metadata.groundingChunks?.first?.web {
            XCTAssertEqual(firstChunk.uri, "https://example.com/article1")
            XCTAssertEqual(firstChunk.title, "Euro 2024 Final Results")
        }
        
        if let firstSupport = metadata.groundingSupports?.first {
            XCTAssertEqual(firstSupport.segment.startIndex, 0)
            XCTAssertEqual(firstSupport.segment.endIndex, 85)
            XCTAssertEqual(firstSupport.groundingChunkIndices, [0])
        }
        
        print("✅ [TEST] testGroundingMetadataDecoding passed")
    }
    
    func testCandidateWithGroundingMetadata() throws {
        print("\n🧪 [TEST] Starting testCandidateWithGroundingMetadata")
        
        let json = """
        {
            "content": {
                "parts": [{"text": "Spain won Euro 2024, defeating England 2-1 in the final."}],
                "role": "model"
            },
            "groundingMetadata": {
                "webSearchQueries": ["Euro 2024 winner"],
                "groundingChunks": [
                    {
                        "web": {
                            "uri": "https://uefa.com",
                            "title": "Official UEFA Report"
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!
        
        let candidate = try JSONDecoder().decode(Candidate.self, from: json)
        
        XCTAssertEqual(candidate.content.parts.first?.text, "Spain won Euro 2024, defeating England 2-1 in the final.")
        XCTAssertNotNil(candidate.groundingMetadata)
        XCTAssertEqual(candidate.groundingMetadata?.groundingChunks?.count, 1)
        
        print("✅ [TEST] testCandidateWithGroundingMetadata passed")
    }
    
    // MARK: - URL Detection Tests (Unit tests that don't require API key)
    
    func testUrlDetectionFromText() {
        print("\n🧪 [TEST] Starting testUrlDetectionFromText")
        
        // Test single URL
        let text1 = "Check out https://example.com for more info"
        let urls1 = extractUrlsFromText(text1)
        XCTAssertEqual(urls1.count, 1)
        XCTAssertEqual(urls1.first?.absoluteString, "https://example.com")
        
        // Test multiple URLs
        let text2 = "Visit https://example.com and http://test.org"
        let urls2 = extractUrlsFromText(text2)
        XCTAssertEqual(urls2.count, 2)
        
        // Test no URLs
        let text3 = "This text has no URLs"
        let urls3 = extractUrlsFromText(text3)
        XCTAssertTrue(urls3.isEmpty)
        
        // Test URLs with paths
        let text4 = "See https://example.com/path/to/resource?query=value"
        let urls4 = extractUrlsFromText(text4)
        XCTAssertEqual(urls4.count, 1)
        XCTAssertEqual(urls4.first?.absoluteString, "https://example.com/path/to/resource?query=value")
        
        print("✅ [TEST] testUrlDetectionFromText passed")
    }
    
    func testUrlDetectionPerformance() {
        print("\n🧪 [TEST] Starting testUrlDetectionPerformance")
        
        let longText = String(repeating: "This is a test with no URLs. ", count: 1000)
        
        measure {
            _ = extractUrlsFromText(longText)
        }
        
        print("✅ [TEST] testUrlDetectionPerformance passed")
    }
    
    // MARK: - Response Parsing Tests (Unit tests that don't require API key)
    
    func testSearchResponseParsing() throws {
        print("\n🧪 [TEST] Starting testSearchResponseParsing")
        
        let jsonResponse = """
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {
                                "text": "Spain won Euro 2024, defeating England 2-1 in the final. This victory marks Spain's record fourth European Championship title."
                            }
                        ],
                        "role": "model"
                    },
                    "groundingMetadata": {
                        "webSearchQueries": [
                            "UEFA Euro 2024 winner",
                            "who won euro 2024"
                        ],
                        "searchEntryPoint": {
                            "renderedContent": "<!-- HTML and CSS for the search widget -->"
                        },
                        "groundingChunks": [
                            {
                                "web": {
                                    "uri": "https://vertexaisearch.cloud.google.com/....",
                                    "title": "aljazeera.com"
                                }
                            },
                            {
                                "web": {
                                    "uri": "https://vertexaisearch.cloud.google.com/....",
                                    "title": "uefa.com"
                                }
                            }
                        ],
                        "groundingSupports": [
                            {
                                "segment": {
                                    "startIndex": 0,
                                    "endIndex": 85,
                                    "text": "Spain won Euro 2024, defeating England 2-1 in the final."
                                },
                                "groundingChunkIndices": [0]
                            },
                            {
                                "segment": {
                                    "startIndex": 86,
                                    "endIndex": 210,
                                    "text": "This victory marks Spain's record fourth European Championship title."
                                },
                                "groundingChunkIndices": [0, 1]
                            }
                        ]
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: jsonResponse)
        
        XCTAssertEqual(response.candidates.count, 1)
        
        let candidate = response.candidates.first!
        XCTAssertEqual(candidate.content.parts.first?.text, "Spain won Euro 2024, defeating England 2-1 in the final. This victory marks Spain's record fourth European Championship title.")
        
        let grounding = candidate.groundingMetadata!
        XCTAssertEqual(grounding.webSearchQueries?.count, 2)
        XCTAssertEqual(grounding.groundingChunks?.count, 2)
        XCTAssertEqual(grounding.groundingSupports?.count, 2)
        
        print("✅ [TEST] testSearchResponseParsing passed")
    }
    
    // MARK: - Integration Tests (Require API key)
    
    func testGoogleSearchWithAPI() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testGoogleSearchWithAPI")
        
        logRequest(
            model: .gemini25Flash,
            prompt: "Who won the euro 2024?",
            temperature: 0.1
        )
        
        let response = try await measureAndLog(operationName: "Google search API call") {
            try await client!.generateContentWithGoogleSearch(
                model: .gemini25Flash,
                text: "Who won the euro 2024?"
            )
        }
        
        // Validate response
        XCTAssertFalse(response.candidates.isEmpty)
        let candidate = response.candidates.first!
        XCTAssertFalse(candidate.content.parts.isEmpty)
        let text = candidate.content.parts.first?.text
        XCTAssertFalse(text?.isEmpty ?? true)
        
        logResponse(text ?? "")
        
        // Check for grounding metadata (optional)
        if let grounding = candidate.groundingMetadata {
            print("\n🔍 [GROUNDING] Found grounding metadata")
            if let queries = grounding.webSearchQueries {
                print("   Search queries: \(queries)")
            }
            if let chunks = grounding.groundingChunks {
                print("   Found \(chunks.count) source chunks")
            }
        } else {
            print("\n📝 [INFO] No grounding metadata in response (this is normal)")
        }
        
        print("✅ [TEST] testGoogleSearchWithAPI passed")
    }
    
    func testGoogleSearchCurlExample() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testGoogleSearchCurlExample")
        print("   Testing exact curl example: 'Who won the euro 2024?'")
        
        // Create request exactly matching the curl example
        let request = GeminiGenerateContentRequest(
            contents: [
                Content(parts: [
                    Part(text: "Who won the euro 2024?")
                ])
            ],
            tools: [
                Tool.googleSearch()
            ]
        )
        
        print("\n📤 [REQUEST] Sending request matching curl example")
        print("   Model: gemini-2.5-flash")
        print("   Content: Who won the euro 2024?")
        print("   Tools: [google_search]")
        
        let response = try await measureAndLog(operationName: "Curl example API call") {
            try await client!.generateContent(model: .gemini25Flash, request: request)
        }
        
        // Validate response
        XCTAssertFalse(response.candidates.isEmpty, "Response should have candidates")
        let candidate = response.candidates.first!
        XCTAssertFalse(candidate.content.parts.isEmpty, "Candidate should have content parts")
        let text = candidate.content.parts.first?.text
        XCTAssertFalse(text?.isEmpty ?? true, "Response text should not be empty")
        
        logResponse(text ?? "")
        
        // Check for grounding metadata
        if let grounding = candidate.groundingMetadata {
            print("\n🔍 [GROUNDING] Found grounding metadata")
            if let queries = grounding.webSearchQueries {
                print("   Search queries: \(queries)")
            }
            if let chunks = grounding.groundingChunks {
                print("   Found \(chunks.count) source chunks")
                for (index, chunk) in chunks.enumerated() {
                    if let web = chunk.web {
                        print("   Chunk \(index + 1): \(web.title ?? "No title")")
                        print("   URI: \(web.uri ?? "No URI")")
                    }
                }
            }
        } else {
            print("\n📝 [INFO] No grounding metadata in response")
        }
        
        // Verify the response contains relevant information
        let responseText = text ?? ""
        let hasSpain = responseText.contains("Spain") || responseText.contains("spain")
        let hasEuro2024 = responseText.contains("Euro 2024") || responseText.contains("euro 2024")
        let hasWinner = responseText.contains("won") || responseText.contains("champion") || responseText.contains("victory")
        
        XCTAssertTrue(hasSpain, "Response should mention Spain as the winner")
        XCTAssertTrue(hasEuro2024, "Response should mention Euro 2024")
        XCTAssertTrue(hasWinner, "Response should indicate who won")
        
        print("✅ [TEST] testGoogleSearchCurlExample passed")
    }
    
    func testWhatHappenedTodayWithSearchAndUrl() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testWhatHappenedTodayWithSearchAndUrl")
        print("   Testing combined Google Search + URL Context for today's events")
        
        let query = "今天发生了什么 请搜索最新新闻并分析 https://www.bbc.com/news"
        
        logRequest(
            model: .gemini25Flash,
            prompt: query,
            temperature: 0.1
        )
        
        let response = try await measureAndLog(operationName: "Today's events with search and URL") {
            try await client!.generateContentWithSearchAndUrlContext(
                model: .gemini25Flash,
                text: query,
                onUrlDetected: { urls in
                    print("\n🔗 [URL DETECTED] Found URLs in query:")
                    for url in urls {
                        print("   - \(url.absoluteString)")
                    }
                    print("✅ Allowing URL access for news analysis")
                    return true
                }
            )
        }
        
        // Validate response
        XCTAssertFalse(response.candidates.isEmpty, "Response should have candidates")
        let candidate = response.candidates.first!
        XCTAssertFalse(candidate.content.parts.isEmpty, "Candidate should have content parts")
        let text = candidate.content.parts.first?.text
        XCTAssertFalse(text?.isEmpty ?? true, "Response text should not be empty")
        
        logResponse(text ?? "")
        
        // Check for grounding metadata from Google Search
        if let grounding = candidate.groundingMetadata {
            print("\n🔍 [GROUNDING] Found grounding metadata")
            if let queries = grounding.webSearchQueries {
                print("   Search queries: \(queries)")
            }
            if let chunks = grounding.groundingChunks {
                print("   Found \(chunks.count) source chunks")
                for (index, chunk) in chunks.prefix(3).enumerated() {
                    if let web = chunk.web {
                        print("   Chunk \(index + 1): \(web.title ?? "No title")")
                    }
                }
            }
        } else {
            print("\n📝 [INFO] No grounding metadata in response")
        }
        
        // Verify the response contains recent information
        let responseText = text ?? ""
        let hasRecentInfo = responseText.contains("2024") || 
                           responseText.contains("今天") || 
                           responseText.contains("今日") ||
                           responseText.contains("recent") ||
                           responseText.contains("latest")
        
        let hasNewsContent = responseText.contains("新闻") || 
                            responseText.contains("news") ||
                            responseText.contains("报道") ||
                            responseText.contains("report")
        
        XCTAssertTrue(hasRecentInfo, "Response should contain recent/today's information")
        XCTAssertTrue(hasNewsContent, "Response should contain news-related content")
        
        print("✅ [TEST] testWhatHappenedTodayWithSearchAndUrl passed")
    }
    
    func testUrlContextWithAPI() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testUrlContextWithAPI")
        
        let query = "Compare https://example.com and https://test.org"
        
        logRequest(
            model: .gemini25Flash,
            prompt: query,
            temperature: 0.1
        )
        
        let response = try await measureAndLog(operationName: "URL context API call") {
            try await client!.generateContentWithUrlContext(
                model: .gemini25Flash,
                text: query,
                onUrlDetected: { urls in
                    print("\n🔗 [URL DETECTED] Found URLs:")
                    for url in urls {
                        print("   - \(url.absoluteString)")
                    }
                    return true // Allow access for testing
                }
            )
        }
        
        // Validate response
        XCTAssertFalse(response.candidates.isEmpty)
        let candidate = response.candidates.first!
        XCTAssertFalse(candidate.content.parts.isEmpty)
        let text = candidate.content.parts.first?.text
        XCTAssertFalse(text?.isEmpty ?? true)
        
        logResponse(text ?? "")
        
        print("✅ [TEST] testUrlContextWithAPI passed")
    }
    
    func testCombinedToolsWithAPI() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testCombinedToolsWithAPI")
        
        let query = "Search for recent news about artificial intelligence"
        
        logRequest(
            model: .gemini25Flash,
            prompt: query,
            temperature: 0.1
        )
        
        let response = try await measureAndLog(operationName: "Combined tools API call") {
            try await client!.generateContentWithSearchAndUrlContext(
                model: .gemini25Flash,
                text: query,
                onUrlDetected: { urls in
                    print("\n🔗 [URL DETECTED] Found URLs:")
                    for url in urls {
                        print("   - \(url.absoluteString)")
                    }
                    return true // Allow access for testing
                }
            )
        }
        
        // Validate response
        XCTAssertFalse(response.candidates.isEmpty)
        let candidate = response.candidates.first!
        XCTAssertFalse(candidate.content.parts.isEmpty)
        let text = candidate.content.parts.first?.text
        XCTAssertFalse(text?.isEmpty ?? true)
        
        logResponse(text ?? "")
        
        print("✅ [TEST] testCombinedToolsWithAPI passed")
    }
    
    // MARK: - Test Gemini Client Methods (Unit tests that don't require API key)
    
    func testGeminiClientHasSearchMethods() {
        print("\n🧪 [TEST] Starting testGeminiClientHasSearchMethods")
        
        // Test that the methods are callable by checking their signatures
        let _: (GeminiClient.Model, String, String?, GenerationConfig?, [SafetySetting]?) async throws -> GeminiGenerateContentResponse = client!.generateContentWithGoogleSearch
        let _: (GeminiClient.Model, String, String?, GenerationConfig?, [SafetySetting]?, (([URL]) -> Bool)?) async throws -> GeminiGenerateContentResponse = client!.generateContentWithUrlContext
        let _: (GeminiClient.Model, String, String?, GenerationConfig?, [SafetySetting]?, (([URL]) -> Bool)?) async throws -> GeminiGenerateContentResponse = client!.generateContentWithSearchAndUrlContext
        
        // If the above lines compile without error, the methods exist
        XCTAssertTrue(true, "All search methods exist on GeminiClient")
        
        print("✅ [TEST] testGeminiClientHasSearchMethods passed")
    }
    
    // MARK: - Error Handling Tests
    
    func testUrlContextAccessDenied() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testUrlContextAccessDenied")
        
        let query = "Analyze https://example.com"
        
        do {
            _ = try await client!.generateContentWithUrlContext(
                model: .gemini25Flash,
                text: query,
                onUrlDetected: { urls in
                    print("\n🔗 [URL DETECTED] Denying access to URLs")
                    return false // Deny access
                }
            )
            
            XCTFail("Expected GeminiError.invalidModel to be thrown")
        } catch let error as GeminiClient.GeminiError {
            if case .invalidModel(let message) = error {
                XCTAssertEqual(message, "URL context access denied by user")
                print("✅ [TEST] Correctly caught access denied error")
            } else {
                XCTFail("Expected .invalidModel error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        print("✅ [TEST] testUrlContextAccessDenied passed")
    }
    
    // MARK: - Helper Methods
    
    /// Helper method to test URL extraction (mimicking the private method)
    private func extractUrlsFromText(_ text: String) -> [URL] {
        var urls: [URL] = []
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        
        if let matches = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let url = match.url {
                    urls.append(url)
                }
            }
        }
        
        return urls
    }
}