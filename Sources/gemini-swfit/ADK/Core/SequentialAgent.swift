//
//  SequentialAgent.swift
//  gemini-swfit
//
//  Agent that executes child agents sequentially
//

import Foundation
import SwiftyBeaver

/// Agent that executes child agents in sequence, passing outputs forward
public final class SequentialAgent: WorkflowAgent, @unchecked Sendable {

    // MARK: - Properties

    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]
    public let children: [any Agent]

    private let logger: SwiftyBeaver.Type
    private let stopOnError: Bool
    private let passOutputs: Bool

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String = "Sequential Agent",
        description: String = "Executes agents in sequence",
        children: [any Agent],
        stopOnError: Bool = true,
        passOutputs: Bool = true,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.capabilities = [.reasoning]
        self.children = children
        self.stopOnError = stopOnError
        self.passOutputs = passOutputs
        self.logger = logger
    }

    // MARK: - Agent Protocol

    public func canHandle(input: AgentInput) -> Bool {
        return !children.isEmpty
    }

    public func process(input: AgentInput) async throws -> AgentOutput {
        let startTime = Date()
        logger.info("[\(name)] Starting sequential execution with \(children.count) agents")

        let outputs = try await executeWorkflow(input: input)

        let processingTime = Date().timeIntervalSince(startTime)

        // Combine outputs into final result
        let combinedContent = outputs.map { $0.content }.joined(separator: "\n\n")
        let avgConfidence = outputs.isEmpty ? 0.0 :
            outputs.reduce(0.0) { $0 + $1.confidence } / Double(outputs.count)

        logger.info("[\(name)] Completed \(outputs.count) agents in \(processingTime)s")

        return AgentOutput(
            agentId: id,
            content: combinedContent,
            structuredData: buildStructuredData(from: outputs),
            confidence: avgConfidence,
            processingTime: processingTime
        )
    }

    // MARK: - WorkflowAgent Protocol

    public func executeWorkflow(input: AgentInput) async throws -> [AgentOutput] {
        var outputs: [AgentOutput] = []
        var currentInput = input

        for (index, agent) in children.enumerated() {
            logger.debug("[\(name)] Executing agent \(index + 1)/\(children.count): \(agent.name)")

            do {
                // Check if agent can handle input
                guard agent.canHandle(input: currentInput) else {
                    logger.warning("[\(name)] Agent \(agent.name) cannot handle input, skipping")
                    continue
                }

                // Execute agent
                let output = try await agent.process(input: currentInput)
                outputs.append(output)

                // Pass output to next agent if enabled
                if passOutputs {
                    currentInput = AgentInput(
                        id: UUID().uuidString,
                        content: currentInput.content,
                        context: currentInput.context,
                        metadata: currentInput.metadata,
                        previousOutputs: outputs
                    )
                }

                logger.debug("[\(name)] Agent \(agent.name) completed with confidence: \(output.confidence)")

            } catch {
                logger.error("[\(name)] Agent \(agent.name) failed: \(error)")

                if stopOnError {
                    throw AgentError.childAgentFailed(agent.id, error.localizedDescription)
                }
            }
        }

        return outputs
    }

    // MARK: - Private Methods

    private func buildStructuredData(from outputs: [AgentOutput]) -> [String: AnySendable] {
        var data: [String: AnySendable] = [:]

        data["agent_count"] = AnySendable(outputs.count)
        data["agent_ids"] = AnySendable(outputs.map { $0.agentId })

        // Merge all structured data
        for output in outputs {
            if let structuredData = output.structuredData {
                for (key, value) in structuredData {
                    data["\(output.agentId)_\(key)"] = value
                }
            }
        }

        return data
    }
}

// MARK: - Builder Support

public extension SequentialAgent {
    /// Create sequential agent with closure-based child definition
    convenience init(
        name: String = "Sequential Agent",
        stopOnError: Bool = true,
        @AgentBuilder agents: () -> [any Agent]
    ) {
        self.init(
            name: name,
            children: agents(),
            stopOnError: stopOnError
        )
    }
}

/// Builder for creating agent arrays
@resultBuilder
public struct AgentBuilder {
    public static func buildBlock(_ agents: any Agent...) -> [any Agent] {
        return agents
    }

    public static func buildOptional(_ component: [any Agent]?) -> [any Agent] {
        return component ?? []
    }

    public static func buildEither(first component: [any Agent]) -> [any Agent] {
        return component
    }

    public static func buildEither(second component: [any Agent]) -> [any Agent] {
        return component
    }

    public static func buildArray(_ components: [[any Agent]]) -> [any Agent] {
        return components.flatMap { $0 }
    }
}

// MARK: - Convenience Extensions

public extension SequentialAgent {
    /// Create a simple pipeline of agents
    static func pipeline(
        _ agents: any Agent...,
        name: String = "Pipeline"
    ) -> SequentialAgent {
        return SequentialAgent(name: name, children: agents)
    }

    /// Add an agent to the sequence
    func adding(_ agent: any Agent) -> SequentialAgent {
        return SequentialAgent(
            id: id,
            name: name,
            description: description,
            children: children + [agent],
            stopOnError: stopOnError,
            passOutputs: passOutputs,
            logger: logger
        )
    }
}
