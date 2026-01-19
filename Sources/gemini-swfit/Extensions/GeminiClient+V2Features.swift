import Foundation
import SwiftyBeaver

// MARK: - GeminiClient V2 Features Extension

extension GeminiClient {

    // MARK: - Thinking Mode

    /// Generate content with thinking mode enabled
    public func generateWithThinking(
        model: Model,
        text: String,
        thinkingConfig: ThinkingConfig = .dynamic,
        systemInstruction: String? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> ThinkingResponse {
        let generationConfig = ThinkingGenerationConfig(
            maxOutputTokens: 65536,
            temperature: 0.7,
            thinkingBudget: thinkingConfig.thinkingBudget,
            thinkingLevel: thinkingConfig.thinkingLevel
        )

        let request = ThinkingGenerateContentRequest(
            contents: [Content(parts: [Part(text: text)])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )

        let response = try await performThinkingRequest(model: model, request: request)

        // Parse thought summary if available
        let thoughtSummary = response.candidates.first.flatMap {
            ThoughtSummaryParser.parse(from: $0)
        }

        return ThinkingResponse(
            response: response,
            thoughtSummary: thoughtSummary,
            usedThinking: thinkingConfig.thinkingBudget != 0,
            thinkingTokensUsed: ThoughtSummaryParser.extractThinkingTokens(from: response)
        )
    }

    /// Perform a request with thinking configuration
    internal func performThinkingRequest(
        model: Model,
        request: ThinkingGenerateContentRequest
    ) async throws -> GeminiGenerateContentResponse {
        let currentApiKey = getNextApiKey()
        var components = URLComponents(
            url: baseURL.appendingPathComponent("models/\(model.rawValue):generateContent"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "key", value: currentApiKey)]
        let url = components.url!

        logger.info("Making thinking request to: \(url.absoluteString)")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw GeminiError.apiError(errorMessage, httpResponse.statusCode)
            }
            throw GeminiError.apiError("Unknown error", httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
    }

    // MARK: - Code Execution

    /// Generate content with code execution enabled
    public func generateWithCodeExecution(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> (response: GeminiGenerateContentResponse, codeBlocks: [ExecutedCodeBlock]) {
        // Build request with code execution tool
        let request = MultiToolRequestBuilder()
            .addCodeExecution()
            .prompt(text)
            .build()

        let response = try await performMultiToolRequest(model: model, request: request)
        let codeBlocks = CodeExecutionParser.extractExecutedCode(from: response)

        return (response, codeBlocks)
    }

    /// Generate content with multiple tools
    public func generateWithMultiTool(
        model: Model,
        request: MultiToolRequest
    ) async throws -> GeminiGenerateContentResponse {
        return try await performMultiToolRequest(model: model, request: request)
    }

    /// Perform a multi-tool request
    internal func performMultiToolRequest(
        model: Model,
        request: MultiToolRequest
    ) async throws -> GeminiGenerateContentResponse {
        let currentApiKey = getNextApiKey()
        var components = URLComponents(
            url: baseURL.appendingPathComponent("models/\(model.rawValue):generateContent"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "key", value: currentApiKey)]
        let url = components.url!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw GeminiError.apiError(errorMessage, httpResponse.statusCode)
            }
            throw GeminiError.apiError("Unknown error", httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
    }

    // MARK: - Grounding with Google Maps

    /// Generate content with Google Maps grounding
    public func generateWithGoogleMaps(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let request = MultiToolRequestBuilder()
            .addGoogleMaps()
            .prompt(text)
            .build()

        return try await performMultiToolRequest(model: model, request: request)
    }

    /// Generate content with Google Search and Maps
    public func generateWithSearchAndMaps(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let request = MultiToolRequestBuilder()
            .addGoogleSearch()
            .addGoogleMaps()
            .prompt(text)
            .build()

        return try await performMultiToolRequest(model: model, request: request)
    }

    // MARK: - Live Session

    /// Create a new Live API session
    public func createLiveSession(
        model: String = "gemini-2.5-flash-preview-native-audio-dialog",
        config: LiveAPIConfig = .voiceConversation
    ) -> LiveSession {
        let apiKey = getNextApiKey()
        return LiveSession(apiKey: apiKey, model: model, config: config, logger: logger)
    }

    // MARK: - Batch Processing

    /// Create a batch processor
    public func createBatchProcessor(config: BatchConfig = .default) -> BatchProcessor {
        let apiKey = getNextApiKey()
        return BatchProcessor(
            apiKey: apiKey,
            baseURL: baseURL.absoluteString,
            config: config,
            logger: logger
        )
    }

    /// Process a batch of text prompts
    public func processBatch(
        texts: [String],
        model: Model = .gemini25Flash
    ) async throws -> [BatchResponse] {
        let processor = createBatchProcessor()
        return try await processor.processTexts(texts, model: model.rawValue)
    }

    // MARK: - Model Selection Helpers

    /// Get the best model for a specific task
    public static func recommendModel(for task: TaskType) -> Model {
        switch task {
        case .simpleText:
            return .gemini25FlashLite
        case .complexReasoning:
            return .gemini25Pro
        case .codeGeneration:
            return .gemini25Flash
        case .imageAnalysis:
            return .gemini25Flash
        case .liveConversation:
            return .gemini25FlashPreviewNativeAudioDialog
        }
    }

    public enum TaskType {
        case simpleText
        case complexReasoning
        case codeGeneration
        case imageAnalysis
        case liveConversation
    }
}

// MARK: - Quick Builders

extension GeminiClient {

    /// Quick builder for thinking requests
    public func thinking(_ text: String, budget: Int = -1) async throws -> ThinkingResponse {
        let config = ThinkingConfig(thinkingBudget: budget)
        return try await generateWithThinking(
            model: .gemini25Flash,
            text: text,
            thinkingConfig: config
        )
    }

    /// Quick builder for code execution
    public func executeCode(_ prompt: String) async throws -> (response: GeminiGenerateContentResponse, codeBlocks: [ExecutedCodeBlock]) {
        return try await generateWithCodeExecution(
            model: .gemini25Flash,
            text: prompt
        )
    }

    /// Quick builder for multi-tool request
    public func multiTool() -> MultiToolRequestBuilder {
        return MultiToolRequestBuilder()
    }
}

// MARK: - Response Extensions

extension GeminiGenerateContentResponse {

    /// Check if response contains code execution results
    public var hasCodeExecution: Bool {
        return CodeExecutionParser.hasCodeExecution(in: self)
    }

    /// Extract code blocks from response
    public var codeBlocks: [ExecutedCodeBlock] {
        return CodeExecutionParser.extractExecutedCode(from: self)
    }

    /// Get the main text response
    public var text: String? {
        return candidates.first?.content.parts.compactMap { $0.text }.joined()
    }

    /// Get grounding sources if available
    public var groundingSources: [WebChunk]? {
        return candidates.first?.groundingMetadata?.groundingChunks?.compactMap { $0.web }
    }

    /// Get search queries used for grounding
    public var searchQueries: [String]? {
        return candidates.first?.groundingMetadata?.webSearchQueries
    }
}

// MARK: - Convenience Typealiases

public typealias GeminiThinkingConfig = ThinkingConfig
public typealias GeminiLiveConfig = LiveAPIConfig
public typealias GeminiBatchConfig = BatchConfig
