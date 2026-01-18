import Foundation

// MARK: - Token Count Response

/// Response from token counting API
public struct TokenCountResponse: Codable, Sendable {
    public let totalTokens: Int

    public init(totalTokens: Int) {
        self.totalTokens = totalTokens
    }
}

/// Detailed token count with breakdown
public struct DetailedTokenCount: Sendable {
    public let totalTokens: Int
    public let promptTokens: Int
    public let cachedContentTokenCount: Int?

    public init(
        totalTokens: Int,
        promptTokens: Int,
        cachedContentTokenCount: Int? = nil
    ) {
        self.totalTokens = totalTokens
        self.promptTokens = promptTokens
        self.cachedContentTokenCount = cachedContentTokenCount
    }
}

// MARK: - Token Estimation

/// Utility for estimating token counts without API calls
public struct TokenEstimator {
    /// Average characters per token (approximation for English text)
    public static let averageCharsPerToken: Double = 4.0

    /// Estimate token count for text
    public static func estimateTokens(for text: String) -> Int {
        // Basic estimation: ~4 characters per token for English
        // This is a rough approximation; actual counts vary by language and content
        let charCount = text.count
        return Int(ceil(Double(charCount) / averageCharsPerToken))
    }

    /// Estimate token count for multiple texts
    public static func estimateTokens(for texts: [String]) -> Int {
        return texts.reduce(0) { $0 + estimateTokens(for: $1) }
    }

    /// Estimate token count for content array
    public static func estimateTokens(for contents: [Content]) -> Int {
        var total = 0

        for content in contents {
            // Role token overhead
            if content.role != nil {
                total += 1
            }

            for part in content.parts {
                if let text = part.text {
                    total += estimateTokens(for: text)
                }

                // Inline data (images, etc.) have significant token overhead
                if let inlineData = part.inlineData {
                    // Estimate based on data size
                    // Images typically use ~85 tokens per 512x512 tile
                    let dataSize = inlineData.data.count
                    let estimatedTiles = max(1, dataSize / (512 * 512))
                    total += estimatedTiles * 85
                }

                // File data has minimal token overhead
                if part.fileData != nil {
                    total += 10
                }
            }
        }

        return total
    }

    /// Check if content is likely within token limit
    public static func isWithinLimit(_ text: String, limit: Int) -> Bool {
        return estimateTokens(for: text) <= limit
    }

    /// Get estimated cost based on token count and pricing
    public static func estimateCost(
        inputTokens: Int,
        outputTokens: Int,
        inputPricePerMillion: Double,
        outputPricePerMillion: Double
    ) -> Double {
        let inputCost = Double(inputTokens) * inputPricePerMillion / 1_000_000
        let outputCost = Double(outputTokens) * outputPricePerMillion / 1_000_000
        return inputCost + outputCost
    }
}

// MARK: - Token Limits

/// Token limits for different models
public struct ModelTokenLimits: Sendable {
    public let inputLimit: Int
    public let outputLimit: Int
    public let contextWindow: Int

    public init(inputLimit: Int, outputLimit: Int, contextWindow: Int) {
        self.inputLimit = inputLimit
        self.outputLimit = outputLimit
        self.contextWindow = contextWindow
    }

    /// Get token limits for a model
    public static func limits(for model: GeminiClient.Model) -> ModelTokenLimits {
        switch model {
        case .gemini25Pro:
            return ModelTokenLimits(
                inputLimit: 1_048_576,  // 1M tokens
                outputLimit: 65_536,     // 64K tokens
                contextWindow: 1_048_576
            )
        case .gemini25Flash, .gemini25FlashLite:
            return ModelTokenLimits(
                inputLimit: 1_048_576,
                outputLimit: 65_536,
                contextWindow: 1_048_576
            )
        case .geminiLive25FlashPreview,
             .gemini25FlashPreviewNativeAudioDialog,
             .gemini25FlashExpNativeAudioThinkingDialog,
             .gemini25FlashImagePreview:
            return ModelTokenLimits(
                inputLimit: 128_000,
                outputLimit: 8_192,
                contextWindow: 128_000
            )
        case .geminiEmbedding001:
            return ModelTokenLimits(
                inputLimit: 2_048,
                outputLimit: 0,  // No text output for embeddings
                contextWindow: 2_048
            )
        }
    }
}

// MARK: - GeminiClient Token Counting Extension

extension GeminiClient {

    /// Count tokens for a text prompt
    /// - Parameters:
    ///   - model: The model to use for counting
    ///   - text: The text to count tokens for
    /// - Returns: Token count response
    public func countTokens(
        model: Model,
        text: String
    ) async throws -> TokenCountResponse {
        let contents = [Content(parts: [Part(text: text)])]
        return try await countTokens(model: model, contents: contents)
    }

    /// Count tokens for content array
    /// - Parameters:
    ///   - model: The model to use for counting
    ///   - contents: The content array to count tokens for
    /// - Returns: Token count response
    public func countTokens(
        model: Model,
        contents: [Content]
    ) async throws -> TokenCountResponse {
        let currentApiKey = getNextApiKey()

        var components = URLComponents(
            url: baseURL.appendingPathComponent("models/\(model.rawValue):countTokens"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "key", value: currentApiKey)]

        guard let url = components.url else {
            throw GeminiError.invalidURL
        }

        let requestBody: [String: Any] = [
            "contents": contents.map { content -> [String: Any] in
                var result: [String: Any] = [:]
                if let role = content.role {
                    result["role"] = role.rawValue
                }
                result["parts"] = content.parts.map { part -> [String: Any] in
                    var partDict: [String: Any] = [:]
                    if let text = part.text {
                        partDict["text"] = text
                    }
                    if let inlineData = part.inlineData {
                        partDict["inlineData"] = [
                            "mimeType": inlineData.mimeType,
                            "data": inlineData.data
                        ]
                    }
                    return partDict
                }
                return result
            }
        ]

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        logger.info("Counting tokens for model: \(model.rawValue)")

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw GeminiError.apiError("Token counting failed", httpResponse.statusCode)
            }

            return try JSONDecoder().decode(TokenCountResponse.self, from: data)
        } catch let error as GeminiError {
            throw error
        } catch {
            logger.error("Token counting failed: \(error.localizedDescription)")
            throw GeminiError.requestFailed(error)
        }
    }

    /// Count tokens for a complete request
    public func countTokens(
        model: Model,
        request: GeminiGenerateContentRequest
    ) async throws -> TokenCountResponse {
        var contents = request.contents

        // Include system instruction in token count
        if let systemInstruction = request.systemInstruction {
            let systemContent = Content(role: .user, parts: systemInstruction.parts)
            contents.insert(systemContent, at: 0)
        }

        return try await countTokens(model: model, contents: contents)
    }

    /// Estimate tokens locally without API call
    public func estimateTokens(for text: String) -> Int {
        return TokenEstimator.estimateTokens(for: text)
    }

    /// Estimate tokens for content array locally
    public func estimateTokens(for contents: [Content]) -> Int {
        return TokenEstimator.estimateTokens(for: contents)
    }

    /// Get token limits for a model
    public func tokenLimits(for model: Model) -> ModelTokenLimits {
        return ModelTokenLimits.limits(for: model)
    }

    /// Check if content fits within model limits
    public func contentFitsModel(
        _ contents: [Content],
        model: Model,
        reserveOutputTokens: Int = 8192
    ) async throws -> Bool {
        let tokenCount = try await countTokens(model: model, contents: contents)
        let limits = tokenLimits(for: model)

        return tokenCount.totalTokens <= (limits.inputLimit - reserveOutputTokens)
    }

    /// Truncate text to fit within token limit
    public func truncateToFit(
        _ text: String,
        model: Model,
        maxTokens: Int? = nil
    ) async throws -> String {
        let limits = tokenLimits(for: model)
        let targetLimit = maxTokens ?? limits.inputLimit

        // First check if truncation is needed
        let currentCount = try await countTokens(model: model, text: text)
        if currentCount.totalTokens <= targetLimit {
            return text
        }

        // Binary search for optimal truncation point
        var low = 0
        var high = text.count
        var bestLength = 0

        while low <= high {
            let mid = (low + high) / 2
            let truncated = String(text.prefix(mid))

            // Use estimation for efficiency during search
            let estimated = estimateTokens(for: truncated)

            if estimated <= targetLimit {
                bestLength = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return String(text.prefix(bestLength))
    }
}

// MARK: - Token Usage Tracking

/// Tracks token usage across requests
public actor TokenUsageTracker {
    private var totalInputTokens: Int = 0
    private var totalOutputTokens: Int = 0
    private var requestCount: Int = 0

    public init() {}

    public func recordUsage(inputTokens: Int, outputTokens: Int) {
        totalInputTokens += inputTokens
        totalOutputTokens += outputTokens
        requestCount += 1
    }

    public var usage: TokenUsage {
        return TokenUsage(
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalTokens: totalInputTokens + totalOutputTokens,
            requestCount: requestCount
        )
    }

    public func reset() {
        totalInputTokens = 0
        totalOutputTokens = 0
        requestCount = 0
    }
}

/// Token usage statistics
public struct TokenUsage: Sendable {
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let totalTokens: Int
    public let requestCount: Int

    public var averageInputTokensPerRequest: Double {
        guard requestCount > 0 else { return 0 }
        return Double(totalInputTokens) / Double(requestCount)
    }

    public var averageOutputTokensPerRequest: Double {
        guard requestCount > 0 else { return 0 }
        return Double(totalOutputTokens) / Double(requestCount)
    }
}
