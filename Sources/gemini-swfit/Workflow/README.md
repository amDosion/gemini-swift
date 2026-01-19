# Workflow System - Multi-Agent Architecture

A comprehensive multi-agent workflow system inspired by [Google ADK](https://google.github.io/adk-docs/) for building intelligent, self-reviewing, and self-argumentation workflows.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    WorkflowCoordinator                          │
│  (Orchestrates all agents and manages workflow execution)       │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│ SequentialAgent│     │ ParallelAgent │     │   LoopAgent   │
└───────────────┘     └───────────────┘     └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│ ReviewAgent   │     │ ContextAgent  │     │SelfArgueAgent │
│ (Quality)     │     │ (Memory)      │     │ (5+ cycles)   │
└───────────────┘     └───────────────┘     └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                              ▼
                    ┌───────────────┐
                    │BoundaryAgent  │
                    │ (Validation)  │
                    └───────────────┘
```

## Agent Types

### 1. Core Agents (ADK/)

| Agent | Purpose | File |
|-------|---------|------|
| `LLMAgent` | Base agent using LLM for reasoning | `ADK/Core/LLMAgent.swift` |
| `SequentialAgent` | Execute tasks in order | `ADK/Core/SequentialAgent.swift` |
| `ParallelAgent` | Execute tasks concurrently | `ADK/Core/ParallelAgent.swift` |
| `LoopAgent` | Iterative execution with conditions | `ADK/Core/LoopAgent.swift` |

### 2. Specialized Agents (Workflow/Agents/)

| Agent | Purpose | File |
|-------|---------|------|
| `ReviewAgent` | Quality review and validation | `Workflow/Agents/ReviewAgent.swift` |
| `ContextAgent` | Context management and memory | `Workflow/Agents/ContextAgent.swift` |
| `SelfArgueAgent` | Self-argumentation (5+ cycles) | `Workflow/Agents/SelfArgueAgent.swift` |
| `BoundaryAgent` | Input/output boundary validation | `Workflow/Agents/BoundaryAgent.swift` |
| `AnalyticsAgent` | Data analysis tasks | `Workflow/Agents/AnalyticsAgent.swift` |
| `ExtractorAgent` | Document data extraction | `Workflow/Agents/ExtractorAgent.swift` |

### 3. Domain Agents (Workflow/*)

| Agent | Purpose | Directory |
|-------|---------|-----------|
| `DataAnalyticsAgent` | E-commerce data analysis | `Workflow/Analytics/` |
| `DocumentExtractAgent` | PDF/Document extraction | `Workflow/DocumentExtract/` |
| `ECommerceAgent` | E-commerce workflows | `Workflow/ECommerce/` |

## Self-Argumentation Process (5+ Cycles)

```
Cycle 1: Initial Analysis
    ├── Generate initial response
    └── Identify key claims

Cycle 2: Counter-Argument Generation
    ├── Challenge each claim
    └── Find potential weaknesses

Cycle 3: Defense and Refinement
    ├── Defend valid claims
    └── Refine weak arguments

Cycle 4: Synthesis
    ├── Merge best arguments
    └── Resolve contradictions

Cycle 5: Final Validation
    ├── Quality score assessment
    └── Confidence calculation

Cycle 6+: (Optional) Deep Review
    ├── Edge case analysis
    └── Alternative perspectives
```

## Coordinator-Service Pattern

```swift
// Coordinator manages workflow orchestration
protocol WorkflowCoordinator {
    func execute(workflow: Workflow) async throws -> WorkflowResult
    func registerAgent(_ agent: Agent)
    func routeTask(_ task: Task) async -> Agent
}

// Services handle specific functionalities
protocol AgentService {
    func process(input: AgentInput) async throws -> AgentOutput
    func validate(output: AgentOutput) -> ValidationResult
}
```

## Usage Example

### Basic Workflow

```swift
let coordinator = WorkflowCoordinator(client: geminiClient)

// Create workflow with multiple agents
let workflow = Workflow {
    SequentialAgent {
        ExtractorAgent(document: pdfURL)
        AnalyticsAgent(analysisType: .sentiment)
        ReviewAgent(criteria: .accuracy)
    }
}

// Execute with self-argumentation
let result = try await coordinator.execute(
    workflow: workflow,
    options: .init(
        selfArgumentationCycles: 5,
        enableBoundaryCheck: true,
        enableReview: true
    )
)
```

### E-Commerce Analysis Workflow

```swift
let ecommerceWorkflow = Workflow {
    ParallelAgent {
        // Concurrent data extraction
        ExtractorAgent(source: .salesData)
        ExtractorAgent(source: .customerReviews)
        ExtractorAgent(source: .inventoryData)
    }

    SequentialAgent {
        // Analysis pipeline
        AnalyticsAgent(type: .salesTrend)
        AnalyticsAgent(type: .customerSentiment)
        AnalyticsAgent(type: .inventoryForecast)
    }

    LoopAgent(maxIterations: 5) {
        SelfArgueAgent(topic: "Market Strategy")
    }

    ReviewAgent(criteria: .comprehensive)
}

let insights = try await coordinator.execute(workflow: ecommerceWorkflow)
```

## Directory Structure

```
Workflow/
├── README.md                    # This file
├── Coordinator/
│   ├── WorkflowCoordinator.swift
│   ├── TaskRouter.swift
│   └── ResultAggregator.swift
├── Agents/
│   ├── ReviewAgent.swift
│   ├── ContextAgent.swift
│   ├── SelfArgueAgent.swift
│   ├── BoundaryAgent.swift
│   ├── AnalyticsAgent.swift
│   └── ExtractorAgent.swift
├── Tools/
│   ├── StructuredOutputTool.swift
│   ├── DocumentTool.swift
│   └── SearchTool.swift
├── Context/
│   ├── WorkflowContext.swift
│   └── ContextMemory.swift
├── Review/
│   ├── QualityReviewer.swift
│   └── ReviewCriteria.swift
├── SelfArgue/
│   ├── ArgumentationEngine.swift
│   └── ClaimValidator.swift
├── Boundary/
│   ├── InputValidator.swift
│   └── OutputValidator.swift
├── Analytics/
│   ├── DataAnalyzer.swift
│   ├── TrendAnalyzer.swift
│   └── SentimentAnalyzer.swift
├── DocumentExtract/
│   ├── PDFExtractor.swift
│   ├── TableExtractor.swift
│   └── SchemaMapper.swift
└── ECommerce/
    ├── SalesAnalyzer.swift
    ├── CustomerAnalyzer.swift
    └── InventoryAnalyzer.swift

ADK/
├── Core/
│   ├── LLMAgent.swift
│   ├── SequentialAgent.swift
│   ├── ParallelAgent.swift
│   └── LoopAgent.swift
├── Protocols/
│   ├── AgentProtocol.swift
│   ├── ToolProtocol.swift
│   └── WorkflowProtocol.swift
├── Routing/
│   ├── AgentRouter.swift
│   └── TaskDispatcher.swift
└── Execution/
    ├── ExecutionContext.swift
    └── ExecutionResult.swift
```

## File Size Constraint

All files MUST be under 500 lines. If a file grows beyond this:
1. Extract related functionality into separate files
2. Use protocol extensions in separate files
3. Split large classes into smaller, focused components

## Key Features

### 1. Structured Output (Gemini API)
- JSON Schema-based output validation
- Type-safe response parsing
- Automatic retry on schema mismatch

### 2. Document Processing
- PDF extraction up to 1000 pages
- Table and chart extraction
- Multi-modal analysis (text + images)

### 3. Deep Research
- Grounding with Google Search
- URL context extraction
- Citation generation

### 4. Performance Optimization
- Parallel execution where possible
- Caching of intermediate results
- Streaming for long operations

## Sources

- [Google ADK Documentation](https://google.github.io/adk-docs/)
- [Gemini API Structured Outputs](https://ai.google.dev/gemini-api/docs/structured-output)
- [Document Understanding](https://ai.google.dev/gemini-api/docs/document-processing)
- [Multi-Agent Systems with ADK](https://cloud.google.com/blog/products/ai-machine-learning/build-multi-agentic-systems-using-google-adk)
