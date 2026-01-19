//
//  WorkflowProtocol.swift
//  gemini-swfit
//
//  Protocols for workflow definition and execution
//

import Foundation

// MARK: - Workflow Definition

/// A workflow represents a sequence of agent operations
public struct Workflow: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let steps: [WorkflowStep]
    public let options: WorkflowOptions
    public let initialInput: AgentInput?

    public init(
        id: String = UUID().uuidString,
        name: String = "Unnamed Workflow",
        description: String = "",
        steps: [WorkflowStep] = [],
        options: WorkflowOptions = .default,
        initialInput: AgentInput? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
        self.options = options
        self.initialInput = initialInput
    }
}

/// A single step in a workflow
public struct WorkflowStep: @unchecked Sendable {
    public let id: String
    public let name: String
    public let agent: any Agent
    public let inputs: [String: AnySendable]
    public let dependsOn: [String]
    public let condition: WorkflowCondition?
    public let isRequired: Bool
    public let timeout: TimeInterval?
    public let retryPolicy: RetryPolicy?

    public init(
        id: String = UUID().uuidString,
        name: String,
        agent: any Agent,
        inputs: [String: AnySendable] = [:],
        dependsOn: [String] = [],
        condition: WorkflowCondition? = nil,
        isRequired: Bool = true,
        timeout: TimeInterval? = nil,
        retryPolicy: RetryPolicy? = nil
    ) {
        self.id = id
        self.name = name
        self.agent = agent
        self.inputs = inputs
        self.dependsOn = dependsOn
        self.condition = condition
        self.isRequired = isRequired
        self.timeout = timeout
        self.retryPolicy = retryPolicy
    }
}

/// Condition for workflow step execution
public enum WorkflowCondition: Sendable {
    case always
    case confidenceAbove(Double)
    case outputContains(String)
    case previousSuccess
    case custom(String)
}

// MARK: - Workflow Options

/// Configuration options for workflow execution
public struct WorkflowOptions: Sendable {
    public let selfArgumentationCycles: Int
    public let enableBoundaryCheck: Bool
    public let enableReview: Bool
    public let enableContextMemory: Bool
    public let maxParallelAgents: Int
    public let timeout: TimeInterval
    public let retryPolicy: RetryPolicy

    public init(
        selfArgumentationCycles: Int = 5,
        enableBoundaryCheck: Bool = true,
        enableReview: Bool = true,
        enableContextMemory: Bool = true,
        maxParallelAgents: Int = 5,
        timeout: TimeInterval = 300,
        retryPolicy: RetryPolicy = .default
    ) {
        self.selfArgumentationCycles = selfArgumentationCycles
        self.enableBoundaryCheck = enableBoundaryCheck
        self.enableReview = enableReview
        self.enableContextMemory = enableContextMemory
        self.maxParallelAgents = maxParallelAgents
        self.timeout = timeout
        self.retryPolicy = retryPolicy
    }

    public static let `default` = WorkflowOptions()

    public static let minimal = WorkflowOptions(
        selfArgumentationCycles: 0,
        enableBoundaryCheck: false,
        enableReview: false,
        enableContextMemory: false
    )

    public static let comprehensive = WorkflowOptions(
        selfArgumentationCycles: 7,
        enableBoundaryCheck: true,
        enableReview: true,
        enableContextMemory: true,
        maxParallelAgents: 10,
        timeout: 600
    )
}

/// Retry policy for failed operations
public struct RetryPolicy: Sendable {
    public let maxRetries: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffStrategy: BackoffStrategy

    public enum BackoffStrategy: Sendable {
        case fixed
        case linear
        case exponential
        case jitter
    }

    public init(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffStrategy: BackoffStrategy = .exponential
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffStrategy = backoffStrategy
    }

    public static let `default` = RetryPolicy()
    public static let aggressive = RetryPolicy(maxRetries: 5, backoffStrategy: .linear)
    public static let none = RetryPolicy(maxRetries: 0)

    public func delay(for attempt: Int) -> TimeInterval {
        switch backoffStrategy {
        case .fixed:
            return initialDelay
        case .linear:
            return initialDelay * Double(attempt)
        case .exponential:
            return min(initialDelay * pow(2.0, Double(attempt - 1)), maxDelay)
        case .jitter:
            let base = initialDelay * pow(2.0, Double(attempt - 1))
            let jitter = Double.random(in: 0...1) * base * 0.3
            return min(base + jitter, maxDelay)
        }
    }
}

// MARK: - Workflow Result

/// Result of workflow execution
public struct WorkflowResult: Sendable {
    public let workflowId: String
    public let status: WorkflowStatus
    public let outputs: [AgentOutput]
    public let finalOutput: String
    public let confidence: Double
    public let totalProcessingTime: TimeInterval
    public let metadata: [String: AnySendable]

    public init(
        workflowId: String,
        status: WorkflowStatus,
        outputs: [AgentOutput] = [],
        finalOutput: String = "",
        confidence: Double = 0.0,
        totalProcessingTime: TimeInterval = 0,
        metadata: [String: AnySendable] = [:]
    ) {
        self.workflowId = workflowId
        self.status = status
        self.outputs = outputs
        self.finalOutput = finalOutput
        self.confidence = confidence
        self.totalProcessingTime = totalProcessingTime
        self.metadata = metadata
    }
}

/// Workflow execution status
public enum WorkflowStatus: String, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled
    case timedOut
}

// MARK: - Workflow Events

/// Events emitted during workflow execution
public enum WorkflowEvent: Sendable {
    case workflowStarted(String)
    case workflowCompleted(String)
    case workflowFailed(String, String) // workflowId, errorMessage
    case workflowPaused(String)
    case workflowResumed(String)
    case workflowCancelled(String)
    case stepStarted(String, String) // workflowId, stepId
    case stepCompleted(String, String, AgentOutput) // workflowId, stepId, output
    case stepFailed(String, String, String) // workflowId, stepId, errorMessage
}

/// Protocol for workflow event handling
public protocol WorkflowEventHandler: Sendable {
    func handle(event: WorkflowEvent) async
}

// MARK: - Workflow Builder (DSL Support)

/// Builder pattern for creating workflows
@resultBuilder
public struct WorkflowBuilder {
    public static func buildBlock(_ steps: WorkflowStep...) -> [WorkflowStep] {
        return steps
    }

    public static func buildOptional(_ component: [WorkflowStep]?) -> [WorkflowStep] {
        return component ?? []
    }

    public static func buildEither(first component: [WorkflowStep]) -> [WorkflowStep] {
        return component
    }

    public static func buildEither(second component: [WorkflowStep]) -> [WorkflowStep] {
        return component
    }

    public static func buildArray(_ components: [[WorkflowStep]]) -> [WorkflowStep] {
        return components.flatMap { $0 }
    }
}

/// Extension for Workflow with builder
public extension Workflow {
    init(
        id: String = UUID().uuidString,
        name: String = "Unnamed Workflow",
        description: String = "",
        options: WorkflowOptions = .default,
        initialInput: AgentInput? = nil,
        @WorkflowBuilder steps: () -> [WorkflowStep]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps()
        self.options = options
        self.initialInput = initialInput
    }
}
