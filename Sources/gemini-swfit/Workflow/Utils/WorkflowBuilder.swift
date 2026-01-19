//
//  WorkflowBuilder.swift
//  gemini-swfit
//
//  Utilities for building and composing workflows
//

import Foundation

// MARK: - Workflow Factory

/// Factory for creating common workflow patterns
public struct WorkflowFactory {

    private let client: GeminiClient

    public init(client: GeminiClient) {
        self.client = client
    }

    // MARK: - Predefined Workflows

    /// Create a document analysis workflow
    public func documentAnalysis(
        includeExtraction: Bool = true,
        includeReview: Bool = true
    ) -> Workflow {
        var agents: [any Agent] = []

        // Boundary validation
        agents.append(BoundaryAgent(client: client))

        // Document extraction
        if includeExtraction {
            agents.append(DocumentExtractorAgent(client: client))
        }

        // Data analysis
        agents.append(DataAnalyzerAgent(client: client))

        // Review
        if includeReview {
            agents.append(ReviewAgent(client: client))
        }

        let steps = agents.enumerated().map { index, agent in
            WorkflowStep(
                id: "step_\(index)",
                name: agent.name,
                agent: agent
            )
        }

        return Workflow(
            name: "Document Analysis Workflow",
            description: "Analyzes documents for insights and structured data",
            steps: steps
        )
    }

    /// Create a sales analysis workflow
    public func salesAnalysis(
        includeTrends: Bool = true,
        includeRecommendations: Bool = true
    ) -> Workflow {
        var agents: [any Agent] = []

        // Context management
        agents.append(ContextAgent(client: client))

        // Sales analysis
        agents.append(SalesAnalyzerAgent(client: client))

        // Trend analysis
        if includeTrends {
            agents.append(TrendAnalyzerAgent(client: client))
        }

        // Self-argumentation for recommendations
        if includeRecommendations {
            agents.append(SelfArgueAgent(client: client, minCycles: 3))
        }

        // Review
        agents.append(ReviewAgent(client: client))

        let steps = agents.enumerated().map { index, agent in
            WorkflowStep(
                id: "step_\(index)",
                name: agent.name,
                agent: agent
            )
        }

        return Workflow(
            name: "Sales Analysis Workflow",
            description: "Comprehensive sales data analysis with trends and recommendations",
            steps: steps
        )
    }

    /// Create a quality assurance workflow
    public func qualityAssurance(cycles: Int = 3) -> Workflow {
        let reviewer = ReviewAgent(client: client)
        let selfArgue = SelfArgueAgent(
            client: client,
            minCycles: cycles
        )

        let steps = [
            WorkflowStep(
                id: "initial_review",
                name: "Initial Review",
                agent: reviewer
            ),
            WorkflowStep(
                id: "self_argumentation",
                name: "Self-Argumentation",
                agent: selfArgue
            ),
            WorkflowStep(
                id: "final_review",
                name: "Final Review",
                agent: ReviewAgent.codeReview(client: client)
            )
        ]

        return Workflow(
            name: "Quality Assurance Workflow",
            description: "Multi-stage review with self-argumentation",
            steps: steps
        )
    }

    /// Create an e-commerce insights workflow
    public func ecommerceInsights() -> Workflow {
        let steps = [
            WorkflowStep(
                id: "boundary",
                name: "Input Validation",
                agent: BoundaryAgent(client: client)
            ),
            WorkflowStep(
                id: "sales",
                name: "Sales Analysis",
                agent: SalesAnalyzerAgent(client: client)
            ),
            WorkflowStep(
                id: "trends",
                name: "Trend Analysis",
                agent: TrendAnalyzerAgent(client: client)
            ),
            WorkflowStep(
                id: "review",
                name: "Quality Review",
                agent: ReviewAgent(client: client)
            )
        ]

        return Workflow(
            name: "E-Commerce Insights Workflow",
            description: "Complete e-commerce data analysis pipeline",
            steps: steps
        )
    }
}

// MARK: - Workflow Composer

/// Utility for composing workflows from agents
public struct WorkflowComposer {

    private var steps: [WorkflowStep] = []
    private var name: String = "Custom Workflow"
    private var description: String = ""
    private var initialInput: AgentInput?

    public init() {}

    // MARK: - Builder Methods

    public mutating func named(_ name: String) -> WorkflowComposer {
        self.name = name
        return self
    }

    public mutating func described(_ description: String) -> WorkflowComposer {
        self.description = description
        return self
    }

    public mutating func withInput(_ input: AgentInput) -> WorkflowComposer {
        self.initialInput = input
        return self
    }

    public mutating func withInput(_ content: String) -> WorkflowComposer {
        self.initialInput = AgentInput(id: UUID().uuidString, content: content)
        return self
    }

    public mutating func addStep(
        _ agent: any Agent,
        name: String? = nil,
        condition: WorkflowCondition? = nil,
        isRequired: Bool = true
    ) -> WorkflowComposer {
        let step = WorkflowStep(
            id: "step_\(steps.count)",
            name: name ?? agent.name,
            agent: agent,
            condition: condition,
            isRequired: isRequired
        )
        steps.append(step)
        return self
    }

    public mutating func addSequential(_ agents: [any Agent]) -> WorkflowComposer {
        for agent in agents {
            _ = addStep(agent)
        }
        return self
    }

    public mutating func addConditional(
        _ agent: any Agent,
        when condition: WorkflowCondition
    ) -> WorkflowComposer {
        return addStep(agent, condition: condition)
    }

    public mutating func addOptional(_ agent: any Agent) -> WorkflowComposer {
        return addStep(agent, isRequired: false)
    }

    // MARK: - Build

    public func build() -> Workflow {
        return Workflow(
            name: name,
            description: description,
            steps: steps,
            initialInput: initialInput
        )
    }
}

// MARK: - Agent Chain Builder

/// DSL for building agent chains
public struct AgentChain {

    private var agents: [any Agent] = []

    public init() {}

    public init(_ agents: any Agent...) {
        self.agents = agents
    }

    public mutating func then(_ agent: any Agent) -> AgentChain {
        agents.append(agent)
        return self
    }

    public mutating func thenParallel(_ agents: [any Agent]) -> AgentChain {
        let parallel = ParallelAgent(
            name: "Parallel Stage",
            children: agents
        )
        self.agents.append(parallel)
        return self
    }

    public mutating func thenLoop(
        _ agent: any Agent,
        iterations: Int
    ) -> AgentChain {
        let loop = LoopAgent(
            name: "Loop Stage",
            children: [agent],
            maxIterations: iterations,
            exitCondition: .iterations(iterations)
        )
        agents.append(loop)
        return self
    }

    public func toSequential() -> SequentialAgent {
        return SequentialAgent(
            name: "Agent Chain",
            children: agents
        )
    }

    public func toWorkflow(name: String = "Agent Chain Workflow") -> Workflow {
        let steps = agents.enumerated().map { index, agent in
            WorkflowStep(
                id: "step_\(index)",
                name: agent.name,
                agent: agent
            )
        }
        return Workflow(name: name, steps: steps)
    }
}

// MARK: - Quick Workflow Builders

public extension Workflow {
    /// Create a simple sequential workflow
    static func sequential(
        name: String,
        agents: [any Agent]
    ) -> Workflow {
        let steps = agents.enumerated().map { index, agent in
            WorkflowStep(
                id: "step_\(index)",
                name: agent.name,
                agent: agent
            )
        }
        return Workflow(name: name, steps: steps)
    }

    /// Create a workflow with parallel execution
    static func parallel(
        name: String,
        agents: [any Agent]
    ) -> Workflow {
        let parallelAgent = ParallelAgent(children: agents)
        return Workflow(
            name: name,
            steps: [WorkflowStep(
                id: "parallel_step",
                name: "Parallel Execution",
                agent: parallelAgent
            )]
        )
    }

    /// Create a loop workflow
    static func loop(
        name: String,
        agent: any Agent,
        iterations: Int
    ) -> Workflow {
        let loopAgent = LoopAgent(
            children: [agent],
            maxIterations: iterations,
            exitCondition: .iterations(iterations)
        )
        return Workflow(
            name: name,
            steps: [WorkflowStep(
                id: "loop_step",
                name: "Loop Execution",
                agent: loopAgent
            )]
        )
    }
}

// MARK: - Workflow Templates

/// Predefined workflow templates
public enum WorkflowTemplate {

    /// Basic analysis template
    case analysis(depth: AnalysisDepth)

    /// Document processing template
    case documentProcessing(extractEntities: Bool, extractTables: Bool)

    /// Sales analytics template
    case salesAnalytics(timeframe: String)

    /// Quality review template
    case qualityReview(cycles: Int)

    /// Custom template
    case custom(steps: [WorkflowStep])

    public enum AnalysisDepth {
        case quick
        case standard
        case comprehensive
    }

    /// Build the workflow from template
    public func build(client: GeminiClient) -> Workflow {
        switch self {
        case .analysis(let depth):
            return buildAnalysisWorkflow(client: client, depth: depth)

        case .documentProcessing(let entities, let tables):
            return buildDocumentWorkflow(
                client: client,
                extractEntities: entities,
                extractTables: tables
            )

        case .salesAnalytics(let timeframe):
            return buildSalesWorkflow(client: client, timeframe: timeframe)

        case .qualityReview(let cycles):
            return buildReviewWorkflow(client: client, cycles: cycles)

        case .custom(let steps):
            return Workflow(name: "Custom Workflow", steps: steps)
        }
    }

    private func buildAnalysisWorkflow(
        client: GeminiClient,
        depth: AnalysisDepth
    ) -> Workflow {
        var agents: [any Agent] = [
            BoundaryAgent(client: client),
            DataAnalyzerAgent(client: client)
        ]

        if depth == .comprehensive {
            agents.append(TrendAnalyzerAgent(client: client))
            agents.append(ReviewAgent(client: client))
        }

        return Workflow.sequential(name: "Analysis Workflow", agents: agents)
    }

    private func buildDocumentWorkflow(
        client: GeminiClient,
        extractEntities: Bool,
        extractTables: Bool
    ) -> Workflow {
        var config = DocumentExtractorAgent.ExtractionConfig()

        if extractEntities && extractTables {
            config = DocumentExtractorAgent.ExtractionConfig(
                extractionType: .comprehensive
            )
        } else if extractEntities {
            config = DocumentExtractorAgent.ExtractionConfig(
                extractionType: .entities
            )
        } else if extractTables {
            config = DocumentExtractorAgent.ExtractionConfig(
                extractionType: .tables
            )
        }

        let agents: [any Agent] = [
            BoundaryAgent(client: client),
            DocumentExtractorAgent(client: client, config: config),
            ReviewAgent.documentReview(client: client)
        ]

        return Workflow.sequential(name: "Document Processing", agents: agents)
    }

    private func buildSalesWorkflow(
        client: GeminiClient,
        timeframe: String
    ) -> Workflow {
        let agents: [any Agent] = [
            ContextAgent(client: client),
            SalesAnalyzerAgent(client: client),
            TrendAnalyzerAgent(client: client),
            ReviewAgent(client: client)
        ]

        return Workflow.sequential(name: "Sales Analytics (\(timeframe))", agents: agents)
    }

    private func buildReviewWorkflow(
        client: GeminiClient,
        cycles: Int
    ) -> Workflow {
        let selfArgue = SelfArgueAgent(
            client: client,
            minCycles: cycles
        )

        let agents: [any Agent] = [
            ReviewAgent(client: client),
            selfArgue,
            ReviewAgent(client: client)
        ]

        return Workflow.sequential(name: "Quality Review (\(cycles) cycles)", agents: agents)
    }
}
