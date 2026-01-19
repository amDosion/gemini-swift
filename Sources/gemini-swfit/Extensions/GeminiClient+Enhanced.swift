import Foundation
import SwiftyBeaver

// MARK: - Enhanced Client Configuration

/// Configuration for enhanced GeminiClient features
public struct GeminiClientEnhancedConfig: Sendable {
    public let retryConfig: GeminiRetryConfig
    public let cacheConfig: GeminiCacheConfig
    public let tracingEnabled: Bool
    public let defaultTimeout: TimeInterval

    public static let `default` = GeminiClientEnhancedConfig(
        retryConfig: .default,
        cacheConfig: .default,
        tracingEnabled: false,
        defaultTimeout: 60.0
    )

    public static let production = GeminiClientEnhancedConfig(
        retryConfig: .default,
        cacheConfig: .longLived,
        tracingEnabled: true,
        defaultTimeout: 120.0
    )

    public static let development = GeminiClientEnhancedConfig(
        retryConfig: .noRetry,
        cacheConfig: .disabled,
        tracingEnabled: true,
        defaultTimeout: 30.0
    )

    public init(
        retryConfig: GeminiRetryConfig = .default,
        cacheConfig: GeminiCacheConfig = .default,
        tracingEnabled: Bool = false,
        defaultTimeout: TimeInterval = 60.0
    ) {
        self.retryConfig = retryConfig
        self.cacheConfig = cacheConfig
        self.tracingEnabled = tracingEnabled
        self.defaultTimeout = defaultTimeout
    }
}

// MARK: - Enhanced Request Options

/// Options for individual requests
public struct GeminiRequestOptions: Sendable {
    public let skipCache: Bool
    public let skipRetry: Bool
    public let customTimeout: TimeInterval?
    public let traceMetadata: [String: String]

    public static let `default` = GeminiRequestOptions(
        skipCache: false,
        skipRetry: false,
        customTimeout: nil,
        traceMetadata: [:]
    )

    public init(
        skipCache: Bool = false,
        skipRetry: Bool = false,
        customTimeout: TimeInterval? = nil,
        traceMetadata: [String: String] = [:]
    ) {
        self.skipCache = skipCache
        self.skipRetry = skipRetry
        self.customTimeout = customTimeout
        self.traceMetadata = traceMetadata
    }
}

// MARK: - Enhanced Response

/// Enhanced response with additional metadata
public struct GeminiEnhancedResponse: Sendable {
    public let response: GeminiGenerateContentResponse
    public let metadata: ResponseMetadata

    public struct ResponseMetadata: Sendable {
        public let traceId: String?
        public let fromCache: Bool
        public let retryCount: Int
        public let duration: TimeInterval
        public let tokenCount: Int?

        public init(
            traceId: String? = nil,
            fromCache: Bool = false,
            retryCount: Int = 0,
            duration: TimeInterval = 0,
            tokenCount: Int? = nil
        ) {
            self.traceId = traceId
            self.fromCache = fromCache
            self.retryCount = retryCount
            self.duration = duration
            self.tokenCount = tokenCount
        }
    }

    /// Convenience accessor for text response
    public var text: String? {
        return response.candidates.first?.content.parts.compactMap { $0.text }.joined()
    }
}

// MARK: - GeminiClient Enhanced Extension

extension GeminiClient {

    // MARK: - Enhanced Generation Methods

    /// Generate content with enhanced features (retry, caching, tracing)
    public func generateContentEnhanced(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        config: GeminiClientEnhancedConfig = .default,
        options: GeminiRequestOptions = .default
    ) async throws -> GeminiEnhancedResponse {
        let startTime = Date()
        var retryCount = 0
        var traceId: String?

        // Create trace context if tracing is enabled
        if config.tracingEnabled {
            traceId = RequestTraceId().value
        }

        // Build cache key
        let contents = [Content(parts: [Part(text: text)])]
        let cacheKey = CacheKeyGenerator.generateKey(
            model: model.rawValue,
            contents: contents,
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            tools: nil
        )

        // Check cache if enabled
        if config.cacheConfig.isEnabled && !options.skipCache {
            let cacheManager = GeminiCacheManager(config: config.cacheConfig)
            if let cachedResponse: GeminiGenerateContentResponse = await cacheManager.get(cacheKey) {
                let duration = Date().timeIntervalSince(startTime)
                logger.debug("Cache hit for request")
                return GeminiEnhancedResponse(
                    response: cachedResponse,
                    metadata: .init(
                        traceId: traceId,
                        fromCache: true,
                        retryCount: 0,
                        duration: duration
                    )
                )
            }
        }

        // Perform request with retry
        let response: GeminiGenerateContentResponse

        if config.retryConfig.maxRetries > 0 && !options.skipRetry {
            let retryExecutor = RetryExecutor(config: config.retryConfig)

            let result = await retryExecutor.executeWithResult { [self] in
                return try await self.generateContent(
                    model: model,
                    text: text,
                    systemInstruction: systemInstruction,
                    generationConfig: generationConfig,
                    safetySettings: safetySettings
                )
            }

            retryCount = result.attemptCount - 1

            switch result {
            case .success(let r, _):
                response = r
            case .failure(let error, _):
                throw error
            }
        } else {
            response = try await generateContent(
                model: model,
                text: text,
                systemInstruction: systemInstruction,
                generationConfig: generationConfig,
                safetySettings: safetySettings
            )
        }

        // Store in cache if enabled
        if config.cacheConfig.isEnabled && !options.skipCache {
            let cacheManager = GeminiCacheManager(config: config.cacheConfig)
            await cacheManager.set(cacheKey, value: response)
        }

        let duration = Date().timeIntervalSince(startTime)

        return GeminiEnhancedResponse(
            response: response,
            metadata: .init(
                traceId: traceId,
                fromCache: false,
                retryCount: retryCount,
                duration: duration
            )
        )
    }

    /// Generate content with Google Search and enhanced features
    public func generateContentWithGoogleSearchEnhanced(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        config: GeminiClientEnhancedConfig = .default,
        options: GeminiRequestOptions = .default
    ) async throws -> GeminiEnhancedResponse {
        let startTime = Date()
        var retryCount = 0
        var traceId: String?

        if config.tracingEnabled {
            traceId = RequestTraceId().value
        }

        let response: GeminiGenerateContentResponse

        if config.retryConfig.maxRetries > 0 && !options.skipRetry {
            let retryExecutor = RetryExecutor(config: config.retryConfig)

            let result = await retryExecutor.executeWithResult { [self] in
                return try await self.generateContentWithGoogleSearch(
                    model: model,
                    text: text,
                    systemInstruction: systemInstruction,
                    generationConfig: generationConfig,
                    safetySettings: safetySettings
                )
            }

            retryCount = result.attemptCount - 1

            switch result {
            case .success(let r, _):
                response = r
            case .failure(let error, _):
                throw error
            }
        } else {
            response = try await generateContentWithGoogleSearch(
                model: model,
                text: text,
                systemInstruction: systemInstruction,
                generationConfig: generationConfig,
                safetySettings: safetySettings
            )
        }

        let duration = Date().timeIntervalSince(startTime)

        return GeminiEnhancedResponse(
            response: response,
            metadata: .init(
                traceId: traceId,
                fromCache: false,
                retryCount: retryCount,
                duration: duration
            )
        )
    }

    // MARK: - Batch Operations

    /// Execute multiple requests in parallel with enhanced features
    public func batchGenerateContent(
        requests: [(model: Model, text: String, systemInstruction: String?)],
        generationConfig: GenerationConfig? = nil,
        config: GeminiClientEnhancedConfig = .default,
        maxConcurrency: Int = 5
    ) async throws -> [Result<GeminiEnhancedResponse, Error>] {
        let semaphore = AsyncSemaphore(limit: maxConcurrency)

        return await withTaskGroup(of: (Int, Result<GeminiEnhancedResponse, Error>).self) { group in
            for (index, request) in requests.enumerated() {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    do {
                        let response = try await self.generateContentEnhanced(
                            model: request.model,
                            text: request.text,
                            systemInstruction: request.systemInstruction,
                            generationConfig: generationConfig,
                            config: config
                        )
                        return (index, .success(response))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            var results: [(Int, Result<GeminiEnhancedResponse, Error>)] = []
            for await result in group {
                results.append(result)
            }

            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Conversation with Enhanced Features

    /// Send a message in a conversation with enhanced features
    public func sendMessageEnhanced(
        model: Model,
        message: String,
        history: [Content] = [],
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        config: GeminiClientEnhancedConfig = .default
    ) async throws -> GeminiEnhancedResponse {
        let startTime = Date()
        var retryCount = 0
        var traceId: String?

        if config.tracingEnabled {
            traceId = RequestTraceId().value
        }

        let response: GeminiGenerateContentResponse

        if config.retryConfig.maxRetries > 0 {
            let retryExecutor = RetryExecutor(config: config.retryConfig)

            let result = await retryExecutor.executeWithResult { [self] in
                return try await self.sendMessage(
                    model: model,
                    message: message,
                    history: history,
                    systemInstruction: systemInstruction,
                    generationConfig: generationConfig,
                    safetySettings: safetySettings
                )
            }

            retryCount = result.attemptCount - 1

            switch result {
            case .success(let r, _):
                response = r
            case .failure(let error, _):
                throw error
            }
        } else {
            response = try await sendMessage(
                model: model,
                message: message,
                history: history,
                systemInstruction: systemInstruction,
                generationConfig: generationConfig,
                safetySettings: safetySettings
            )
        }

        let duration = Date().timeIntervalSince(startTime)

        return GeminiEnhancedResponse(
            response: response,
            metadata: .init(
                traceId: traceId,
                fromCache: false,
                retryCount: retryCount,
                duration: duration
            )
        )
    }
}

// MARK: - Async Semaphore

/// Simple async semaphore for limiting concurrency
actor AsyncSemaphore {
    private let limit: Int
    private var count: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
    }

    func wait() async {
        if count < limit {
            count += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else if count > 0 {
            count -= 1
        }
    }
}

// MARK: - Response Helpers

extension GeminiEnhancedResponse {
    /// Get grounding metadata if available
    public var groundingMetadata: GroundingMetadata? {
        return response.candidates.first?.groundingMetadata
    }

    /// Get all citations if available
    public var citations: [CitationSource]? {
        return response.candidates.first?.citationMetadata?.citationSources
    }

    /// Check if response was blocked for safety
    public var wasBlocked: Bool {
        return response.candidates.first?.finishReason == .safety
    }

    /// Get finish reason
    public var finishReason: FinishReason? {
        return response.candidates.first?.finishReason
    }
}

// MARK: - Request Builder

/// Fluent builder for creating requests
public class GeminiRequestBuilder {
    private var model: GeminiClient.Model = .gemini25Flash
    private var text: String = ""
    private var systemInstruction: String?
    private var generationConfig: GenerationConfig?
    private var safetySettings: [SafetySetting]?
    private var tools: [Tool]?
    private var options: GeminiRequestOptions = .default
    private var config: GeminiClientEnhancedConfig = .default

    public init() {}

    @discardableResult
    public func model(_ model: GeminiClient.Model) -> Self {
        self.model = model
        return self
    }

    @discardableResult
    public func prompt(_ text: String) -> Self {
        self.text = text
        return self
    }

    @discardableResult
    public func systemInstruction(_ instruction: String) -> Self {
        self.systemInstruction = instruction
        return self
    }

    @discardableResult
    public func temperature(_ temp: Double) -> Self {
        self.generationConfig = GenerationConfig(
            candidateCount: generationConfig?.candidateCount,
            stopSequences: generationConfig?.stopSequences,
            maxOutputTokens: generationConfig?.maxOutputTokens,
            temperature: temp,
            topP: generationConfig?.topP,
            topK: generationConfig?.topK
        )
        return self
    }

    @discardableResult
    public func maxTokens(_ tokens: Int) -> Self {
        self.generationConfig = GenerationConfig(
            candidateCount: generationConfig?.candidateCount,
            stopSequences: generationConfig?.stopSequences,
            maxOutputTokens: tokens,
            temperature: generationConfig?.temperature,
            topP: generationConfig?.topP,
            topK: generationConfig?.topK
        )
        return self
    }

    @discardableResult
    public func withGoogleSearch() -> Self {
        self.tools = (self.tools ?? []) + [Tool.googleSearch()]
        return self
    }

    @discardableResult
    public func withUrlContext() -> Self {
        self.tools = (self.tools ?? []) + [Tool.urlContext()]
        return self
    }

    @discardableResult
    public func withRetry(_ config: GeminiRetryConfig) -> Self {
        self.config = GeminiClientEnhancedConfig(
            retryConfig: config,
            cacheConfig: self.config.cacheConfig,
            tracingEnabled: self.config.tracingEnabled,
            defaultTimeout: self.config.defaultTimeout
        )
        return self
    }

    @discardableResult
    public func withCaching(_ config: GeminiCacheConfig) -> Self {
        self.config = GeminiClientEnhancedConfig(
            retryConfig: self.config.retryConfig,
            cacheConfig: config,
            tracingEnabled: self.config.tracingEnabled,
            defaultTimeout: self.config.defaultTimeout
        )
        return self
    }

    @discardableResult
    public func skipCache() -> Self {
        self.options = GeminiRequestOptions(
            skipCache: true,
            skipRetry: options.skipRetry,
            customTimeout: options.customTimeout,
            traceMetadata: options.traceMetadata
        )
        return self
    }

    @discardableResult
    public func skipRetry() -> Self {
        self.options = GeminiRequestOptions(
            skipCache: options.skipCache,
            skipRetry: true,
            customTimeout: options.customTimeout,
            traceMetadata: options.traceMetadata
        )
        return self
    }

    @discardableResult
    public func timeout(_ seconds: TimeInterval) -> Self {
        self.options = GeminiRequestOptions(
            skipCache: options.skipCache,
            skipRetry: options.skipRetry,
            customTimeout: seconds,
            traceMetadata: options.traceMetadata
        )
        return self
    }

    /// Execute the built request
    public func execute(with client: GeminiClient) async throws -> GeminiEnhancedResponse {
        return try await client.generateContentEnhanced(
            model: model,
            text: text,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings,
            config: config,
            options: options
        )
    }
}

// MARK: - Convenience Extensions

extension GeminiClient {
    /// Create a request builder
    public func request() -> GeminiRequestBuilder {
        return GeminiRequestBuilder()
    }

    /// Quick text generation
    public func generate(
        _ text: String,
        model: Model = .gemini25Flash
    ) async throws -> String {
        let response = try await generateContent(model: model, text: text)
        return response.candidates.first?.content.parts.compactMap { $0.text }.joined() ?? ""
    }

    /// Quick text generation with system instruction
    public func generate(
        _ text: String,
        system: String,
        model: Model = .gemini25Flash
    ) async throws -> String {
        let response = try await generateContent(
            model: model,
            text: text,
            systemInstruction: system
        )
        return response.candidates.first?.content.parts.compactMap { $0.text }.joined() ?? ""
    }
}
