//
//  SalesAnalyzer.swift
//  gemini-swfit
//
//  Agent for e-commerce sales analysis
//

import Foundation
import SwiftyBeaver

/// Agent specialized in e-commerce sales data analysis
public final class SalesAnalyzerAgent: Agent, @unchecked Sendable {

    // MARK: - Types

    /// Sales analysis configuration
    public struct AnalysisConfig: Sendable {
        public let timeframe: Timeframe
        public let metrics: [SalesMetric]
        public let segmentation: [Segmentation]
        public let includeComparison: Bool

        public enum Timeframe: String, Sendable {
            case daily = "Daily"
            case weekly = "Weekly"
            case monthly = "Monthly"
            case quarterly = "Quarterly"
            case yearly = "Yearly"
            case custom = "Custom"
        }

        public enum SalesMetric: String, Sendable {
            case revenue = "Revenue"
            case units = "Units Sold"
            case averageOrderValue = "Average Order Value"
            case conversionRate = "Conversion Rate"
            case customerAcquisitionCost = "CAC"
            case customerLifetimeValue = "CLV"
            case returnRate = "Return Rate"
            case profitMargin = "Profit Margin"
        }

        public enum Segmentation: String, Sendable {
            case product = "By Product"
            case category = "By Category"
            case region = "By Region"
            case channel = "By Channel"
            case customer = "By Customer Segment"
            case time = "By Time Period"
        }

        public init(
            timeframe: Timeframe = .monthly,
            metrics: [SalesMetric] = [.revenue, .units, .averageOrderValue],
            segmentation: [Segmentation] = [.product, .category],
            includeComparison: Bool = true
        ) {
            self.timeframe = timeframe
            self.metrics = metrics
            self.segmentation = segmentation
            self.includeComparison = includeComparison
        }
    }

    /// Sales analysis result
    public struct SalesAnalysisResult: Sendable {
        public let summary: SalesSummary
        public let topPerformers: TopPerformers
        public let underperformers: [UnderperformerItem]
        public let trends: [SalesTrend]
        public let recommendations: [Recommendation]
        public let confidence: Double

        public struct SalesSummary: Sendable {
            public let totalRevenue: String
            public let totalUnits: Int
            public let averageOrderValue: String
            public let periodComparison: String
            public let growthRate: Double
        }

        public struct TopPerformers: Sendable {
            public let products: [PerformerItem]
            public let categories: [PerformerItem]
            public let regions: [PerformerItem]
        }

        public struct PerformerItem: Sendable {
            public let name: String
            public let value: String
            public let growth: Double
            public let sharePercent: Double
        }

        public struct UnderperformerItem: Sendable {
            public let name: String
            public let value: String
            public let decline: Double
            public let issue: String
            public let suggestedAction: String
        }

        public struct SalesTrend: Sendable {
            public let metric: String
            public let direction: String
            public let magnitude: Double
            public let insight: String
        }

        public struct Recommendation: Sendable {
            public let priority: Priority
            public let action: String
            public let expectedImpact: String
            public let effort: String

            public enum Priority: String, Sendable {
                case high = "High"
                case medium = "Medium"
                case low = "Low"
            }
        }
    }

    // MARK: - Properties

    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]

    private let client: GeminiClient
    private let logger: SwiftyBeaver.Type
    private let config: AnalysisConfig

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String = "Sales Analyzer",
        client: GeminiClient,
        config: AnalysisConfig = AnalysisConfig(),
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = "Analyzes e-commerce sales data for insights"
        self.capabilities = [.dataAnalysis, .reasoning]
        self.client = client
        self.config = config
        self.logger = logger
    }

    // MARK: - Agent Protocol

    public func canHandle(input: AgentInput) -> Bool {
        return !input.content.isEmpty
    }

    public func process(input: AgentInput) async throws -> AgentOutput {
        let startTime = Date()
        logger.info("[\(name)] Starting sales analysis (\(config.timeframe.rawValue))")

        let result = try await analyzeSalesData(input: input)

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("[\(name)] Analysis completed with \(result.recommendations.count) recommendations")

        return buildOutput(from: result, processingTime: processingTime)
    }

    // MARK: - Analysis Methods

    private func analyzeSalesData(input: AgentInput) async throws -> SalesAnalysisResult {
        let prompt = buildAnalysisPrompt(for: input)
        let response = try await generateWithLLM(prompt: prompt)

        return parseAnalysisResult(response)
    }

    private func buildAnalysisPrompt(for input: AgentInput) -> String {
        let metricsStr = config.metrics.map { $0.rawValue }.joined(separator: ", ")
        let segmentStr = config.segmentation.map { $0.rawValue }.joined(separator: ", ")

        return """
        Analyze the following e-commerce sales data:

        Analysis Configuration:
        - Timeframe: \(config.timeframe.rawValue)
        - Key Metrics: \(metricsStr)
        - Segmentation: \(segmentStr)
        - Include Period Comparison: \(config.includeComparison)

        Sales Data:
        \(input.content.prefix(8000))

        Provide comprehensive analysis in the following format:

        SUMMARY:
        Total Revenue: [amount with currency]
        Total Units: [number]
        Average Order Value: [amount]
        Period Comparison: [vs previous period]
        Growth Rate: [percentage as decimal, e.g., 0.15 for 15%]

        TOP_PRODUCTS:
        - Name: [product name] | Value: [revenue] | Growth: [0.X] | Share: [0.X]

        TOP_CATEGORIES:
        - Name: [category name] | Value: [revenue] | Growth: [0.X] | Share: [0.X]

        TOP_REGIONS:
        - Name: [region name] | Value: [revenue] | Growth: [0.X] | Share: [0.X]

        UNDERPERFORMERS:
        - Name: [item name] | Value: [revenue] | Decline: [0.X] | Issue: [problem] | Action: [suggested action]

        TRENDS:
        - Metric: [metric name] | Direction: [up/down/stable] | Magnitude: [0.X] | Insight: [description]

        RECOMMENDATIONS:
        - Priority: [high/medium/low] | Action: [what to do] | Impact: [expected result] | Effort: [low/medium/high]

        CONFIDENCE: [0.X]
        """
    }

    private func parseAnalysisResult(_ response: String) -> SalesAnalysisResult {
        // Parse SUMMARY
        var summary = SalesAnalysisResult.SalesSummary(
            totalRevenue: "$0",
            totalUnits: 0,
            averageOrderValue: "$0",
            periodComparison: "N/A",
            growthRate: 0.0
        )

        if let range = response.range(of: "SUMMARY:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")

            var revenue = "$0"
            var units = 0
            var aov = "$0"
            var comparison = "N/A"
            var growth = 0.0

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("Total Revenue:") {
                    revenue = trimmed.replacingOccurrences(of: "Total Revenue:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("Total Units:") {
                    if let u = Int(trimmed.filter { $0.isNumber }) {
                        units = u
                    }
                } else if trimmed.hasPrefix("Average Order Value:") {
                    aov = trimmed.replacingOccurrences(of: "Average Order Value:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("Period Comparison:") {
                    comparison = trimmed.replacingOccurrences(of: "Period Comparison:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("Growth Rate:") {
                    if let g = Double(trimmed.filter { $0.isNumber || $0 == "." || $0 == "-" }) {
                        growth = g
                    }
                } else if trimmed.contains("TOP_PRODUCTS:") {
                    break
                }
            }

            summary = SalesAnalysisResult.SalesSummary(
                totalRevenue: revenue,
                totalUnits: units,
                averageOrderValue: aov,
                periodComparison: comparison,
                growthRate: growth
            )
        }

        // Parse TOP_PRODUCTS
        let products = parsePerformers(response, section: "TOP_PRODUCTS:")

        // Parse TOP_CATEGORIES
        let categories = parsePerformers(response, section: "TOP_CATEGORIES:")

        // Parse TOP_REGIONS
        let regions = parsePerformers(response, section: "TOP_REGIONS:")

        let topPerformers = SalesAnalysisResult.TopPerformers(
            products: products,
            categories: categories,
            regions: regions
        )

        // Parse UNDERPERFORMERS
        var underperformers: [SalesAnalysisResult.UnderperformerItem] = []
        if let range = response.range(of: "UNDERPERFORMERS:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- Name:") || trimmed.hasPrefix("-Name:") {
                    if let item = parseUnderperformer(trimmed) {
                        underperformers.append(item)
                    }
                } else if trimmed.contains("TRENDS:") {
                    break
                }
            }
        }

        // Parse TRENDS
        var trends: [SalesAnalysisResult.SalesTrend] = []
        if let range = response.range(of: "TRENDS:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- Metric:") || trimmed.hasPrefix("-Metric:") {
                    if let trend = parseTrend(trimmed) {
                        trends.append(trend)
                    }
                } else if trimmed.contains("RECOMMENDATIONS:") {
                    break
                }
            }
        }

        // Parse RECOMMENDATIONS
        var recommendations: [SalesAnalysisResult.Recommendation] = []
        if let range = response.range(of: "RECOMMENDATIONS:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- Priority:") || trimmed.hasPrefix("-Priority:") {
                    if let rec = parseRecommendation(trimmed) {
                        recommendations.append(rec)
                    }
                } else if trimmed.contains("CONFIDENCE:") {
                    break
                }
            }
        }

        // Parse CONFIDENCE
        var confidence = 0.75
        if let range = response.range(of: "CONFIDENCE:") {
            let after = response[range.upperBound...].prefix(10)
            if let parsed = Double(after.filter { $0.isNumber || $0 == "." }) {
                confidence = min(1.0, max(0.0, parsed))
            }
        }

        return SalesAnalysisResult(
            summary: summary,
            topPerformers: topPerformers,
            underperformers: underperformers,
            trends: trends,
            recommendations: recommendations,
            confidence: confidence
        )
    }

    private func parsePerformers(
        _ response: String,
        section: String
    ) -> [SalesAnalysisResult.PerformerItem] {
        var performers: [SalesAnalysisResult.PerformerItem] = []

        guard let range = response.range(of: section) else { return performers }

        let after = response[range.upperBound...]
        let lines = after.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- Name:") || trimmed.hasPrefix("-Name:") {
                let parts = trimmed.components(separatedBy: " | ")
                var name = ""
                var value = "$0"
                var growth = 0.0
                var share = 0.0

                for part in parts {
                    let p = part.trimmingCharacters(in: .whitespaces)
                    if p.contains("Name:") {
                        name = p.replacingOccurrences(of: "- Name:", with: "")
                            .replacingOccurrences(of: "-Name:", with: "")
                            .replacingOccurrences(of: "Name:", with: "")
                            .trimmingCharacters(in: .whitespaces)
                    } else if p.contains("Value:") {
                        value = p.replacingOccurrences(of: "Value:", with: "")
                            .trimmingCharacters(in: .whitespaces)
                    } else if p.contains("Growth:") {
                        if let g = Double(p.filter { $0.isNumber || $0 == "." || $0 == "-" }) {
                            growth = g
                        }
                    } else if p.contains("Share:") {
                        if let s = Double(p.filter { $0.isNumber || $0 == "." }) {
                            share = s
                        }
                    }
                }

                if !name.isEmpty {
                    performers.append(SalesAnalysisResult.PerformerItem(
                        name: name,
                        value: value,
                        growth: growth,
                        sharePercent: share
                    ))
                }
            } else if trimmed.contains(":") && !trimmed.hasPrefix("-") {
                break
            }
        }

        return performers
    }

    private func parseUnderperformer(_ line: String) -> SalesAnalysisResult.UnderperformerItem? {
        let parts = line.components(separatedBy: " | ")
        var name = ""
        var value = "$0"
        var decline = 0.0
        var issue = ""
        var action = ""

        for part in parts {
            let p = part.trimmingCharacters(in: .whitespaces)
            if p.contains("Name:") {
                name = p.replacingOccurrences(of: "- Name:", with: "")
                    .replacingOccurrences(of: "Name:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if p.contains("Value:") {
                value = p.replacingOccurrences(of: "Value:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if p.contains("Decline:") {
                if let d = Double(p.filter { $0.isNumber || $0 == "." }) {
                    decline = d
                }
            } else if p.contains("Issue:") {
                issue = p.replacingOccurrences(of: "Issue:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if p.contains("Action:") {
                action = p.replacingOccurrences(of: "Action:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        guard !name.isEmpty else { return nil }

        return SalesAnalysisResult.UnderperformerItem(
            name: name,
            value: value,
            decline: decline,
            issue: issue,
            suggestedAction: action
        )
    }

    private func parseTrend(_ line: String) -> SalesAnalysisResult.SalesTrend? {
        let parts = line.components(separatedBy: " | ")
        var metric = ""
        var direction = ""
        var magnitude = 0.0
        var insight = ""

        for part in parts {
            let p = part.trimmingCharacters(in: .whitespaces)
            if p.contains("Metric:") {
                metric = p.replacingOccurrences(of: "- Metric:", with: "")
                    .replacingOccurrences(of: "Metric:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if p.contains("Direction:") {
                direction = p.replacingOccurrences(of: "Direction:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if p.contains("Magnitude:") {
                if let m = Double(p.filter { $0.isNumber || $0 == "." }) {
                    magnitude = m
                }
            } else if p.contains("Insight:") {
                insight = p.replacingOccurrences(of: "Insight:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        guard !metric.isEmpty else { return nil }

        return SalesAnalysisResult.SalesTrend(
            metric: metric,
            direction: direction,
            magnitude: magnitude,
            insight: insight
        )
    }

    private func parseRecommendation(_ line: String) -> SalesAnalysisResult.Recommendation? {
        let parts = line.components(separatedBy: " | ")
        var priority: SalesAnalysisResult.Recommendation.Priority = .medium
        var action = ""
        var impact = ""
        var effort = ""

        for part in parts {
            let p = part.trimmingCharacters(in: .whitespaces).lowercased()
            if p.contains("priority:") {
                if p.contains("high") {
                    priority = .high
                } else if p.contains("low") {
                    priority = .low
                }
            } else if part.contains("Action:") {
                action = part.replacingOccurrences(of: "Action:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if part.contains("Impact:") {
                impact = part.replacingOccurrences(of: "Impact:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if part.contains("Effort:") {
                effort = part.replacingOccurrences(of: "Effort:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        guard !action.isEmpty else { return nil }

        return SalesAnalysisResult.Recommendation(
            priority: priority,
            action: action,
            expectedImpact: impact,
            effort: effort
        )
    }

    // MARK: - Helper Methods

    private func generateWithLLM(prompt: String) async throws -> String {
        let response = try await client.generateContent(
            model: .gemini25Pro,
            prompt: prompt,
            generationConfig: GeminiClient.GenerationConfig(temperature: 0.3)
        )

        guard let text = response.text else {
            throw AgentError.processingFailed("No response from LLM")
        }

        return text
    }

    private func buildOutput(
        from result: SalesAnalysisResult,
        processingTime: TimeInterval
    ) -> AgentOutput {
        let growthIcon = result.summary.growthRate >= 0 ? "📈" : "📉"

        var content = """
        ## Sales Analysis Report \(growthIcon)

        ### Executive Summary
        - **Total Revenue:** \(result.summary.totalRevenue)
        - **Total Units Sold:** \(result.summary.totalUnits)
        - **Average Order Value:** \(result.summary.averageOrderValue)
        - **Growth Rate:** \(String(format: "%.1f%%", result.summary.growthRate * 100))
        - **Period Comparison:** \(result.summary.periodComparison)

        ### Top Performers

        #### 🏆 Top Products
        """

        for (index, product) in result.topPerformers.products.prefix(5).enumerated() {
            let growthStr = product.growth >= 0 ? "+\(String(format: "%.1f", product.growth * 100))%" : "\(String(format: "%.1f", product.growth * 100))%"
            content += "\n\(index + 1). **\(product.name)** - \(product.value) (\(growthStr))"
        }

        content += "\n\n#### 📦 Top Categories\n"
        for category in result.topPerformers.categories.prefix(5) {
            content += "\n- **\(category.name)** - \(category.value) (Share: \(String(format: "%.1f%%", category.sharePercent * 100)))"
        }

        if !result.underperformers.isEmpty {
            content += "\n\n### ⚠️ Underperformers Requiring Attention\n"
            for item in result.underperformers.prefix(5) {
                content += "\n- **\(item.name)** (\(item.value), -\(String(format: "%.1f%%", item.decline * 100)))"
                content += "\n  Issue: \(item.issue)"
                content += "\n  Action: \(item.suggestedAction)"
            }
        }

        if !result.trends.isEmpty {
            content += "\n\n### Key Trends\n"
            for trend in result.trends {
                let icon = trend.direction.lowercased() == "up" ? "⬆️" : (trend.direction.lowercased() == "down" ? "⬇️" : "➡️")
                content += "\n- \(icon) **\(trend.metric)**: \(trend.insight)"
            }
        }

        if !result.recommendations.isEmpty {
            content += "\n\n### 💡 Recommendations\n"
            for rec in result.recommendations {
                let priorityIcon = rec.priority == .high ? "🔴" : (rec.priority == .medium ? "🟡" : "🟢")
                content += "\n\(priorityIcon) **[\(rec.priority.rawValue)]** \(rec.action)"
                if !rec.expectedImpact.isEmpty {
                    content += "\n   Expected Impact: \(rec.expectedImpact)"
                }
            }
        }

        var structuredData: [String: AnySendable] = [:]
        structuredData["total_revenue"] = AnySendable(result.summary.totalRevenue)
        structuredData["total_units"] = AnySendable(result.summary.totalUnits)
        structuredData["growth_rate"] = AnySendable(result.summary.growthRate)
        structuredData["recommendations_count"] = AnySendable(result.recommendations.count)

        return AgentOutput(
            agentId: id,
            content: content,
            structuredData: structuredData,
            confidence: result.confidence,
            processingTime: processingTime
        )
    }
}
