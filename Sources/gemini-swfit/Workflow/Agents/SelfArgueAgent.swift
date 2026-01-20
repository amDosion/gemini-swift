//
//  SelfArgueAgent.swift
//  gemini-swfit
//
//  Agent that performs self-argumentation through multiple cycles
//

import Foundation
import SwiftyBeaver

/// Agent that performs self-argumentation with at least 5 cycles
public final class SelfArgueAgent: Agent, @unchecked Sendable {

    // MARK: - Types

    /// A single argument in the debate
    public struct Argument: Sendable {
        public let cycle: Int
        public let type: ArgumentType
        public let claim: String
        public let evidence: [String]
        public let counterPoints: [String]
        public let confidence: Double

        public enum ArgumentType: String, Sendable {
            case initial = "Initial Claim"
            case counter = "Counter-Argument"
            case defense = "Defense"
            case synthesis = "Synthesis"
            case validation = "Final Validation"
            case deepReview = "Deep Review"
        }
    }

    /// Result of self-argumentation
    public struct ArgumentationResult: Sendable {
        public let cycles: [Argument]
        public let finalConclusion: String
        public let confidenceScore: Double
        public let consensusReached: Bool
        public let keyInsights: [String]
    }

    // MARK: - Properties

    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]

    private let client: GeminiClient
    private let logger: SwiftyBeaver.Type
    private let minCycles: Int
    private let maxCycles: Int
    private let confidenceThreshold: Double

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String = "Self-Argumentation Agent",
        client: GeminiClient,
        minCycles: Int = 5,
        maxCycles: Int = 8,
        confidenceThreshold: Double = 0.9,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = "Performs self-argumentation through multiple debate cycles"
        self.capabilities = [.selfArgumentation, .reasoning]
        self.client = client
        self.minCycles = max(5, minCycles) // Ensure at least 5 cycles
        self.maxCycles = max(minCycles, maxCycles)
        self.confidenceThreshold = confidenceThreshold
        self.logger = logger
    }

    // MARK: - Agent Protocol

    public func canHandle(input: AgentInput) -> Bool {
        return !input.content.isEmpty
    }

    public func process(input: AgentInput) async throws -> AgentOutput {
        let startTime = Date()
        logger.info("[\(name)] Starting self-argumentation on: \(input.content.prefix(100))...")

        let result = try await performArgumentation(topic: input.content, context: input)

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("[\(name)] Completed \(result.cycles.count) cycles in \(processingTime)s")

        return buildOutput(from: result, processingTime: processingTime)
    }

    // MARK: - Argumentation Process

    private func performArgumentation(
        topic: String,
        context: AgentInput
    ) async throws -> ArgumentationResult {
        var arguments: [Argument] = []
        var currentCycle = 0

        // Cycle 1: Initial Analysis
        currentCycle += 1
        let initialClaim = try await generateInitialClaim(topic: topic)
        arguments.append(initialClaim)
        logger.debug("[\(name)] Cycle 1: Initial analysis completed")

        // Cycle 2: Counter-Argument Generation
        currentCycle += 1
        let counterArgument = try await generateCounterArgument(
            against: initialClaim,
            topic: topic
        )
        arguments.append(counterArgument)
        logger.debug("[\(name)] Cycle 2: Counter-arguments generated")

        // Cycle 3: Defense and Refinement
        currentCycle += 1
        let defense = try await generateDefense(
            original: initialClaim,
            counter: counterArgument,
            topic: topic
        )
        arguments.append(defense)
        logger.debug("[\(name)] Cycle 3: Defense completed")

        // Cycle 4: Synthesis
        currentCycle += 1
        let synthesis = try await generateSynthesis(
            arguments: arguments,
            topic: topic
        )
        arguments.append(synthesis)
        logger.debug("[\(name)] Cycle 4: Synthesis completed")

        // Cycle 5: Final Validation
        currentCycle += 1
        let validation = try await generateValidation(
            synthesis: synthesis,
            allArguments: arguments,
            topic: topic
        )
        arguments.append(validation)
        logger.debug("[\(name)] Cycle 5: Validation completed")

        // Additional cycles if needed (Cycle 6+: Deep Review)
        while currentCycle < maxCycles && validation.confidence < confidenceThreshold {
            currentCycle += 1
            let deepReview = try await generateDeepReview(
                cycle: currentCycle,
                previousArguments: arguments,
                topic: topic
            )
            arguments.append(deepReview)
            logger.debug("[\(name)] Cycle \(currentCycle): Deep review completed")

            if deepReview.confidence >= confidenceThreshold {
                break
            }
        }

        // Build final result
        return buildResult(from: arguments, topic: topic)
    }

    // MARK: - Cycle Generators

    private func generateInitialClaim(topic: String) async throws -> Argument {
        let prompt = """
        Analyze the following topic and provide an initial comprehensive analysis:

        Topic: \(topic)

        Provide:
        1. Main claim or thesis
        2. Key supporting evidence (list 3-5 points)
        3. Initial confidence level (0.0-1.0)

        Format your response as:
        CLAIM: [Your main claim]
        EVIDENCE:
        - [Point 1]
        - [Point 2]
        - [Point 3]
        CONFIDENCE: [0.X]
        """

        let response = try await generateWithLLM(prompt: prompt)
        return parseArgument(response, cycle: 1, type: .initial)
    }

    private func generateCounterArgument(
        against claim: Argument,
        topic: String
    ) async throws -> Argument {
        let prompt = """
        Challenge the following claim about "\(topic)":

        Original Claim: \(claim.claim)
        Supporting Evidence: \(claim.evidence.joined(separator: "; "))

        Provide strong counter-arguments:
        1. Challenge the main claim
        2. Find weaknesses in the evidence
        3. Present alternative perspectives

        Format your response as:
        CLAIM: [Your counter-claim]
        EVIDENCE:
        - [Counter-point 1]
        - [Counter-point 2]
        - [Counter-point 3]
        COUNTER_POINTS:
        - [Weakness 1]
        - [Weakness 2]
        CONFIDENCE: [0.X]
        """

        let response = try await generateWithLLM(prompt: prompt)
        return parseArgument(response, cycle: 2, type: .counter)
    }

    private func generateDefense(
        original: Argument,
        counter: Argument,
        topic: String
    ) async throws -> Argument {
        let prompt = """
        Defend and refine the original position on "\(topic)":

        Original Claim: \(original.claim)
        Counter-Arguments: \(counter.claim)
        Weaknesses Identified: \(counter.counterPoints.joined(separator: "; "))

        Provide a refined defense:
        1. Address each counter-argument
        2. Strengthen weak points
        3. Acknowledge valid criticisms

        Format your response as:
        CLAIM: [Refined claim]
        EVIDENCE:
        - [Strengthened point 1]
        - [Strengthened point 2]
        - [New supporting point]
        COUNTER_POINTS:
        - [Acknowledged limitation 1]
        CONFIDENCE: [0.X]
        """

        let response = try await generateWithLLM(prompt: prompt)
        return parseArgument(response, cycle: 3, type: .defense)
    }

    private func generateSynthesis(
        arguments: [Argument],
        topic: String
    ) async throws -> Argument {
        let argumentsSummary = arguments.map {
            "[\($0.type.rawValue)]: \($0.claim)"
        }.joined(separator: "\n")

        let prompt = """
        Synthesize all perspectives on "\(topic)":

        Previous Arguments:
        \(argumentsSummary)

        Create a balanced synthesis:
        1. Merge the strongest points from all sides
        2. Resolve contradictions where possible
        3. Identify areas of consensus

        Format your response as:
        CLAIM: [Synthesized conclusion]
        EVIDENCE:
        - [Merged insight 1]
        - [Merged insight 2]
        - [Consensus point]
        COUNTER_POINTS:
        - [Remaining uncertainty]
        CONFIDENCE: [0.X]
        """

        let response = try await generateWithLLM(prompt: prompt)
        return parseArgument(response, cycle: 4, type: .synthesis)
    }

    private func generateValidation(
        synthesis: Argument,
        allArguments: [Argument],
        topic: String
    ) async throws -> Argument {
        let prompt = """
        Validate the synthesized conclusion on "\(topic)":

        Conclusion: \(synthesis.claim)
        Supporting Points: \(synthesis.evidence.joined(separator: "; "))

        Perform final validation:
        1. Assess overall quality and completeness
        2. Check for logical consistency
        3. Calculate final confidence score
        4. List key insights

        Format your response as:
        CLAIM: [Validated conclusion]
        EVIDENCE:
        - [Quality assessment]
        - [Consistency check]
        - [Key insight 1]
        - [Key insight 2]
        CONFIDENCE: [0.X]
        """

        let response = try await generateWithLLM(prompt: prompt)
        return parseArgument(response, cycle: 5, type: .validation)
    }

    private func generateDeepReview(
        cycle: Int,
        previousArguments: [Argument],
        topic: String
    ) async throws -> Argument {
        guard let lastArg = previousArguments.last else {
            throw AgentError.processingFailed("No previous arguments for deep review")
        }

        let prompt = """
        Deep review (Cycle \(cycle)) on "\(topic)":

        Current Conclusion: \(lastArg.claim)
        Current Confidence: \(lastArg.confidence)

        Perform deep analysis:
        1. Consider edge cases
        2. Explore alternative perspectives
        3. Strengthen or revise the conclusion

        Format your response as:
        CLAIM: [Reviewed conclusion]
        EVIDENCE:
        - [Edge case consideration]
        - [Alternative perspective]
        - [Strengthened point]
        CONFIDENCE: [0.X]
        """

        let response = try await generateWithLLM(prompt: prompt)
        return parseArgument(response, cycle: cycle, type: .deepReview)
    }

    // MARK: - Helper Methods

    private func generateWithLLM(prompt: String) async throws -> String {
        let response = try await client.generateContent(
            model: .gemini25Pro,
            text: prompt,
            generationConfig: GeminiClient.GenerationConfig(temperature: 0.7)
        )

        guard let text = response.text else {
            throw AgentError.processingFailed("No response from LLM")
        }

        return text
    }

    private func parseArgument(_ response: String, cycle: Int, type: Argument.ArgumentType) -> Argument {
        // Parse CLAIM
        var claim = ""
        if let claimRange = response.range(of: "CLAIM:") {
            let afterClaim = response[claimRange.upperBound...]
            if let endRange = afterClaim.range(of: "\nEVIDENCE:") ?? afterClaim.range(of: "\n\n") {
                claim = String(afterClaim[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                claim = String(afterClaim.prefix(500)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Parse EVIDENCE
        var evidence: [String] = []
        if let evidenceRange = response.range(of: "EVIDENCE:") {
            let afterEvidence = response[evidenceRange.upperBound...]
            let lines = afterEvidence.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("-") {
                    evidence.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                } else if trimmed.hasPrefix("COUNTER") || trimmed.hasPrefix("CONFIDENCE") {
                    break
                }
            }
        }

        // Parse COUNTER_POINTS
        var counterPoints: [String] = []
        if let counterRange = response.range(of: "COUNTER_POINTS:") {
            let afterCounter = response[counterRange.upperBound...]
            let lines = afterCounter.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("-") {
                    counterPoints.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                } else if trimmed.hasPrefix("CONFIDENCE") {
                    break
                }
            }
        }

        // Parse CONFIDENCE
        var confidence = 0.7
        if let confRange = response.range(of: "CONFIDENCE:") {
            let afterConf = response[confRange.upperBound...]
            let confStr = afterConf.trimmingCharacters(in: .whitespacesAndNewlines).prefix(10)
            if let parsed = Double(confStr.filter { $0.isNumber || $0 == "." }) {
                confidence = min(1.0, max(0.0, parsed))
            }
        }

        return Argument(
            cycle: cycle,
            type: type,
            claim: claim.isEmpty ? response.prefix(200).description : claim,
            evidence: evidence.isEmpty ? ["Analysis provided"] : evidence,
            counterPoints: counterPoints,
            confidence: confidence
        )
    }

    private func buildResult(from arguments: [Argument], topic: String) -> ArgumentationResult {
        guard let finalArg = arguments.last else {
            // Return a default result if no arguments (should not happen)
            return ArgumentationResult(
                cycles: [],
                finalConclusion: "No conclusion reached",
                confidenceScore: 0.0,
                consensusReached: false,
                keyInsights: []
            )
        }
        let avgConfidence = arguments.reduce(0.0) { $0 + $1.confidence } / Double(arguments.count)

        // Extract key insights from all cycles
        var insights: [String] = []
        for arg in arguments {
            insights.append(contentsOf: arg.evidence.prefix(2))
        }

        return ArgumentationResult(
            cycles: arguments,
            finalConclusion: finalArg.claim,
            confidenceScore: finalArg.confidence,
            consensusReached: finalArg.confidence >= confidenceThreshold,
            keyInsights: Array(Set(insights)).prefix(5).map { $0 }
        )
    }

    private func buildOutput(
        from result: ArgumentationResult,
        processingTime: TimeInterval
    ) -> AgentOutput {
        var content = """
        ## Self-Argumentation Result

        **Final Conclusion:** \(result.finalConclusion)

        **Confidence Score:** \(String(format: "%.2f", result.confidenceScore))

        **Consensus Reached:** \(result.consensusReached ? "Yes" : "No")

        ### Argumentation Cycles (\(result.cycles.count) total)

        """

        for arg in result.cycles {
            content += """

            #### Cycle \(arg.cycle): \(arg.type.rawValue)
            - Claim: \(arg.claim.prefix(200))
            - Confidence: \(String(format: "%.2f", arg.confidence))

            """
        }

        content += "\n### Key Insights\n"
        for insight in result.keyInsights {
            content += "- \(insight)\n"
        }

        var structuredData: [String: AnySendable] = [:]
        structuredData["total_cycles"] = AnySendable(result.cycles.count)
        structuredData["final_confidence"] = AnySendable(result.confidenceScore)
        structuredData["consensus_reached"] = AnySendable(result.consensusReached)

        return AgentOutput(
            agentId: id,
            content: content,
            structuredData: structuredData,
            confidence: result.confidenceScore,
            processingTime: processingTime
        )
    }
}
