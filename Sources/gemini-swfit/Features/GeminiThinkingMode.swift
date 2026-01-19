import Foundation

// MARK: - Thinking Configuration

/// Configuration for Gemini's thinking/reasoning mode
public struct ThinkingConfig: Codable, Sendable {
    /// The thinking budget in tokens
    /// - Set to 0 to disable thinking
    /// - Set to -1 for dynamic thinking (model adjusts based on complexity)
    /// - Set to a positive value for a specific token budget
    public let thinkingBudget: Int?

    /// Whether to include thought summaries in the response
    public let includeThoughts: Bool

    /// Thinking level for Gemini 3 models (low, medium, high)
    public let thinkingLevel: ThinkingLevel?

    public init(
        thinkingBudget: Int? = nil,
        includeThoughts: Bool = true,
        thinkingLevel: ThinkingLevel? = nil
    ) {
        self.thinkingBudget = thinkingBudget
        self.includeThoughts = includeThoughts
        self.thinkingLevel = thinkingLevel
    }

    // MARK: - Preset Configurations

    /// Disable thinking entirely
    public static let disabled = ThinkingConfig(thinkingBudget: 0, includeThoughts: false)

    /// Dynamic thinking - model decides based on complexity
    public static let dynamic = ThinkingConfig(thinkingBudget: -1, includeThoughts: true)

    /// Light thinking for simple tasks
    public static let light = ThinkingConfig(thinkingBudget: 1024, includeThoughts: true)

    /// Standard thinking for most tasks
    public static let standard = ThinkingConfig(thinkingBudget: 4096, includeThoughts: true)

    /// Deep thinking for complex reasoning
    public static let deep = ThinkingConfig(thinkingBudget: 16384, includeThoughts: true)

    /// Maximum thinking for highly complex problems
    public static let maximum = ThinkingConfig(thinkingBudget: 32768, includeThoughts: true)
}

/// Thinking level for Gemini 3 models
public enum ThinkingLevel: String, Codable, Sendable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

// MARK: - Thought Summary

/// Parsed thought summary from model response
public struct ThoughtSummary: Sendable {
    /// The raw thinking content
    public let rawThoughts: String?

    /// Summarized headers/sections
    public let headers: [String]

    /// Key reasoning steps
    public let reasoningSteps: [ReasoningStep]

    /// Tool calls made during thinking
    public let toolCalls: [ThinkingToolCall]

    /// Duration of thinking in tokens
    public let thinkingTokens: Int?

    public init(
        rawThoughts: String? = nil,
        headers: [String] = [],
        reasoningSteps: [ReasoningStep] = [],
        toolCalls: [ThinkingToolCall] = [],
        thinkingTokens: Int? = nil
    ) {
        self.rawThoughts = rawThoughts
        self.headers = headers
        self.reasoningSteps = reasoningSteps
        self.toolCalls = toolCalls
        self.thinkingTokens = thinkingTokens
    }
}

/// A single reasoning step in the thinking process
public struct ReasoningStep: Sendable {
    public let index: Int
    public let description: String
    public let conclusion: String?

    public init(index: Int, description: String, conclusion: String? = nil) {
        self.index = index
        self.description = description
        self.conclusion = conclusion
    }
}

/// A tool call made during the thinking process
public struct ThinkingToolCall: Sendable {
    public let toolName: String
    public let arguments: [String: Any]
    public let result: String?

    public init(toolName: String, arguments: [String: Any], result: String? = nil) {
        self.toolName = toolName
        self.arguments = arguments
        self.result = result
    }
}

// MARK: - Thinking Response

/// Extended response that includes thinking information
public struct ThinkingResponse: Sendable {
    /// The main response content
    public let response: GeminiGenerateContentResponse

    /// The thought summary (if thinking was enabled)
    public let thoughtSummary: ThoughtSummary?

    /// Whether thinking was used
    public let usedThinking: Bool

    /// Thinking token usage
    public let thinkingTokensUsed: Int?

    public init(
        response: GeminiGenerateContentResponse,
        thoughtSummary: ThoughtSummary? = nil,
        usedThinking: Bool = false,
        thinkingTokensUsed: Int? = nil
    ) {
        self.response = response
        self.thoughtSummary = thoughtSummary
        self.usedThinking = usedThinking
        self.thinkingTokensUsed = thinkingTokensUsed
    }

    /// Get the main text response
    public var text: String? {
        return response.candidates.first?.content.parts.compactMap { $0.text }.joined()
    }
}

// MARK: - Thought Summary Parser

/// Parser for extracting thought summaries from responses
public struct ThoughtSummaryParser {

    /// Parse thought summary from a candidate response
    public static func parse(from candidate: Candidate) -> ThoughtSummary? {
        // Check if there's thinking content in the response
        guard let content = candidate.content.parts.first,
              let text = content.text else {
            return nil
        }

        // Look for thinking markers in the response
        let thinkingPattern = #"<thinking>(.*?)</thinking>"#
        let thoughtPattern = #"<thought>(.*?)</thought>"#

        var rawThoughts: String?
        var headers: [String] = []
        var steps: [ReasoningStep] = []

        // Try to extract thinking block
        if let thinkingRange = text.range(of: thinkingPattern, options: .regularExpression) {
            rawThoughts = String(text[thinkingRange])
        }

        // Extract headers (lines starting with ##)
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("## ") || line.hasPrefix("### ") {
                headers.append(line.trimmingCharacters(in: .whitespaces))
            }
        }

        // Extract numbered steps
        let stepPattern = #"(\d+)\.\s+(.+)"#
        if let regex = try? NSRegularExpression(pattern: stepPattern) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

            for match in matches {
                if match.numberOfRanges >= 3,
                   let indexRange = Range(match.range(at: 1), in: text),
                   let descRange = Range(match.range(at: 2), in: text),
                   let index = Int(text[indexRange]) {
                    steps.append(ReasoningStep(
                        index: index,
                        description: String(text[descRange])
                    ))
                }
            }
        }

        // Return nil if no thinking content found
        if rawThoughts == nil && headers.isEmpty && steps.isEmpty {
            return nil
        }

        return ThoughtSummary(
            rawThoughts: rawThoughts,
            headers: headers,
            reasoningSteps: steps
        )
    }

    /// Extract thinking tokens from usage metadata
    public static func extractThinkingTokens(from response: GeminiGenerateContentResponse) -> Int? {
        // This would be extracted from the response metadata if available
        // The actual implementation depends on how Google returns this data
        return nil
    }
}

// MARK: - Generation Config Extension

extension GenerationConfig {
    /// Create a generation config with thinking enabled
    public static func withThinking(
        budget: Int = -1,
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil,
        topP: Double? = nil,
        topK: Int? = nil
    ) -> GenerationConfig {
        return GenerationConfig(
            candidateCount: 1,
            maxOutputTokens: maxOutputTokens,
            temperature: temperature,
            topP: topP,
            topK: topK,
            responseSchema: ["thinkingBudget": budget] as [String: Any]
        )
    }
}

// MARK: - Extended Generation Config for Thinking

/// Extended generation config that supports thinking mode
public struct ThinkingGenerationConfig: Codable, Sendable {
    public let candidateCount: Int?
    public let stopSequences: [String]?
    public let maxOutputTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let responseMimeType: String?
    public let responseSchema: String?
    public let thinkingConfig: ThinkingConfigPayload?

    public struct ThinkingConfigPayload: Codable, Sendable {
        public let thinkingBudget: Int?
        public let thinkingLevel: String?

        public init(thinkingBudget: Int? = nil, thinkingLevel: String? = nil) {
            self.thinkingBudget = thinkingBudget
            self.thinkingLevel = thinkingLevel
        }
    }

    public init(
        candidateCount: Int? = 1,
        stopSequences: [String]? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        responseMimeType: String? = nil,
        responseSchema: String? = nil,
        thinkingBudget: Int? = nil,
        thinkingLevel: ThinkingLevel? = nil
    ) {
        self.candidateCount = candidateCount
        self.stopSequences = stopSequences
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.responseMimeType = responseMimeType
        self.responseSchema = responseSchema

        if thinkingBudget != nil || thinkingLevel != nil {
            self.thinkingConfig = ThinkingConfigPayload(
                thinkingBudget: thinkingBudget,
                thinkingLevel: thinkingLevel?.rawValue
            )
        } else {
            self.thinkingConfig = nil
        }
    }
}

// MARK: - Thinking Request

/// Request structure that supports thinking mode
public struct ThinkingGenerateContentRequest: Codable, Sendable {
    public let contents: [Content]
    public let systemInstruction: SystemInstruction?
    public let generationConfig: ThinkingGenerationConfig?
    public let safetySettings: [SafetySetting]?
    public let tools: [Tool]?

    public init(
        contents: [Content],
        systemInstruction: SystemInstruction? = nil,
        generationConfig: ThinkingGenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        tools: [Tool]? = nil
    ) {
        self.contents = contents
        self.systemInstruction = systemInstruction
        self.generationConfig = generationConfig
        self.safetySettings = safetySettings
        self.tools = tools
    }
}
