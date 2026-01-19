//
//  AgentProtocol.swift
//  gemini-swfit
//
//  Core protocols for the Agent Development Kit (ADK)
//

import Foundation

// MARK: - Agent Input/Output

/// Input for agent processing
public struct AgentInput: Sendable {
    public let id: String
    public let content: String
    public let context: [String: AnySendable]
    public let metadata: AgentMetadata
    public let previousOutputs: [AgentOutput]

    public init(
        id: String = UUID().uuidString,
        content: String,
        context: [String: AnySendable] = [:],
        metadata: AgentMetadata = .init(),
        previousOutputs: [AgentOutput] = []
    ) {
        self.id = id
        self.content = content
        self.context = context
        self.metadata = metadata
        self.previousOutputs = previousOutputs
    }
}

/// Output from agent processing
public struct AgentOutput: Sendable {
    public let id: String
    public let agentId: String
    public let content: String
    public let structuredData: [String: AnySendable]?
    public let confidence: Double
    public let processingTime: TimeInterval
    public let metadata: AgentMetadata

    public init(
        id: String = UUID().uuidString,
        agentId: String,
        content: String,
        structuredData: [String: AnySendable]? = nil,
        confidence: Double = 1.0,
        processingTime: TimeInterval = 0,
        metadata: AgentMetadata = .init()
    ) {
        self.id = id
        self.agentId = agentId
        self.content = content
        self.structuredData = structuredData
        self.confidence = confidence
        self.processingTime = processingTime
        self.metadata = metadata
    }
}

/// Metadata for agent operations
public struct AgentMetadata: Sendable {
    public let timestamp: Date
    public let tags: [String]
    public let priority: AgentPriority
    public let retryCount: Int
    public let maxRetries: Int

    public init(
        timestamp: Date = Date(),
        tags: [String] = [],
        priority: AgentPriority = .normal,
        retryCount: Int = 0,
        maxRetries: Int = 3
    ) {
        self.timestamp = timestamp
        self.tags = tags
        self.priority = priority
        self.retryCount = retryCount
        self.maxRetries = maxRetries
    }
}

/// Priority levels for agent tasks
public enum AgentPriority: Int, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: AgentPriority, rhs: AgentPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Type-erased Sendable wrapper

/// Type-erased Sendable value for heterogeneous collections
public struct AnySendable: @unchecked Sendable {
    private let _value: Any

    public init<T: Sendable>(_ value: T) {
        self._value = value
    }

    public func getValue<T>() -> T? {
        return _value as? T
    }

    public var stringValue: String? { getValue() }
    public var intValue: Int? { getValue() }
    public var doubleValue: Double? { getValue() }
    public var boolValue: Bool? { getValue() }
    public var arrayValue: [AnySendable]? { getValue() }
    public var dictValue: [String: AnySendable]? { getValue() }
}

// MARK: - Agent Protocol

/// Base protocol for all agents
public protocol Agent: Sendable {
    /// Unique identifier for this agent
    var id: String { get }

    /// Human-readable name
    var name: String { get }

    /// Agent description
    var description: String { get }

    /// Agent capabilities
    var capabilities: [AgentCapability] { get }

    /// Process input and return output
    func process(input: AgentInput) async throws -> AgentOutput

    /// Validate if agent can handle this input
    func canHandle(input: AgentInput) -> Bool
}

/// Default implementations
public extension Agent {
    var id: String { UUID().uuidString }
    var capabilities: [AgentCapability] { [] }

    func canHandle(input: AgentInput) -> Bool {
        return true
    }
}

/// Agent capabilities
public enum AgentCapability: String, Sendable, CaseIterable {
    case textGeneration
    case imageGeneration
    case documentExtraction
    case dataAnalysis
    case codeGeneration
    case search
    case reasoning
    case review
    case selfArgumentation
    case boundaryValidation
}

// MARK: - LLM Agent Protocol

/// Protocol for agents that use LLM for reasoning
public protocol LLMBasedAgent: Agent {
    /// The model to use
    var model: String { get }

    /// System instruction for the agent
    var systemInstruction: String { get }

    /// Temperature for generation
    var temperature: Double { get }

    /// Generate response using LLM
    func generate(prompt: String, context: AgentInput) async throws -> String
}

// MARK: - Workflow Agent Protocol

/// Protocol for agents that orchestrate other agents
public protocol WorkflowAgent: Agent {
    /// Child agents managed by this workflow agent
    var children: [any Agent] { get }

    /// Execute workflow with children
    func executeWorkflow(input: AgentInput) async throws -> [AgentOutput]
}

// MARK: - Tool Protocol

/// Protocol for tools that agents can use
public protocol AgentTool: Sendable {
    /// Tool identifier
    var id: String { get }

    /// Tool name
    var name: String { get }

    /// Tool description
    var description: String { get }

    /// Input schema (JSON Schema)
    var inputSchema: [String: Any] { get }

    /// Execute tool with parameters
    func execute(parameters: [String: AnySendable]) async throws -> AnySendable
}

// MARK: - Agent State

/// State management for agents
public enum AgentState: String, Sendable {
    case idle
    case processing
    case waiting
    case completed
    case failed
    case cancelled
}

/// Agent execution result
public struct AgentExecutionResult: Sendable {
    public let output: AgentOutput
    public let state: AgentState
    public let error: AgentError?
    public let childResults: [AgentExecutionResult]

    public init(
        output: AgentOutput,
        state: AgentState = .completed,
        error: AgentError? = nil,
        childResults: [AgentExecutionResult] = []
    ) {
        self.output = output
        self.state = state
        self.error = error
        self.childResults = childResults
    }
}

// MARK: - Agent Errors

/// Errors that can occur during agent execution
public enum AgentError: Error, Sendable {
    case processingFailed(String)
    case validationFailed(String)
    case timeout
    case cancelled
    case maxRetriesExceeded
    case childAgentFailed(String, Error)
    case invalidInput(String)
    case invalidOutput(String)
    case configurationError(String)

    public var localizedDescription: String {
        switch self {
        case .processingFailed(let msg): return "Processing failed: \(msg)"
        case .validationFailed(let msg): return "Validation failed: \(msg)"
        case .timeout: return "Agent execution timed out"
        case .cancelled: return "Agent execution was cancelled"
        case .maxRetriesExceeded: return "Maximum retries exceeded"
        case .childAgentFailed(let id, let err): return "Child agent \(id) failed: \(err)"
        case .invalidInput(let msg): return "Invalid input: \(msg)"
        case .invalidOutput(let msg): return "Invalid output: \(msg)"
        case .configurationError(let msg): return "Configuration error: \(msg)"
        }
    }
}
