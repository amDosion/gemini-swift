//
//  LLMAgent.swift
//  gemini-swfit
//
//  Base LLM-powered agent using Gemini API
//

import Foundation
import SwiftyBeaver

/// Base LLM Agent that uses Gemini for reasoning
public final class GeminiLLMAgent: LLMBasedAgent, @unchecked Sendable {

    // MARK: - Properties

    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]
    public let model: String
    public let systemInstruction: String
    public let temperature: Double

    private let client: GeminiClient
    private let logger: SwiftyBeaver.Type
    private let tools: [any AgentTool]

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        capabilities: [AgentCapability] = [.textGeneration, .reasoning],
        model: String = "gemini-2.5-flash",
        systemInstruction: String = "",
        temperature: Double = 0.7,
        client: GeminiClient,
        tools: [any AgentTool] = [],
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.capabilities = capabilities
        self.model = model
        self.systemInstruction = systemInstruction
        self.temperature = temperature
        self.client = client
        self.tools = tools
        self.logger = logger
    }

    // MARK: - Agent Protocol

    public func canHandle(input: AgentInput) -> Bool {
        return true // LLM agents can handle most text inputs
    }

    public func process(input: AgentInput) async throws -> AgentOutput {
        let startTime = Date()
        logger.info("[\(name)] Processing input: \(input.id)")

        // Build prompt with context
        let prompt = buildPrompt(from: input)

        // Generate response
        let response = try await generate(prompt: prompt, context: input)

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("[\(name)] Completed in \(processingTime)s")

        return AgentOutput(
            agentId: id,
            content: response,
            confidence: calculateConfidence(response),
            processingTime: processingTime
        )
    }

    // MARK: - LLMBasedAgent Protocol

    public func generate(prompt: String, context: AgentInput) async throws -> String {
        // Build generation config
        let config = GeminiClient.GenerationConfig(
            temperature: temperature,
            maxOutputTokens: 4096
        )

        // Generate content
        let geminiModel = mapToGeminiModel(model)
        let response = try await client.generateContent(
            model: geminiModel,
            prompt: prompt,
            systemInstruction: systemInstruction.isEmpty ? nil : systemInstruction,
            generationConfig: config
        )

        guard let text = response.text else {
            throw AgentError.processingFailed("No text in response")
        }

        return text
    }

    // MARK: - Private Methods

    private func buildPrompt(from input: AgentInput) -> String {
        var promptParts: [String] = []

        // Add previous outputs context
        if !input.previousOutputs.isEmpty {
            promptParts.append("## Previous Context")
            for output in input.previousOutputs {
                promptParts.append("[\(output.agentId)]: \(output.content)")
            }
            promptParts.append("")
        }

        // Add context variables
        if !input.context.isEmpty {
            promptParts.append("## Context Variables")
            for (key, value) in input.context {
                if let str = value.stringValue {
                    promptParts.append("- \(key): \(str)")
                }
            }
            promptParts.append("")
        }

        // Add main content
        promptParts.append("## Task")
        promptParts.append(input.content)

        return promptParts.joined(separator: "\n")
    }

    private func calculateConfidence(_ response: String) -> Double {
        // Simple heuristic based on response quality
        let wordCount = response.split(separator: " ").count

        if wordCount < 10 {
            return 0.5
        } else if wordCount < 50 {
            return 0.7
        } else if wordCount < 200 {
            return 0.85
        } else {
            return 0.9
        }
    }

    private func mapToGeminiModel(_ modelString: String) -> GeminiClient.Model {
        switch modelString.lowercased() {
        case "gemini-2.5-flash", "flash":
            return .gemini25Flash
        case "gemini-2.5-pro", "pro":
            return .gemini25Pro
        case "gemini-2.5-flash-lite", "lite":
            return .gemini25FlashLite
        default:
            return .gemini25Flash
        }
    }
}

// MARK: - Specialized LLM Agents

/// Agent specialized for data analysis
public final class AnalysisLLMAgent: GeminiLLMAgent {
    public init(
        name: String = "Analysis Agent",
        client: GeminiClient,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        let systemPrompt = """
        You are a data analysis expert. Your role is to:
        1. Analyze data patterns and trends
        2. Identify key insights and anomalies
        3. Provide actionable recommendations
        4. Present findings in a structured format

        Always structure your analysis with:
        - Key Findings
        - Data Patterns
        - Recommendations
        - Confidence Level
        """

        super.init(
            name: name,
            description: "Specialized agent for data analysis",
            capabilities: [.dataAnalysis, .reasoning],
            model: "gemini-2.5-pro",
            systemInstruction: systemPrompt,
            temperature: 0.3,
            client: client,
            logger: logger
        )
    }
}

/// Agent specialized for document extraction
public final class ExtractionLLMAgent: GeminiLLMAgent {
    public init(
        name: String = "Extraction Agent",
        client: GeminiClient,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        let systemPrompt = """
        You are a document extraction specialist. Your role is to:
        1. Extract structured data from unstructured documents
        2. Identify key entities, dates, and values
        3. Map extracted data to provided schemas
        4. Validate extracted information

        Always output in structured JSON format when requested.
        """

        super.init(
            name: name,
            description: "Specialized agent for document extraction",
            capabilities: [.documentExtraction, .textGeneration],
            model: "gemini-2.5-flash",
            systemInstruction: systemPrompt,
            temperature: 0.1,
            client: client,
            logger: logger
        )
    }
}

/// Agent specialized for review and quality assurance
public final class ReviewLLMAgent: GeminiLLMAgent {
    public init(
        name: String = "Review Agent",
        client: GeminiClient,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        let systemPrompt = """
        You are a quality review specialist. Your role is to:
        1. Review content for accuracy and completeness
        2. Identify errors, inconsistencies, and gaps
        3. Suggest improvements and corrections
        4. Assign quality scores

        Provide detailed feedback with specific examples.
        """

        super.init(
            name: name,
            description: "Specialized agent for quality review",
            capabilities: [.review, .reasoning],
            model: "gemini-2.5-pro",
            systemInstruction: systemPrompt,
            temperature: 0.5,
            client: client,
            logger: logger
        )
    }
}
