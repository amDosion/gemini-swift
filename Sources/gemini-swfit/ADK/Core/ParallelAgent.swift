//
//  ParallelAgent.swift
//  gemini-swfit
//
//  Agent that executes child agents concurrently
//

import Foundation
import SwiftyBeaver

/// Agent that executes child agents in parallel for improved performance
public final class ParallelAgent: WorkflowAgent, @unchecked Sendable {

    // MARK: - Properties

    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]
    public let children: [any Agent]

    private let logger: SwiftyBeaver.Type
    private let maxConcurrent: Int
    private let failFast: Bool
    private let aggregationStrategy: AggregationStrategy

    /// Strategy for aggregating parallel outputs
    public enum AggregationStrategy: Sendable {
        case concatenate      // Join all outputs
        case bestConfidence   // Pick highest confidence
        case merge            // Merge structured data
        case custom((([AgentOutput]) -> AgentOutput)?)  // Note: closure not Sendable

        // Sendable version
        public static let defaultStrategy: AggregationStrategy = .concatenate
    }

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String = "Parallel Agent",
        description: String = "Executes agents concurrently",
        children: [any Agent],
        maxConcurrent: Int = 5,
        failFast: Bool = false,
        aggregationStrategy: AggregationStrategy = .concatenate,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.capabilities = [.reasoning]
        self.children = children
        self.maxConcurrent = maxConcurrent
        self.failFast = failFast
        self.aggregationStrategy = aggregationStrategy
        self.logger = logger
    }

    // MARK: - Agent Protocol

    public func canHandle(input: AgentInput) -> Bool {
        return !children.isEmpty
    }

    public func process(input: AgentInput) async throws -> AgentOutput {
        let startTime = Date()
        logger.info("[\(name)] Starting parallel execution with \(children.count) agents")

        let outputs = try await executeWorkflow(input: input)

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("[\(name)] Completed \(outputs.count) agents in \(processingTime)s")

        return aggregate(outputs: outputs, processingTime: processingTime)
    }

    // MARK: - WorkflowAgent Protocol

    public func executeWorkflow(input: AgentInput) async throws -> [AgentOutput] {
        return try await withThrowingTaskGroup(of: (Int, AgentOutput?).self) { group in
            var outputs: [(Int, AgentOutput)] = []

            // Add tasks for each child agent with concurrency limit
            for (index, agent) in children.enumerated() {
                // Wait if at capacity
                if index >= maxConcurrent {
                    if let result = try await group.next() {
                        if let output = result.1 {
                            outputs.append((result.0, output))
                        }
                    }
                }

                group.addTask { [self] in
                    return await self.executeChildAgent(agent, input: input, index: index)
                }
            }

            // Collect remaining results
            for try await result in group {
                if let output = result.1 {
                    outputs.append((result.0, output))
                } else if failFast {
                    throw AgentError.childAgentFailed("Agent at index \(result.0)", "Processing failed")
                }
            }

            // Sort by original order
            outputs.sort { $0.0 < $1.0 }
            return outputs.map { $0.1 }
        }
    }

    // MARK: - Private Methods

    private func executeChildAgent(
        _ agent: any Agent,
        input: AgentInput,
        index: Int
    ) async -> (Int, AgentOutput?) {
        logger.debug("[\(name)] Starting agent \(index): \(agent.name)")

        do {
            guard agent.canHandle(input: input) else {
                logger.warning("[\(name)] Agent \(agent.name) cannot handle input")
                return (index, nil)
            }

            let output = try await agent.process(input: input)
            logger.debug("[\(name)] Agent \(index) completed: \(agent.name)")
            return (index, output)

        } catch {
            logger.error("[\(name)] Agent \(index) failed: \(error)")
            return (index, nil)
        }
    }

    private func aggregate(outputs: [AgentOutput], processingTime: TimeInterval) -> AgentOutput {
        guard !outputs.isEmpty else {
            return AgentOutput(
                agentId: id,
                content: "No outputs generated",
                confidence: 0.0,
                processingTime: processingTime
            )
        }

        switch aggregationStrategy {
        case .concatenate:
            return aggregateConcatenate(outputs: outputs, processingTime: processingTime)

        case .bestConfidence:
            return aggregateBestConfidence(outputs: outputs, processingTime: processingTime)

        case .merge:
            return aggregateMerge(outputs: outputs, processingTime: processingTime)

        case .custom(let aggregator):
            if let customAggregator = aggregator {
                return customAggregator(outputs)
            }
            return aggregateConcatenate(outputs: outputs, processingTime: processingTime)
        }
    }

    private func aggregateConcatenate(
        outputs: [AgentOutput],
        processingTime: TimeInterval
    ) -> AgentOutput {
        let combinedContent = outputs
            .enumerated()
            .map { "[\($0.element.agentId)]\n\($0.element.content)" }
            .joined(separator: "\n\n---\n\n")

        let avgConfidence = outputs.reduce(0.0) { $0 + $1.confidence } / Double(outputs.count)

        return AgentOutput(
            agentId: id,
            content: combinedContent,
            structuredData: mergeStructuredData(outputs),
            confidence: avgConfidence,
            processingTime: processingTime
        )
    }

    private func aggregateBestConfidence(
        outputs: [AgentOutput],
        processingTime: TimeInterval
    ) -> AgentOutput {
        guard let best = outputs.max(by: { $0.confidence < $1.confidence }) else {
            return AgentOutput(
                agentId: id,
                content: "No outputs to aggregate",
                confidence: 0.0,
                processingTime: processingTime
            )
        }

        return AgentOutput(
            agentId: id,
            content: best.content,
            structuredData: best.structuredData,
            confidence: best.confidence,
            processingTime: processingTime
        )
    }

    private func aggregateMerge(
        outputs: [AgentOutput],
        processingTime: TimeInterval
    ) -> AgentOutput {
        let combinedContent = outputs.map { $0.content }.joined(separator: "\n")
        let avgConfidence = outputs.reduce(0.0) { $0 + $1.confidence } / Double(outputs.count)

        return AgentOutput(
            agentId: id,
            content: combinedContent,
            structuredData: mergeStructuredData(outputs),
            confidence: avgConfidence,
            processingTime: processingTime
        )
    }

    private func mergeStructuredData(_ outputs: [AgentOutput]) -> [String: AnySendable] {
        var merged: [String: AnySendable] = [:]
        merged["parallel_count"] = AnySendable(outputs.count)
        merged["agent_ids"] = AnySendable(outputs.map { $0.agentId })

        for output in outputs {
            if let data = output.structuredData {
                for (key, value) in data {
                    merged["\(output.agentId)_\(key)"] = value
                }
            }
        }

        return merged
    }
}

// MARK: - Builder Support

public extension ParallelAgent {
    /// Create parallel agent with closure-based child definition
    convenience init(
        name: String = "Parallel Agent",
        maxConcurrent: Int = 5,
        @AgentBuilder agents: () -> [any Agent]
    ) {
        self.init(
            name: name,
            children: agents(),
            maxConcurrent: maxConcurrent
        )
    }

    /// Create a fan-out pattern
    static func fanOut(
        _ agents: any Agent...,
        name: String = "Fan-Out"
    ) -> ParallelAgent {
        return ParallelAgent(name: name, children: agents)
    }
}
