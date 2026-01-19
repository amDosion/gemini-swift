//
//  WorkflowCoordinator.swift
//  gemini-swfit
//
//  Central coordinator for managing workflow execution
//

import Foundation
import SwiftyBeaver

/// Central coordinator that orchestrates workflow execution following Coordinator-Service pattern
public final class WorkflowCoordinator: @unchecked Sendable {

    // MARK: - Types

    /// Coordinator configuration
    public struct Configuration: Sendable {
        public let maxConcurrentWorkflows: Int
        public let defaultTimeout: TimeInterval
        public let enableMetrics: Bool
        public let enableBoundaryValidation: Bool
        public let retryPolicy: RetryPolicy

        public init(
            maxConcurrentWorkflows: Int = 5,
            defaultTimeout: TimeInterval = 300,
            enableMetrics: Bool = true,
            enableBoundaryValidation: Bool = true,
            retryPolicy: RetryPolicy = RetryPolicy()
        ) {
            self.maxConcurrentWorkflows = maxConcurrentWorkflows
            self.defaultTimeout = defaultTimeout
            self.enableMetrics = enableMetrics
            self.enableBoundaryValidation = enableBoundaryValidation
            self.retryPolicy = retryPolicy
        }
    }

    /// Workflow execution state
    public enum ExecutionState: Sendable {
        case pending
        case running
        case paused
        case completed
        case failed(Error)
        case cancelled
    }

    /// Workflow execution context
    public struct ExecutionContext: Sendable {
        public let workflowId: String
        public let startTime: Date
        public var state: ExecutionState
        public var currentStep: Int
        public var outputs: [AgentOutput]
        public var metrics: ExecutionMetrics

        public init(workflowId: String) {
            self.workflowId = workflowId
            self.startTime = Date()
            self.state = .pending
            self.currentStep = 0
            self.outputs = []
            self.metrics = ExecutionMetrics()
        }
    }

    /// Metrics for workflow execution
    public struct ExecutionMetrics: Sendable {
        public var totalSteps: Int = 0
        public var completedSteps: Int = 0
        public var failedSteps: Int = 0
        public var totalProcessingTime: TimeInterval = 0
        public var stepTimes: [String: TimeInterval] = [:]
        public var retryCount: Int = 0
    }

    // MARK: - Properties

    private let client: GeminiClient
    private let configuration: Configuration
    private let logger: SwiftyBeaver.Type

    private let executionQueue = DispatchQueue(
        label: "com.gemini.workflow.coordinator",
        attributes: .concurrent
    )
    private var activeContexts: [String: ExecutionContext] = [:]
    private var registeredAgents: [String: any Agent] = [:]
    private var eventHandlers: [(WorkflowEvent) -> Void] = []

    // Core agents
    private var boundaryAgent: BoundaryAgent?
    private var contextAgent: ContextAgent?
    private var reviewAgent: ReviewAgent?

    // MARK: - Initialization

    public init(
        client: GeminiClient,
        configuration: Configuration = Configuration(),
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.client = client
        self.configuration = configuration
        self.logger = logger

        // Initialize core agents if enabled
        if configuration.enableBoundaryValidation {
            self.boundaryAgent = BoundaryAgent(client: client)
        }
        self.contextAgent = ContextAgent(client: client)
        self.reviewAgent = ReviewAgent(client: client)
    }

    // MARK: - Agent Registration

    /// Register an agent with the coordinator
    public func register(agent: any Agent) {
        executionQueue.async(flags: .barrier) { [weak self] in
            self?.registeredAgents[agent.id] = agent
        }
        logger.info("[Coordinator] Registered agent: \(agent.name)")
    }

    /// Register multiple agents
    public func register(agents: [any Agent]) {
        for agent in agents {
            register(agent: agent)
        }
    }

    /// Get a registered agent by ID
    public func getAgent(id: String) -> (any Agent)? {
        executionQueue.sync {
            registeredAgents[id]
        }
    }

    // MARK: - Workflow Execution

    /// Execute a workflow
    public func execute(workflow: Workflow) async throws -> WorkflowResult {
        let workflowId = workflow.id
        logger.info("[Coordinator] Starting workflow: \(workflow.name)")

        // Create execution context
        var context = ExecutionContext(workflowId: workflowId)
        context.metrics.totalSteps = workflow.steps.count

        // Store context
        updateContext(workflowId: workflowId, context: context)

        // Emit start event
        emitEvent(.workflowStarted(workflowId))

        do {
            // Execute workflow steps
            let outputs = try await executeSteps(
                workflow: workflow,
                context: &context
            )

            // Update final state
            context.state = .completed
            context.outputs = outputs
            updateContext(workflowId: workflowId, context: context)

            // Emit completion event
            emitEvent(.workflowCompleted(workflowId))

            return buildResult(workflow: workflow, context: context, outputs: outputs)

        } catch {
            // Update failed state
            context.state = .failed(error)
            updateContext(workflowId: workflowId, context: context)

            // Emit failure event
            emitEvent(.workflowFailed(workflowId, error))

            throw error
        }
    }

    /// Execute a simple agent chain
    public func executeChain(
        _ agents: [any Agent],
        input: AgentInput,
        name: String = "Agent Chain"
    ) async throws -> WorkflowResult {
        let steps = agents.enumerated().map { index, agent in
            WorkflowStep(
                id: "step_\(index)",
                name: agent.name,
                agent: agent
            )
        }

        let workflow = Workflow(
            name: name,
            steps: steps
        )

        return try await execute(workflow: workflow)
    }

    // MARK: - Step Execution

    private func executeSteps(
        workflow: Workflow,
        context: inout ExecutionContext
    ) async throws -> [AgentOutput] {
        var outputs: [AgentOutput] = []
        var currentInput = workflow.initialInput ?? AgentInput(
            id: UUID().uuidString,
            content: ""
        )

        // Validate input if boundary agent is enabled
        if let boundary = boundaryAgent {
            let validatedOutput = try await boundary.process(input: currentInput)
            logger.debug("[Coordinator] Input validation: \(validatedOutput.confidence)")
        }

        // Process context
        if let contextMgr = contextAgent {
            let contextOutput = try await contextMgr.process(input: currentInput)
            logger.debug("[Coordinator] Context processed: \(contextOutput.content.prefix(100))")
        }

        context.state = .running
        updateContext(workflowId: workflow.id, context: context)

        for (index, step) in workflow.steps.enumerated() {
            context.currentStep = index
            updateContext(workflowId: workflow.id, context: context)

            logger.info("[Coordinator] Executing step \(index + 1)/\(workflow.steps.count): \(step.name)")
            emitEvent(.stepStarted(workflow.id, step.id))

            let stepStartTime = Date()

            do {
                // Check conditions
                if let condition = step.condition {
                    let shouldExecute = evaluateCondition(condition, outputs: outputs)
                    if !shouldExecute {
                        logger.info("[Coordinator] Skipping step \(step.name) - condition not met")
                        continue
                    }
                }

                // Execute with retry
                let output = try await executeWithRetry(
                    step: step,
                    input: currentInput,
                    retryPolicy: step.retryPolicy ?? configuration.retryPolicy
                )

                outputs.append(output)

                // Update metrics
                let stepTime = Date().timeIntervalSince(stepStartTime)
                context.metrics.stepTimes[step.id] = stepTime
                context.metrics.completedSteps += 1
                context.metrics.totalProcessingTime += stepTime

                // Update input for next step
                currentInput = AgentInput(
                    id: UUID().uuidString,
                    content: currentInput.content,
                    context: mergeContext(currentInput.context, output),
                    metadata: currentInput.metadata,
                    previousOutputs: outputs
                )

                emitEvent(.stepCompleted(workflow.id, step.id, output))

            } catch {
                context.metrics.failedSteps += 1
                emitEvent(.stepFailed(workflow.id, step.id, error))

                if step.isRequired {
                    throw WorkflowError.stepFailed(step.id, error)
                }

                logger.warning("[Coordinator] Optional step \(step.name) failed: \(error)")
            }
        }

        // Review output if review agent is enabled
        if let reviewer = reviewAgent, !outputs.isEmpty {
            let reviewInput = AgentInput(
                id: UUID().uuidString,
                content: workflow.initialInput?.content ?? "",
                previousOutputs: outputs
            )
            let reviewOutput = try await reviewer.process(input: reviewInput)
            logger.info("[Coordinator] Review completed: \(reviewOutput.confidence)")
        }

        return outputs
    }

    private func executeWithRetry(
        step: WorkflowStep,
        input: AgentInput,
        retryPolicy: RetryPolicy
    ) async throws -> AgentOutput {
        var lastError: Error?
        var attempt = 0

        while attempt <= retryPolicy.maxRetries {
            do {
                guard step.agent.canHandle(input: input) else {
                    throw AgentError.invalidInput("Agent cannot handle input")
                }

                return try await withTimeout(
                    seconds: step.timeout ?? configuration.defaultTimeout
                ) {
                    try await step.agent.process(input: input)
                }

            } catch {
                lastError = error
                attempt += 1

                if attempt <= retryPolicy.maxRetries {
                    let delay = calculateRetryDelay(
                        attempt: attempt,
                        policy: retryPolicy
                    )
                    logger.warning("[Coordinator] Step \(step.name) failed, retrying in \(delay)s")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? AgentError.processingFailed("Unknown error")
    }

    // MARK: - Workflow Control

    /// Pause a running workflow
    public func pause(workflowId: String) {
        executionQueue.async(flags: .barrier) { [weak self] in
            if var context = self?.activeContexts[workflowId] {
                if case .running = context.state {
                    context.state = .paused
                    self?.activeContexts[workflowId] = context
                }
            }
        }
        emitEvent(.workflowPaused(workflowId))
    }

    /// Resume a paused workflow
    public func resume(workflowId: String) {
        executionQueue.async(flags: .barrier) { [weak self] in
            if var context = self?.activeContexts[workflowId] {
                if case .paused = context.state {
                    context.state = .running
                    self?.activeContexts[workflowId] = context
                }
            }
        }
        emitEvent(.workflowResumed(workflowId))
    }

    /// Cancel a workflow
    public func cancel(workflowId: String) {
        executionQueue.async(flags: .barrier) { [weak self] in
            if var context = self?.activeContexts[workflowId] {
                context.state = .cancelled
                self?.activeContexts[workflowId] = context
            }
        }
        emitEvent(.workflowCancelled(workflowId))
    }

    /// Get workflow status
    public func getStatus(workflowId: String) -> ExecutionContext? {
        executionQueue.sync {
            activeContexts[workflowId]
        }
    }

    // MARK: - Event Handling

    /// Subscribe to workflow events
    public func onEvent(_ handler: @escaping (WorkflowEvent) -> Void) {
        executionQueue.async(flags: .barrier) { [weak self] in
            self?.eventHandlers.append(handler)
        }
    }

    private func emitEvent(_ event: WorkflowEvent) {
        let handlers = executionQueue.sync { eventHandlers }
        for handler in handlers {
            handler(event)
        }
    }

    // MARK: - Helper Methods

    private func updateContext(workflowId: String, context: ExecutionContext) {
        executionQueue.async(flags: .barrier) { [weak self] in
            self?.activeContexts[workflowId] = context
        }
    }

    private func evaluateCondition(
        _ condition: WorkflowCondition,
        outputs: [AgentOutput]
    ) -> Bool {
        switch condition {
        case .always:
            return true

        case .confidenceAbove(let threshold):
            guard let lastOutput = outputs.last else { return true }
            return lastOutput.confidence >= threshold

        case .outputContains(let text):
            guard let lastOutput = outputs.last else { return true }
            return lastOutput.content.contains(text)

        case .previousSuccess:
            return !outputs.isEmpty

        case .custom:
            return true // Custom conditions need external evaluation
        }
    }

    private func calculateRetryDelay(attempt: Int, policy: RetryPolicy) -> TimeInterval {
        switch policy.backoffStrategy {
        case .fixed:
            return policy.initialDelay

        case .linear:
            return policy.initialDelay * Double(attempt)

        case .exponential:
            return policy.initialDelay * pow(2.0, Double(attempt - 1))

        case .jitter:
            let baseDelay = policy.initialDelay * pow(2.0, Double(attempt - 1))
            let jitter = Double.random(in: 0...1) * baseDelay * 0.3
            return baseDelay + jitter
        }
    }

    private func mergeContext(
        _ context: [String: AnySendable],
        _ output: AgentOutput
    ) -> [String: AnySendable] {
        var merged = context
        merged["last_agent_id"] = AnySendable(output.agentId)
        merged["last_confidence"] = AnySendable(output.confidence)

        if let data = output.structuredData {
            for (key, value) in data {
                merged["output_\(key)"] = value
            }
        }

        return merged
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw WorkflowError.timeout(seconds)
            }

            guard let result = try await group.next() else {
                throw WorkflowError.timeout(seconds)
            }

            group.cancelAll()
            return result
        }
    }

    private func buildResult(
        workflow: Workflow,
        context: ExecutionContext,
        outputs: [AgentOutput]
    ) -> WorkflowResult {
        let finalOutput = outputs.last?.content ?? ""
        let avgConfidence = outputs.isEmpty ? 0.0 :
            outputs.reduce(0.0) { $0 + $1.confidence } / Double(outputs.count)

        return WorkflowResult(
            workflowId: workflow.id,
            status: .completed,
            outputs: outputs,
            finalOutput: finalOutput,
            confidence: avgConfidence,
            totalProcessingTime: context.metrics.totalProcessingTime,
            metadata: [
                "total_steps": AnySendable(context.metrics.totalSteps),
                "completed_steps": AnySendable(context.metrics.completedSteps),
                "failed_steps": AnySendable(context.metrics.failedSteps),
                "retry_count": AnySendable(context.metrics.retryCount)
            ]
        )
    }
}

// MARK: - Workflow Error

public enum WorkflowError: Error, Sendable {
    case stepFailed(String, Error)
    case timeout(TimeInterval)
    case cancelled
    case invalidWorkflow(String)
    case agentNotFound(String)
}

// MARK: - Builder Extension

public extension WorkflowCoordinator {
    /// Create a workflow using builder pattern
    func createWorkflow(
        name: String,
        @WorkflowBuilder steps: () -> [WorkflowStep]
    ) -> Workflow {
        Workflow(name: name, steps: steps())
    }

    /// Quick execution of a single agent
    func execute(
        agent: any Agent,
        input: String
    ) async throws -> AgentOutput {
        let agentInput = AgentInput(id: UUID().uuidString, content: input)
        return try await agent.process(input: agentInput)
    }
}
