//
//  WorkflowTestRunner.swift
//  gemini-swfit
//
//  Comprehensive test runner for multi-agent workflow system
//

import Foundation

/// Test runner for all workflow components
@main
struct WorkflowTestRunner {

    // MARK: - Configuration

    static let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

    // MARK: - Test Data

    static let salesData = """
    Monthly Sales Report - Q4 2024

    Product Sales Summary:
    | Product Name      | Units Sold | Revenue    | Growth |
    |-------------------|------------|------------|--------|
    | iPhone 15 Pro     | 15,234     | $15,234,000| +23%   |
    | MacBook Pro 14"   | 8,456      | $16,912,000| +15%   |
    | AirPods Pro 2     | 28,789     | $7,197,250 | +45%   |
    | iPad Pro 12.9"    | 5,123      | $5,635,300 | -8%    |
    | Apple Watch Ultra | 3,456      | $2,764,800 | +12%   |

    Regional Performance:
    - North America: $28.5M (+18%)
    - Europe: $12.3M (+22%)
    - Asia Pacific: $8.9M (+35%)
    - Other: $2.1M (+5%)

    Key Observations:
    - AirPods showing strongest growth
    - iPad Pro underperforming compared to last quarter
    - Asia Pacific emerging as fastest growing market
    - Holiday season driving increased sales volume
    """

    static let documentData = """
    INVOICE #INV-2024-12345

    From: TechCorp Solutions Inc.
    Address: 123 Innovation Drive, San Francisco, CA 94105
    Email: billing@techcorp.com
    Phone: (415) 555-0100

    Bill To:
    Customer: Acme Corporation
    Contact: John Smith
    Email: john.smith@acme.com
    Address: 456 Business Ave, New York, NY 10001

    Invoice Date: December 15, 2024
    Due Date: January 15, 2025
    Terms: Net 30

    Items:
    | Description              | Qty | Unit Price | Total      |
    |--------------------------|-----|------------|------------|
    | Enterprise License       | 1   | $50,000.00 | $50,000.00 |
    | Implementation Service   | 40  | $250.00    | $10,000.00 |
    | Training (per person)    | 25  | $500.00    | $12,500.00 |
    | Annual Support Contract  | 1   | $15,000.00 | $15,000.00 |

    Subtotal: $87,500.00
    Tax (8.5%): $7,437.50
    Total Due: $94,937.50

    Payment Methods: Wire Transfer, ACH, Credit Card
    Bank: First National Bank
    Account: 1234567890
    Routing: 021000021
    """

    static let analysisData = """
    Customer Behavior Analysis - E-commerce Platform

    User Engagement Metrics (Last 30 Days):
    - Total Active Users: 125,456
    - New Registrations: 8,234 (+12% vs last month)
    - Average Session Duration: 8.5 minutes
    - Pages per Session: 4.2
    - Bounce Rate: 35.2%

    Conversion Funnel:
    1. Homepage Visits: 500,000
    2. Product Views: 250,000 (50%)
    3. Add to Cart: 75,000 (30%)
    4. Checkout Started: 45,000 (60%)
    5. Purchase Complete: 30,000 (67%)

    Overall Conversion Rate: 6%

    Top Traffic Sources:
    - Organic Search: 40%
    - Direct: 25%
    - Social Media: 20%
    - Paid Ads: 10%
    - Email: 5%

    Customer Segments:
    - Power Users (>10 orders): 5% of users, 35% of revenue
    - Regular Users (3-10 orders): 15% of users, 40% of revenue
    - Occasional Users (1-2 orders): 30% of users, 20% of revenue
    - New Users: 50% of users, 5% of revenue

    Anomalies Detected:
    - Unusual spike in cart abandonment on mobile (Dec 10-12)
    - Payment gateway errors increased 200% on Dec 11
    - Significant drop in email open rates (from 25% to 15%)
    """

    // MARK: - Main

    static func main() async {
        print("""
        ╔══════════════════════════════════════════════════════════════════╗
        ║          Multi-Agent Workflow System Test Runner                 ║
        ║                    gemini-swift ADK                              ║
        ╚══════════════════════════════════════════════════════════════════╝

        """)

        guard let client = GeminiClient(apiKeys: [apiKey]) else {
            print("❌ Failed to initialize GeminiClient")
            return
        }

        print("✅ GeminiClient initialized successfully\n")

        // Run all tests
        await runAllTests(client: client)
    }

    static func runAllTests(client: GeminiClient) async {
        print("Select a test to run:")
        print("1. Test Individual Agents")
        print("2. Test Sales Analysis Workflow")
        print("3. Test Document Extraction Workflow")
        print("4. Test Data Analysis Workflow")
        print("5. Test Self-Argumentation Agent")
        print("6. Test Review Agent")
        print("7. Test Complete E-Commerce Pipeline")
        print("8. Run All Tests")
        print("0. Exit\n")

        print("Running all tests automatically...\n")

        // Test 1: Individual Agents
        await testIndividualAgents(client: client)

        // Test 2: Sales Analysis
        await testSalesAnalysisWorkflow(client: client)

        // Test 3: Document Extraction
        await testDocumentExtractionWorkflow(client: client)

        // Test 4: Data Analysis
        await testDataAnalysisWorkflow(client: client)

        // Test 5: Self-Argumentation
        await testSelfArgumentation(client: client)

        // Test 6: Review Agent
        await testReviewAgent(client: client)

        // Test 7: Complete Pipeline
        await testCompleteECommercePipeline(client: client)

        print("""

        ╔══════════════════════════════════════════════════════════════════╗
        ║                    All Tests Completed                           ║
        ╚══════════════════════════════════════════════════════════════════╝
        """)
    }

    // MARK: - Test 1: Individual Agents

    static func testIndividualAgents(client: GeminiClient) async {
        printTestHeader("Test 1: Individual Agents")

        // Test BoundaryAgent
        print("\n📋 Testing BoundaryAgent...")
        let boundary = BoundaryAgent(client: client)
        let boundaryInput = AgentInput(
            id: UUID().uuidString,
            content: "Test input for validation: Hello, this is a sample text."
        )

        do {
            let result = try await boundary.process(input: boundaryInput)
            print("✅ BoundaryAgent: Validation completed")
            print("   Confidence: \(result.confidence)")
            printOutputPreview(result.content)
        } catch {
            print("❌ BoundaryAgent failed: \(error)")
        }

        // Test ContextAgent
        print("\n📋 Testing ContextAgent...")
        let context = ContextAgent(client: client)

        do {
            let result = try await context.process(input: boundaryInput)
            print("✅ ContextAgent: Context processed")
            print("   Confidence: \(result.confidence)")
            printOutputPreview(result.content)
        } catch {
            print("❌ ContextAgent failed: \(error)")
        }

        print("\n✅ Individual Agents Test Complete\n")
    }

    // MARK: - Test 2: Sales Analysis Workflow

    static func testSalesAnalysisWorkflow(client: GeminiClient) async {
        printTestHeader("Test 2: Sales Analysis Workflow")

        let salesAnalyzer = SalesAnalyzerAgent(client: client)
        let input = AgentInput(
            id: UUID().uuidString,
            content: salesData
        )

        print("\n📊 Analyzing sales data...")

        do {
            let result = try await salesAnalyzer.process(input: input)
            print("✅ Sales Analysis completed")
            print("   Confidence: \(result.confidence)")
            print("   Processing Time: \(String(format: "%.2f", result.processingTime))s")
            printOutputPreview(result.content, maxLines: 30)

            if let data = result.structuredData {
                print("\n   Structured Data:")
                for (key, value) in data {
                    print("   - \(key): \(value.stringValue ?? "N/A")")
                }
            }
        } catch {
            print("❌ Sales Analysis failed: \(error)")
        }

        print("\n✅ Sales Analysis Workflow Test Complete\n")
    }

    // MARK: - Test 3: Document Extraction Workflow

    static func testDocumentExtractionWorkflow(client: GeminiClient) async {
        printTestHeader("Test 3: Document Extraction Workflow")

        let extractor = DocumentExtractorAgent(client: client)
        let input = AgentInput(
            id: UUID().uuidString,
            content: documentData
        )

        print("\n📄 Extracting data from document...")

        do {
            let result = try await extractor.process(input: input)
            print("✅ Document Extraction completed")
            print("   Confidence: \(result.confidence)")
            print("   Processing Time: \(String(format: "%.2f", result.processingTime))s")
            printOutputPreview(result.content, maxLines: 40)

            if let data = result.structuredData {
                print("\n   Structured Data:")
                for (key, value) in data {
                    print("   - \(key): \(value.stringValue ?? "N/A")")
                }
            }
        } catch {
            print("❌ Document Extraction failed: \(error)")
        }

        print("\n✅ Document Extraction Workflow Test Complete\n")
    }

    // MARK: - Test 4: Data Analysis Workflow

    static func testDataAnalysisWorkflow(client: GeminiClient) async {
        printTestHeader("Test 4: Data Analysis Workflow")

        let analyzer = DataAnalyzerAgent(client: client)
        let trendAnalyzer = TrendAnalyzerAgent(client: client)

        let input = AgentInput(
            id: UUID().uuidString,
            content: analysisData
        )

        print("\n📈 Running data analysis...")

        do {
            let result = try await analyzer.process(input: input)
            print("✅ Data Analysis completed")
            print("   Confidence: \(result.confidence)")
            printOutputPreview(result.content, maxLines: 25)
        } catch {
            print("❌ Data Analysis failed: \(error)")
        }

        print("\n📈 Running trend analysis...")

        do {
            let result = try await trendAnalyzer.process(input: input)
            print("✅ Trend Analysis completed")
            print("   Confidence: \(result.confidence)")
            printOutputPreview(result.content, maxLines: 25)
        } catch {
            print("❌ Trend Analysis failed: \(error)")
        }

        print("\n✅ Data Analysis Workflow Test Complete\n")
    }

    // MARK: - Test 5: Self-Argumentation

    static func testSelfArgumentation(client: GeminiClient) async {
        printTestHeader("Test 5: Self-Argumentation Agent (5+ Cycles)")

        let selfArgue = SelfArgueAgent(
            client: client,
            minCycles: 5,
            confidenceThreshold: 0.85
        )

        let topic = """
        Should e-commerce businesses prioritize mobile app development over
        responsive web design? Consider factors like user engagement,
        development costs, maintenance, and market reach.
        """

        let input = AgentInput(
            id: UUID().uuidString,
            content: topic
        )

        print("\n🤔 Starting self-argumentation process...")
        print("   Topic: \(topic.prefix(100))...\n")

        do {
            let result = try await selfArgue.process(input: input)
            print("✅ Self-Argumentation completed")
            print("   Final Confidence: \(result.confidence)")
            print("   Processing Time: \(String(format: "%.2f", result.processingTime))s")
            printOutputPreview(result.content, maxLines: 50)

            if let data = result.structuredData {
                if let cycles = data["total_cycles"]?.intValue {
                    print("\n   Total Argumentation Cycles: \(cycles)")
                }
            }
        } catch {
            print("❌ Self-Argumentation failed: \(error)")
        }

        print("\n✅ Self-Argumentation Test Complete\n")
    }

    // MARK: - Test 6: Review Agent

    static func testReviewAgent(client: GeminiClient) async {
        printTestHeader("Test 6: Review Agent")

        let reviewer = ReviewAgent(client: client)

        let contentToReview = """
        Analysis Summary:
        Based on the Q4 sales data, we recommend:
        1. Increase marketing spend on AirPods Pro 2 by 30%
        2. Launch promotional campaign for iPad Pro
        3. Expand presence in Asia Pacific region
        4. Implement mobile app improvements

        These recommendations are expected to drive 15-20% growth in Q1 2025.
        """

        let input = AgentInput(
            id: UUID().uuidString,
            content: "Review the following analysis recommendations for accuracy and completeness."
        )
        let inputWithPrevious = AgentInput(
            id: input.id,
            content: input.content,
            context: input.context,
            metadata: input.metadata,
            previousOutputs: [
                AgentOutput(
                    agentId: "previous_agent",
                    content: contentToReview,
                    confidence: 0.8,
                    processingTime: 1.0
                )
            ]
        )

        print("\n🔍 Running quality review...")

        do {
            let result = try await reviewer.process(input: inputWithPrevious)
            print("✅ Review completed")
            print("   Confidence: \(result.confidence)")
            printOutputPreview(result.content, maxLines: 30)
        } catch {
            print("❌ Review failed: \(error)")
        }

        print("\n✅ Review Agent Test Complete\n")
    }

    // MARK: - Test 7: Complete E-Commerce Pipeline

    static func testCompleteECommercePipeline(client: GeminiClient) async {
        printTestHeader("Test 7: Complete E-Commerce Analysis Pipeline")

        let coordinator = WorkflowCoordinator(client: client)

        // Register all agents
        let contextAgent = ContextAgent(client: client)
        let salesAnalyzer = SalesAnalyzerAgent(client: client)
        let trendAnalyzer = TrendAnalyzerAgent(client: client)
        let reviewer = ReviewAgent(client: client)

        coordinator.register(agents: [
            contextAgent,
            salesAnalyzer,
            trendAnalyzer,
            reviewer
        ])

        // Create workflow using factory
        let factory = WorkflowFactory(client: client)
        var workflow = factory.ecommerceInsights()
        workflow = Workflow(
            id: workflow.id,
            name: workflow.name,
            description: workflow.description,
            steps: workflow.steps,
            initialInput: AgentInput(
                id: UUID().uuidString,
                content: salesData + "\n\n" + analysisData
            )
        )

        print("\n🔄 Running complete e-commerce analysis pipeline...")
        print("   Steps: \(workflow.steps.count)")

        // Subscribe to events
        coordinator.onEvent { event in
            switch event {
            case .stepStarted(_, let stepId):
                print("   ▶️ Started: \(stepId)")
            case .stepCompleted(_, let stepId, let output):
                print("   ✅ Completed: \(stepId) (confidence: \(String(format: "%.2f", output.confidence)))")
            case .stepFailed(_, let stepId, let error):
                print("   ❌ Failed: \(stepId) - \(error)")
            default:
                break
            }
        }

        do {
            let result = try await coordinator.execute(workflow: workflow)
            print("\n✅ Pipeline completed successfully!")
            print("   Status: \(result.status)")
            print("   Total Processing Time: \(String(format: "%.2f", result.totalProcessingTime))s")
            print("   Overall Confidence: \(String(format: "%.2f", result.confidence))")
            print("   Outputs Generated: \(result.outputs.count)")

            print("\n📊 Final Output Preview:")
            printOutputPreview(result.finalOutput, maxLines: 40)

        } catch {
            print("❌ Pipeline failed: \(error)")
        }

        print("\n✅ Complete E-Commerce Pipeline Test Complete\n")
    }

    // MARK: - Helper Methods

    static func printTestHeader(_ title: String) {
        print("""

        ┌──────────────────────────────────────────────────────────────────┐
        │ \(title.padding(toLength: 64, withPad: " ", startingAt: 0)) │
        └──────────────────────────────────────────────────────────────────┘
        """)
    }

    static func printOutputPreview(_ content: String, maxLines: Int = 15) {
        let lines = content.components(separatedBy: "\n")
        let preview = lines.prefix(maxLines)
        print("\n   Output Preview:")
        print("   " + String(repeating: "-", count: 60))
        for line in preview {
            print("   \(line)")
        }
        if lines.count > maxLines {
            print("   ... (\(lines.count - maxLines) more lines)")
        }
        print("   " + String(repeating: "-", count: 60))
    }
}

// MARK: - Extensions for Testing

extension AnySendable {
    var stringValue: String? {
        if let str = value as? String {
            return str
        }
        if let num = value as? Double {
            return String(format: "%.2f", num)
        }
        if let num = value as? Int {
            return String(num)
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        return nil
    }

    var intValue: Int? {
        if let num = value as? Int {
            return num
        }
        if let num = value as? Double {
            return Int(num)
        }
        return nil
    }
}
