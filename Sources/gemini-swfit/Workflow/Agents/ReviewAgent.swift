//
//  ReviewAgent.swift
//  gemini-swfit
//
//  Agent for quality review and validation of outputs
//

import Foundation
import SwiftyBeaver

/// Agent that performs quality review and validation on content
public final class ReviewAgent: Agent, @unchecked Sendable {

    // MARK: - Types

    /// Review criteria configuration
    public struct ReviewCriteria: Sendable {
        public let name: String
        public let weight: Double
        public let minimumScore: Double
        public let description: String

        public init(
            name: String,
            weight: Double = 1.0,
            minimumScore: Double = 0.6,
            description: String = ""
        ) {
            self.name = name
            self.weight = weight
            self.minimumScore = minimumScore
            self.description = description
        }
    }

    /// Result of a single criterion review
    public struct CriterionResult: Sendable {
        public let criterion: String
        public let score: Double
        public let passed: Bool
        public let feedback: String
        public let suggestions: [String]
    }

    /// Complete review result
    public struct ReviewResult: Sendable {
        public let overallScore: Double
        public let passed: Bool
        public let criteriaResults: [CriterionResult]
        public let summary: String
        public let improvements: [String]
        public let confidence: Double
    }

    // MARK: - Properties

    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]

    private let client: GeminiClient
    private let logger: SwiftyBeaver.Type
    private let criteria: [ReviewCriteria]
    private let passThreshold: Double

    // MARK: - Default Criteria

    public static let defaultCriteria: [ReviewCriteria] = [
        ReviewCriteria(
            name: "Accuracy",
            weight: 1.5,
            minimumScore: 0.7,
            description: "Factual correctness and precision"
        ),
        ReviewCriteria(
            name: "Completeness",
            weight: 1.2,
            minimumScore: 0.6,
            description: "Coverage of all required aspects"
        ),
        ReviewCriteria(
            name: "Clarity",
            weight: 1.0,
            minimumScore: 0.6,
            description: "Clear and understandable presentation"
        ),
        ReviewCriteria(
            name: "Consistency",
            weight: 1.0,
            minimumScore: 0.6,
            description: "Internal logical consistency"
        ),
        ReviewCriteria(
            name: "Relevance",
            weight: 1.0,
            minimumScore: 0.6,
            description: "Alignment with the original request"
        )
    ]

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String = "Review Agent",
        client: GeminiClient,
        criteria: [ReviewCriteria] = ReviewAgent.defaultCriteria,
        passThreshold: Double = 0.7,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = "Performs quality review and validation"
        self.capabilities = [.review, .reasoning]
        self.client = client
        self.criteria = criteria
        self.passThreshold = passThreshold
        self.logger = logger
    }

    // MARK: - Agent Protocol

    public func canHandle(input: AgentInput) -> Bool {
        return !input.content.isEmpty || !input.previousOutputs.isEmpty
    }

    public func process(input: AgentInput) async throws -> AgentOutput {
        let startTime = Date()
        logger.info("[\(name)] Starting review process")

        // Get content to review
        let contentToReview = extractContentToReview(from: input)

        // Perform review
        let result = try await performReview(
            content: contentToReview,
            context: input
        )

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("[\(name)] Review completed. Score: \(result.overallScore)")

        return buildOutput(from: result, processingTime: processingTime)
    }

    // MARK: - Review Process

    private func extractContentToReview(from input: AgentInput) -> String {
        // If there are previous outputs, review those
        if !input.previousOutputs.isEmpty {
            return input.previousOutputs
                .map { "[\($0.agentId)]:\n\($0.content)" }
                .joined(separator: "\n\n---\n\n")
        }

        // Otherwise review the input content
        return input.content
    }

    private func performReview(
        content: String,
        context: AgentInput
    ) async throws -> ReviewResult {
        var criteriaResults: [CriterionResult] = []

        // Review each criterion
        for criterion in criteria {
            let result = try await reviewCriterion(
                criterion: criterion,
                content: content,
                originalRequest: context.content
            )
            criteriaResults.append(result)
        }

        // Calculate overall score
        let totalWeight = criteria.reduce(0.0) { $0 + $1.weight }
        let weightedScore = zip(criteria, criteriaResults).reduce(0.0) {
            $0 + ($1.0.weight * $1.1.score)
        }
        let overallScore = weightedScore / totalWeight

        // Determine pass/fail
        let allMinimumsMet = zip(criteria, criteriaResults).allSatisfy {
            $1.score >= $0.minimumScore
        }
        let passed = overallScore >= passThreshold && allMinimumsMet

        // Generate summary and improvements
        let summary = generateSummary(
            results: criteriaResults,
            overallScore: overallScore,
            passed: passed
        )

        let improvements = criteriaResults
            .filter { !$0.passed }
            .flatMap { $0.suggestions }

        return ReviewResult(
            overallScore: overallScore,
            passed: passed,
            criteriaResults: criteriaResults,
            summary: summary,
            improvements: improvements,
            confidence: calculateConfidence(criteriaResults)
        )
    }

    private func reviewCriterion(
        criterion: ReviewCriteria,
        content: String,
        originalRequest: String
    ) async throws -> CriterionResult {
        let prompt = """
        Review the following content for: \(criterion.name)

        Criterion Description: \(criterion.description)
        Minimum Required Score: \(criterion.minimumScore)

        Original Request: \(originalRequest)

        Content to Review:
        \(content.prefix(3000))

        Evaluate on a scale of 0.0 to 1.0 and provide specific feedback.

        Format your response as:
        SCORE: [0.X]
        FEEDBACK: [Your detailed feedback]
        SUGGESTIONS:
        - [Improvement suggestion 1]
        - [Improvement suggestion 2]
        """

        let response = try await generateWithLLM(prompt: prompt)
        return parseCriterionResult(response, criterion: criterion.name)
    }

    // MARK: - Helper Methods

    private func generateWithLLM(prompt: String) async throws -> String {
        let response = try await client.generateContent(
            model: .gemini25Flash,
            prompt: prompt,
            generationConfig: GeminiClient.GenerationConfig(temperature: 0.3)
        )

        guard let text = response.text else {
            throw AgentError.processingFailed("No response from LLM")
        }

        return text
    }

    private func parseCriterionResult(
        _ response: String,
        criterion: String
    ) -> CriterionResult {
        // Parse SCORE
        var score = 0.7
        if let scoreRange = response.range(of: "SCORE:") {
            let afterScore = response[scoreRange.upperBound...]
            let scoreStr = afterScore.prefix(10)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = Double(scoreStr.filter { $0.isNumber || $0 == "." }) {
                score = min(1.0, max(0.0, parsed))
            }
        }

        // Parse FEEDBACK
        var feedback = ""
        if let feedbackRange = response.range(of: "FEEDBACK:") {
            let afterFeedback = response[feedbackRange.upperBound...]
            if let endRange = afterFeedback.range(of: "\nSUGGESTIONS:") {
                feedback = String(afterFeedback[..<endRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                feedback = String(afterFeedback.prefix(500))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Parse SUGGESTIONS
        var suggestions: [String] = []
        if let suggestRange = response.range(of: "SUGGESTIONS:") {
            let afterSuggest = response[suggestRange.upperBound...]
            let lines = afterSuggest.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("-") {
                    suggestions.append(
                        String(trimmed.dropFirst())
                            .trimmingCharacters(in: .whitespaces)
                    )
                }
            }
        }

        let minimumScore = criteria.first { $0.name == criterion }?.minimumScore ?? 0.6

        return CriterionResult(
            criterion: criterion,
            score: score,
            passed: score >= minimumScore,
            feedback: feedback.isEmpty ? "Review completed" : feedback,
            suggestions: suggestions
        )
    }

    private func generateSummary(
        results: [CriterionResult],
        overallScore: Double,
        passed: Bool
    ) -> String {
        let passedCount = results.filter { $0.passed }.count
        let status = passed ? "PASSED" : "NEEDS IMPROVEMENT"

        return """
        Review Status: \(status)
        Overall Score: \(String(format: "%.2f", overallScore))
        Criteria Passed: \(passedCount)/\(results.count)
        """
    }

    private func calculateConfidence(_ results: [CriterionResult]) -> Double {
        let avgScore = results.reduce(0.0) { $0 + $1.score } / Double(results.count)
        return avgScore
    }

    private func buildOutput(
        from result: ReviewResult,
        processingTime: TimeInterval
    ) -> AgentOutput {
        var content = """
        ## Review Result

        **Status:** \(result.passed ? "✅ PASSED" : "❌ NEEDS IMPROVEMENT")
        **Overall Score:** \(String(format: "%.2f", result.overallScore))

        ### Criteria Results

        """

        for criterionResult in result.criteriaResults {
            let status = criterionResult.passed ? "✅" : "❌"
            content += """

            #### \(status) \(criterionResult.criterion): \(String(format: "%.2f", criterionResult.score))
            \(criterionResult.feedback)

            """
        }

        if !result.improvements.isEmpty {
            content += "\n### Suggested Improvements\n"
            for improvement in result.improvements {
                content += "- \(improvement)\n"
            }
        }

        var structuredData: [String: AnySendable] = [:]
        structuredData["overall_score"] = AnySendable(result.overallScore)
        structuredData["passed"] = AnySendable(result.passed)
        structuredData["criteria_count"] = AnySendable(result.criteriaResults.count)

        return AgentOutput(
            agentId: id,
            content: content,
            structuredData: structuredData,
            confidence: result.confidence,
            processingTime: processingTime
        )
    }
}

// MARK: - Predefined Review Configurations

public extension ReviewAgent {
    /// Create a code review agent
    static func codeReview(client: GeminiClient) -> ReviewAgent {
        let criteria = [
            ReviewCriteria(
                name: "Code Quality",
                weight: 1.5,
                minimumScore: 0.7,
                description: "Clean, maintainable code following best practices"
            ),
            ReviewCriteria(
                name: "Security",
                weight: 2.0,
                minimumScore: 0.8,
                description: "No security vulnerabilities or unsafe patterns"
            ),
            ReviewCriteria(
                name: "Performance",
                weight: 1.2,
                minimumScore: 0.6,
                description: "Efficient algorithms and resource usage"
            ),
            ReviewCriteria(
                name: "Documentation",
                weight: 0.8,
                minimumScore: 0.5,
                description: "Clear comments and documentation"
            )
        ]

        return ReviewAgent(
            name: "Code Review Agent",
            client: client,
            criteria: criteria
        )
    }

    /// Create a document review agent
    static func documentReview(client: GeminiClient) -> ReviewAgent {
        let criteria = [
            ReviewCriteria(
                name: "Content Quality",
                weight: 1.5,
                minimumScore: 0.7,
                description: "High-quality, accurate content"
            ),
            ReviewCriteria(
                name: "Structure",
                weight: 1.0,
                minimumScore: 0.6,
                description: "Well-organized with clear sections"
            ),
            ReviewCriteria(
                name: "Grammar",
                weight: 0.8,
                minimumScore: 0.7,
                description: "Correct grammar and spelling"
            ),
            ReviewCriteria(
                name: "Formatting",
                weight: 0.6,
                minimumScore: 0.5,
                description: "Consistent and appropriate formatting"
            )
        ]

        return ReviewAgent(
            name: "Document Review Agent",
            client: client,
            criteria: criteria
        )
    }
}
