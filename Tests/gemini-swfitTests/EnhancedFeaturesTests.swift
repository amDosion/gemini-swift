import XCTest
@testable import gemini_swfit

final class EnhancedFeaturesTests: XCTestCase {

    // MARK: - Retry Configuration Tests

    func testRetryConfigDefault() {
        let config = GeminiRetryConfig.default
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.baseDelay, 1.0)
        XCTAssertEqual(config.maxDelay, 30.0)
        XCTAssertTrue(config.retryOnNetworkError)
    }

    func testRetryConfigNoRetry() {
        let config = GeminiRetryConfig.noRetry
        XCTAssertEqual(config.maxRetries, 0)
        XCTAssertEqual(config.baseDelay, 0)
    }

    func testRetryConfigAggressive() {
        let config = GeminiRetryConfig.aggressive
        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertTrue(config.retryableStatusCodes.contains(429))
        XCTAssertTrue(config.retryableStatusCodes.contains(503))
    }

    func testRetryDelayCalculation() {
        let config = GeminiRetryConfig(
            maxRetries: 5,
            baseDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0,
            jitterFactor: 0.0
        )

        // Without jitter, delay should be exact
        XCTAssertEqual(config.delay(forAttempt: 0), 1.0)
        XCTAssertEqual(config.delay(forAttempt: 1), 2.0)
        XCTAssertEqual(config.delay(forAttempt: 2), 4.0)
        XCTAssertEqual(config.delay(forAttempt: 3), 8.0)
        XCTAssertEqual(config.delay(forAttempt: 4), 16.0)
        // Should be capped at maxDelay
        XCTAssertEqual(config.delay(forAttempt: 5), 30.0)
    }

    func testRetryStatusCodeCheck() {
        let config = GeminiRetryConfig.default

        XCTAssertTrue(config.shouldRetry(statusCode: 429))
        XCTAssertTrue(config.shouldRetry(statusCode: 500))
        XCTAssertTrue(config.shouldRetry(statusCode: 503))
        XCTAssertFalse(config.shouldRetry(statusCode: 400))
        XCTAssertFalse(config.shouldRetry(statusCode: 401))
        XCTAssertFalse(config.shouldRetry(statusCode: 404))
    }

    // MARK: - Cache Configuration Tests

    func testCacheConfigDefault() {
        let config = GeminiCacheConfig.default
        XCTAssertEqual(config.maxEntries, 100)
        XCTAssertEqual(config.ttl, 300)
        XCTAssertTrue(config.isEnabled)
    }

    func testCacheConfigDisabled() {
        let config = GeminiCacheConfig.disabled
        XCTAssertEqual(config.maxEntries, 0)
        XCTAssertFalse(config.isEnabled)
    }

    func testCacheConfigLongLived() {
        let config = GeminiCacheConfig.longLived
        XCTAssertEqual(config.maxEntries, 500)
        XCTAssertEqual(config.ttl, 3600)
    }

    func testCacheKeyGeneration() {
        let contents = [Content(parts: [Part(text: "Hello")])]
        let key1 = CacheKeyGenerator.generateKey(
            model: "gemini-2.5-flash",
            contents: contents,
            systemInstruction: nil,
            generationConfig: nil,
            tools: nil
        )

        let key2 = CacheKeyGenerator.generateKey(
            model: "gemini-2.5-flash",
            contents: contents,
            systemInstruction: nil,
            generationConfig: nil,
            tools: nil
        )

        // Same inputs should produce same key
        XCTAssertEqual(key1, key2)

        // Different inputs should produce different keys
        let key3 = CacheKeyGenerator.generateKey(
            model: "gemini-2.5-pro",
            contents: contents,
            systemInstruction: nil,
            generationConfig: nil,
            tools: nil
        )
        XCTAssertNotEqual(key1, key3)
    }

    // MARK: - Token Estimation Tests

    func testTokenEstimation() {
        let text = "Hello, world!"
        let estimated = TokenEstimator.estimateTokens(for: text)

        // Rough estimate: ~4 chars per token
        XCTAssertGreaterThan(estimated, 0)
        XCTAssertLessThan(estimated, 10)
    }

    func testTokenLimits() {
        let flashLimits = ModelTokenLimits.limits(for: .gemini25Flash)
        XCTAssertEqual(flashLimits.inputLimit, 1_048_576)
        XCTAssertEqual(flashLimits.outputLimit, 65_536)

        let embeddingLimits = ModelTokenLimits.limits(for: .geminiEmbedding001)
        XCTAssertEqual(embeddingLimits.inputLimit, 2_048)
        XCTAssertEqual(embeddingLimits.outputLimit, 0)
    }

    func testIsWithinLimit() {
        XCTAssertTrue(TokenEstimator.isWithinLimit("Hello", limit: 100))
        XCTAssertFalse(TokenEstimator.isWithinLimit(String(repeating: "word ", count: 1000), limit: 10))
    }

    // MARK: - Request Tracing Tests

    func testRequestTraceIdGeneration() {
        let traceId1 = RequestTraceId()
        let traceId2 = RequestTraceId()

        XCTAssertNotEqual(traceId1.value, traceId2.value)
        XCTAssertEqual(traceId1.shortId.count, 8)
    }

    func testRequestContext() {
        let context = RequestContext(operation: "generateContent")

        XCTAssertEqual(context.operation, "generateContent")
        XCTAssertNotNil(context.traceId)
        XCTAssertNil(context.parentTraceId)
    }

    func testRequestContextChild() {
        let parent = RequestContext(operation: "parent")
        let child = parent.createChild(operation: "child")

        XCTAssertEqual(child.operation, "child")
        XCTAssertEqual(child.parentTraceId?.value, parent.traceId.value)
    }

    // MARK: - Function Declaration Tests

    func testFunctionDeclarationSimple() {
        let function = FunctionDeclaration.simple(
            name: "getWeather",
            description: "Get current weather"
        )

        XCTAssertEqual(function.name, "getWeather")
        XCTAssertEqual(function.description, "Get current weather")
        XCTAssertNil(function.parameters)
    }

    func testFunctionDeclarationWithParams() {
        let function = FunctionDeclaration.withStringParams(
            name: "search",
            description: "Search for items",
            params: [
                (name: "query", description: "Search query", required: true),
                (name: "limit", description: "Max results", required: false)
            ]
        )

        XCTAssertEqual(function.name, "search")
        XCTAssertNotNil(function.parameters)
        XCTAssertEqual(function.parameters?.properties.count, 2)
        XCTAssertEqual(function.parameters?.required, ["query"])
    }

    func testFunctionCallResult() {
        let result = FunctionCallResult(
            name: "test",
            arguments: [
                "string": "hello",
                "int": 42,
                "double": 3.14,
                "bool": true
            ]
        )

        XCTAssertEqual(result.stringArgument("string"), "hello")
        XCTAssertEqual(result.intArgument("int"), 42)
        XCTAssertEqual(result.doubleArgument("double"), 3.14)
        XCTAssertEqual(result.boolArgument("bool"), true)
    }

    // MARK: - Streaming Types Tests

    func testStreamingChunk() {
        let chunk = StreamingChunk(
            text: "Hello",
            isComplete: false,
            finishReason: nil,
            index: 0
        )

        XCTAssertEqual(chunk.text, "Hello")
        XCTAssertFalse(chunk.isComplete)
    }

    func testStreamingAccumulator() {
        var accumulator = StreamingAccumulator()

        accumulator.append(StreamingChunk(text: "Hello", isComplete: false, index: 0))
        accumulator.append(StreamingChunk(text: " World", isComplete: false, index: 1))
        accumulator.append(StreamingChunk(text: "!", isComplete: true, finishReason: .stop, index: 2))

        XCTAssertEqual(accumulator.fullText, "Hello World!")
        XCTAssertTrue(accumulator.isComplete)
        XCTAssertEqual(accumulator.finishReason, .stop)
        XCTAssertEqual(accumulator.chunks.count, 3)
    }

    // MARK: - Enhanced Config Tests

    func testEnhancedConfigDefault() {
        let config = GeminiClientEnhancedConfig.default

        XCTAssertEqual(config.retryConfig.maxRetries, 3)
        XCTAssertTrue(config.cacheConfig.isEnabled)
        XCTAssertFalse(config.tracingEnabled)
    }

    func testEnhancedConfigProduction() {
        let config = GeminiClientEnhancedConfig.production

        XCTAssertTrue(config.tracingEnabled)
        XCTAssertEqual(config.cacheConfig.ttl, 3600)
    }

    func testEnhancedConfigDevelopment() {
        let config = GeminiClientEnhancedConfig.development

        XCTAssertTrue(config.tracingEnabled)
        XCTAssertEqual(config.retryConfig.maxRetries, 0)
        XCTAssertFalse(config.cacheConfig.isEnabled)
    }

    // MARK: - Request Options Tests

    func testRequestOptionsDefault() {
        let options = GeminiRequestOptions.default

        XCTAssertFalse(options.skipCache)
        XCTAssertFalse(options.skipRetry)
        XCTAssertNil(options.customTimeout)
    }

    // MARK: - Base Uploader Tests

    func testUploadErrorDescriptions() {
        let errors: [GeminiUploadError] = [
            .invalidURL,
            .fileNotFound,
            .metadataExtractionFailed,
            .invalidUploadResponse,
            .sessionExpired,
            .processingTimeout
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testGeminiFileInfo() {
        let fileInfo = GeminiFileInfo(
            name: "files/abc123",
            displayName: "test.mp4",
            mimeType: "video/mp4",
            uri: "https://example.com/files/abc123",
            state: "ACTIVE"
        )

        XCTAssertEqual(fileInfo.fileId, "abc123")
        XCTAssertTrue(fileInfo.isActive)
    }

    func testGeminiUploadSession() {
        let session = GeminiUploadSession(
            apiKey: "test-key",
            mediaType: .video
        )

        XCTAssertFalse(session.sessionID.isEmpty)
        XCTAssertEqual(session.apiKey, "test-key")
        XCTAssertEqual(session.mediaType, .video)
        XCTAssertTrue(session.uploadedFiles.isEmpty)
    }

    func testChunkUploadConfig() {
        let defaultConfig = ChunkUploadConfig.default
        XCTAssertEqual(defaultConfig.chunkSize, 5 * 1024 * 1024)

        let largeConfig = ChunkUploadConfig.largeFile
        XCTAssertEqual(largeConfig.chunkSize, 10 * 1024 * 1024)
    }

    // MARK: - Cache Manager Tests

    func testCacheManagerOperations() async {
        let config = GeminiCacheConfig(
            maxEntries: 10,
            ttl: 60
        )
        let cacheManager = GeminiCacheManager(config: config)

        // Test set and get
        let testResponse = GeminiGenerateContentResponse(
            candidates: [
                Candidate(content: Content(parts: [Part(text: "cached response")]))
            ]
        )

        await cacheManager.set("test-key", value: testResponse)

        let retrieved: GeminiGenerateContentResponse? = await cacheManager.get("test-key")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.candidates.first?.content.parts.first?.text, "cached response")

        // Test statistics
        let stats = await cacheManager.statistics
        XCTAssertEqual(stats.entryCount, 1)
        XCTAssertEqual(stats.maxEntries, 10)
    }

    func testCacheManagerEviction() async {
        let config = GeminiCacheConfig(
            maxEntries: 2,
            ttl: 60
        )
        let cacheManager = GeminiCacheManager(config: config)

        let response1 = GeminiGenerateContentResponse(candidates: [])
        let response2 = GeminiGenerateContentResponse(candidates: [])
        let response3 = GeminiGenerateContentResponse(candidates: [])

        await cacheManager.set("key1", value: response1)
        await cacheManager.set("key2", value: response2)
        await cacheManager.set("key3", value: response3)

        let stats = await cacheManager.statistics
        XCTAssertEqual(stats.entryCount, 2)

        // First key should have been evicted
        let retrieved: GeminiGenerateContentResponse? = await cacheManager.get("key1")
        XCTAssertNil(retrieved)
    }

    // MARK: - SHA256 Hash Tests

    func testSHA256Hash() {
        let hash1 = "hello".sha256Hash
        let hash2 = "hello".sha256Hash
        let hash3 = "world".sha256Hash

        XCTAssertEqual(hash1, hash2)
        XCTAssertNotEqual(hash1, hash3)
        XCTAssertEqual(hash1.count, 64) // 32 bytes = 64 hex chars
    }
}
