//
//  LoopAgent.swift
//  gemini-swfit
//
//  Agent that executes child agents in a loop with conditions
//

import Foundation
import SwiftyBeaver

/// Agent that executes child agents iteratively until a condition is met
public final class LoopAgent: WorkflowAgent, @unchecked Sendable {

    // MARK: - Properties

    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]
    public let children: [any Agent]

    private let logger: SwiftyBeaver.Type
    private let maxIterations: Int
    private let minIterations: Int
    private let exitCondition: LoopExitCondition

    /// Conditions for exiting the loop
    public enum LoopExitCondition: Sendable {
        case iterations(Int)                    // Fixed number
        case confidenceThreshold(Double)        // Exit when confidence >= threshold
        case convergence(tolerance: Double)     // Exit when outputs converge
        case custom(String)                     // Custom expression (evaluated by LLM)
    }

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String = "Loop Agent",
        description: String = "Executes agents iteratively",
        children: [any Agent],
        maxIterations: Int = 10,
        minIterations: Int = 1,
        exitCondition: LoopExitCondition = .iterations(5),
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.capabilities = [.reasoning, .selfArgumentation]
        self.children = children
        self.maxIterations = maxIterations
        self.minIterations = minIterations
        self.exitCondition = exitCondition
        self.logger = logger
    }

    // MARK: - Agent Protocol

    public func canHandle(input: AgentInput) -> Bool {
        return !children.isEmpty
    }

    public func process(input: AgentInput) async throws -> AgentOutput {
        let startTime = Date()
        logger.info("[\(name)] Starting loop execution (max: \(maxIterations) iterations)")

        let outputs = try await executeWorkflow(input: input)

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("[\(name)] Completed \(outputs.count) iterations in \(processingTime)s")

        return buildFinalOutput(from: outputs, processingTime: processingTime)
    }

    // MARK: - WorkflowAgent Protocol

    public func executeWorkflow(input: AgentInput) async throws -> [AgentOutput] {
        var allOutputs: [AgentOutput] = []
        var currentInput = input
        var iteration = 0

        while iteration < maxIterations {
            iteration += 1
            logger.debug("[\(name)] Starting iteration \(iteration)")

            // Execute all child agents in sequence for this iteration
            var iterationOutputs: [AgentOutput] = []

            for agent in children {
                let output = try await agent.process(input: currentInput)
                iterationOutputs.append(output)

                // Update input for next agent
                currentInput = AgentInput(
                    id: UUID().uuidString,
                    content: currentInput.content,
                    context: mergeContext(currentInput.context, output),
                    metadata: currentInput.metadata,
                    previousOutputs: iterationOutputs
                )
            }

            // Combine iteration outputs
            let iterationOutput = combineIterationOutputs(iterationOutputs, iteration: iteration)
            allOutputs.append(iterationOutput)

            // Check exit condition
            if iteration >= minIterations && shouldExit(outputs: allOutputs) {
                logger.info("[\(name)] Exit condition met at iteration \(iteration)")
                break
            }

            // Update input for next iteration
            currentInput = AgentInput(
                id: UUID().uuidString,
                content: input.content,
                context: mergeAllOutputsContext(allOutputs),
                metadata: input.metadata,
                previousOutputs: allOutputs
            )
        }

        return allOutputs
    }

    // MARK: - Private Methods

    private func shouldExit(outputs: [AgentOutput]) -> Bool {
        switch exitCondition {
        case .iterations(let count):
            return outputs.count >= count

        case .confidenceThreshold(let threshold):
            guard let lastOutput = outputs.last else { return false }
            return lastOutput.confidence >= threshold

        case .convergence(let tolerance):
            return hasConverged(outputs: outputs, tolerance: tolerance)

        case .custom:
            // Custom conditions would need LLM evaluation
            return false
        }
    }

    private func hasConverged(outputs: [AgentOutput], tolerance: Double) -> Bool {
        guard outputs.count >= 2 else { return false }

        let lastTwo = Array(outputs.suffix(2))
        guard lastTwo.count == 2 else { return false }

        let diff = abs(lastTwo[0].confidence - lastTwo[1].confidence)
        return diff < tolerance
    }

    private func combineIterationOutputs(
        _ outputs: [AgentOutput],
        iteration: Int
    ) -> AgentOutput {
        let combinedContent = outputs.map { $0.content }.joined(separator: "\n")
        let avgConfidence = outputs.isEmpty ? 0.0 :
            outputs.reduce(0.0) { $0 + $1.confidence } / Double(outputs.count)

        var structuredData: [String: AnySendable] = [:]
        structuredData["iteration"] = AnySendable(iteration)
        structuredData["agent_count"] = AnySendable(outputs.count)

        return AgentOutput(
            agentId: "\(id)_iter\(iteration)",
            content: combinedContent,
            structuredData: structuredData,
            confidence: avgConfidence,
            processingTime: outputs.reduce(0) { $0 + $1.processingTime }
        )
    }

    private func buildFinalOutput(
        from outputs: [AgentOutput],
        processingTime: TimeInterval
    ) -> AgentOutput {
        // Build summary of all iterations
        var summaryParts: [String] = []
        summaryParts.append("## Loop Execution Summary")
        summaryParts.append("Total Iterations: \(outputs.count)")
        summaryParts.append("")

        for (index, output) in outputs.enumerated() {
            summaryParts.append("### Iteration \(index + 1)")
            summaryParts.append("Confidence: \(String(format: "%.2f", output.confidence))")
            summaryParts.append(output.content)
            summaryParts.append("")
        }

        // Use last output's content as main result
        let finalContent = outputs.last?.content ?? ""
        let finalConfidence = outputs.last?.confidence ?? 0.0

        var structuredData: [String: AnySendable] = [:]
        structuredData["total_iterations"] = AnySendable(outputs.count)
        structuredData["final_confidence"] = AnySendable(finalConfidence)
        structuredData["summary"] = AnySendable(summaryParts.joined(separator: "\n"))

        return AgentOutput(
            agentId: id,
            content: finalContent,
            structuredData: structuredData,
            confidence: finalConfidence,
            processingTime: processingTime
        )
    }

    private func mergeContext(
        _ context: [String: AnySendable],
        _ output: AgentOutput
    ) -> [String: AnySendable] {
        var merged = context
        merged["last_output"] = AnySendable(output.content)
        merged["last_confidence"] = AnySendable(output.confidence)
        return merged
    }

    private func mergeAllOutputsContext(
        _ outputs: [AgentOutput]
    ) -> [String: AnySendable] {
        var context: [String: AnySendable] = [:]
        context["iteration_count"] = AnySendable(outputs.count)
        context["all_outputs"] = AnySendable(outputs.map { $0.content })
        context["confidence_trend"] = AnySendable(outputs.map { $0.confidence })
        return context
    }
}

// MARK: - Builder Support

public extension LoopAgent {
    /// Create loop agent with closure-based child definition
    convenience init(
        name: String = "Loop Agent",
        maxIterations: Int = 10,
        exitCondition: LoopExitCondition = .iterations(5),
        @AgentBuilder agents: () -> [any Agent]
    ) {
        self.init(
            name: name,
            children: agents(),
            maxIterations: maxIterations,
            exitCondition: exitCondition
        )
    }

    /// Create a self-argumentation loop (5+ cycles)
    static func selfArgumentation(
        agent: any Agent,
        cycles: Int = 5
    ) -> LoopAgent {
        return LoopAgent(
            name: "Self-Argumentation Loop",
            children: [agent],
            maxIterations: cycles + 2, // Allow extra for convergence
            minIterations: cycles,
            exitCondition: .confidenceThreshold(0.95)
        )
    }
}
