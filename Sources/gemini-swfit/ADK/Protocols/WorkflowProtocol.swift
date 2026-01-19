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

    public init(
        id: String = UUID().uuidString,
        name: String = "Unnamed Workflow",
        description: String = "",
        steps: [WorkflowStep] = [],
        options: WorkflowOptions = .default
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
        self.options = options
    }
}

/// A single step in a workflow
public struct WorkflowStep: Sendable {
    public let id: String
    public let name: String
    public let agentId: String
    public let inputs: [String: AnySendable]
    public let dependsOn: [String]
    public let condition: WorkflowCondition?

    public init(
        id: String = UUID().uuidString,
        name: String,
        agentId: String,
        inputs: [String: AnySendable] = [:],
        dependsOn: [String] = [],
        condition: WorkflowCondition? = nil
    ) {
        self.id = id
        self.name = name
        self.agentId = agentId
        self.inputs = inputs
        self.dependsOn = dependsOn
        self.condition = condition
    }
}

/// Condition for workflow step execution
public struct WorkflowCondition: Sendable {
    public let expression: String
    public let type: ConditionType

    public enum ConditionType: String, Sendable {
        case always
        case ifPreviousSuccess
        case ifPreviousFailed
        case custom
    }

    public init(expression: String = "", type: ConditionType = .always) {
        self.expression = expression
        self.type = type
    }

    public static let always = WorkflowCondition(type: .always)
    public static let ifSuccess = WorkflowCondition(type: .ifPreviousSuccess)
    public static let ifFailed = WorkflowCondition(type: .ifPreviousFailed)
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
    public let multiplier: Double

    public init(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        multiplier: Double = 2.0
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
    }

    public static let `default` = RetryPolicy()
    public static let aggressive = RetryPolicy(maxRetries: 5, multiplier: 1.5)
    public static let none = RetryPolicy(maxRetries: 0)

    public func delay(for attempt: Int) -> TimeInterval {
        let delay = initialDelay * pow(multiplier, Double(attempt))
        return min(delay, maxDelay)
    }
}

// MARK: - Workflow Result

/// Result of workflow execution
public struct WorkflowResult: Sendable {
    public let workflowId: String
    public let status: WorkflowStatus
    public let outputs: [String: AgentOutput]
    public let finalOutput: AgentOutput?
    public let executionTime: TimeInterval
    public let metadata: WorkflowResultMetadata

    public init(
        workflowId: String,
        status: WorkflowStatus,
        outputs: [String: AgentOutput] = [:],
        finalOutput: AgentOutput? = nil,
        executionTime: TimeInterval = 0,
        metadata: WorkflowResultMetadata = .init()
    ) {
        self.workflowId = workflowId
        self.status = status
        self.outputs = outputs
        self.finalOutput = finalOutput
        self.executionTime = executionTime
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

/// Metadata for workflow results
public struct WorkflowResultMetadata: Sendable {
    public let stepsCompleted: Int
    public let stepsFailed: Int
    public let argumentationCycles: Int
    public let reviewScore: Double?
    public let boundaryViolations: [String]

    public init(
        stepsCompleted: Int = 0,
        stepsFailed: Int = 0,
        argumentationCycles: Int = 0,
        reviewScore: Double? = nil,
        boundaryViolations: [String] = []
    ) {
        self.stepsCompleted = stepsCompleted
        self.stepsFailed = stepsFailed
        self.argumentationCycles = argumentationCycles
        self.reviewScore = reviewScore
        self.boundaryViolations = boundaryViolations
    }
}

// MARK: - Workflow Events

/// Events emitted during workflow execution
public enum WorkflowEvent: Sendable {
    case started(workflowId: String)
    case stepStarted(stepId: String, agentId: String)
    case stepCompleted(stepId: String, output: AgentOutput)
    case stepFailed(stepId: String, error: String)
    case argumentationCycleCompleted(cycle: Int, result: String)
    case reviewCompleted(score: Double)
    case boundaryCheckCompleted(violations: [String])
    case completed(result: WorkflowResult)
    case failed(error: String)
    case cancelled
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
        @WorkflowBuilder steps: () -> [WorkflowStep]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps()
        self.options = options
    }
}
