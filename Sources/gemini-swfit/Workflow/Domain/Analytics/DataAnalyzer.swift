//
//  DataAnalyzer.swift
//  gemini-swfit
//
//  Agent for general data analysis and insights extraction
//

import Foundation
import SwiftyBeaver

/// Agent specialized in data analysis and pattern recognition
public final class DataAnalyzerAgent: Agent, @unchecked Sendable {

    // MARK: - Types

    /// Analysis configuration
    public struct AnalysisConfig: Sendable {
        public let analysisType: AnalysisType
        public let depth: AnalysisDepth
        public let outputFormat: OutputFormat
        public let includeVisualizations: Bool

        public enum AnalysisType: String, Sendable {
            case descriptive = "Descriptive Statistics"
            case diagnostic = "Diagnostic Analysis"
            case predictive = "Predictive Analysis"
            case prescriptive = "Prescriptive Analysis"
            case comprehensive = "Comprehensive Analysis"
        }

        public enum AnalysisDepth: String, Sendable {
            case quick = "Quick Overview"
            case standard = "Standard Analysis"
            case deep = "Deep Analysis"
        }

        public enum OutputFormat: String, Sendable {
            case summary = "Summary"
            case detailed = "Detailed Report"
            case actionable = "Actionable Insights"
            case technical = "Technical Report"
        }

        public init(
            analysisType: AnalysisType = .comprehensive,
            depth: AnalysisDepth = .standard,
            outputFormat: OutputFormat = .actionable,
            includeVisualizations: Bool = false
        ) {
            self.analysisType = analysisType
            self.depth = depth
            self.outputFormat = outputFormat
            self.includeVisualizations = includeVisualizations
        }
    }

    /// Analysis result
    public struct AnalysisResult: Sendable {
        public let summary: String
        public let keyMetrics: [Metric]
        public let patterns: [Pattern]
        public let anomalies: [Anomaly]
        public let recommendations: [String]
        public let confidence: Double

        public struct Metric: Sendable {
            public let name: String
            public let value: String
            public let trend: Trend?
            public let importance: Double
        }

        public struct Pattern: Sendable {
            public let description: String
            public let significance: Double
            public let affectedData: String
        }

        public struct Anomaly: Sendable {
            public let description: String
            public let severity: Severity
            public let suggestedAction: String

            public enum Severity: String, Sendable {
                case low = "Low"
                case medium = "Medium"
                case high = "High"
                case critical = "Critical"
            }
        }

        public enum Trend: String, Sendable {
            case increasing = "↑ Increasing"
            case decreasing = "↓ Decreasing"
            case stable = "→ Stable"
            case volatile = "↕ Volatile"
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
        name: String = "Data Analyzer",
        client: GeminiClient,
        config: AnalysisConfig = AnalysisConfig(),
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = "Analyzes data and extracts meaningful insights"
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
        logger.info("[\(name)] Starting \(config.analysisType.rawValue)")

        let result = try await analyzeData(input: input)

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("[\(name)] Analysis completed with confidence: \(result.confidence)")

        return buildOutput(from: result, processingTime: processingTime)
    }

    // MARK: - Analysis Methods

    private func analyzeData(input: AgentInput) async throws -> AnalysisResult {
        let prompt = buildAnalysisPrompt(for: input)
        let response = try await generateWithLLM(prompt: prompt)

        return parseAnalysisResult(response)
    }

    private func buildAnalysisPrompt(for input: AgentInput) -> String {
        return """
        Perform \(config.analysisType.rawValue) on the following data:

        Analysis Depth: \(config.depth.rawValue)
        Output Format: \(config.outputFormat.rawValue)

        Data to Analyze:
        \(input.content.prefix(8000))

        \(getContextInstructions(input))

        Provide your analysis in the following format:

        SUMMARY:
        [Brief summary of key findings]

        KEY_METRICS:
        - [Metric Name]: [Value] | Trend: [increasing/decreasing/stable] | Importance: [0.X]
        - [Metric Name]: [Value] | Trend: [N/A] | Importance: [0.X]

        PATTERNS:
        - Pattern: [Description] | Significance: [0.X] | Affected: [data description]

        ANOMALIES:
        - Anomaly: [Description] | Severity: [low/medium/high/critical] | Action: [suggested action]

        RECOMMENDATIONS:
        - [Recommendation 1]
        - [Recommendation 2]

        CONFIDENCE: [0.X]
        """
    }

    private func getContextInstructions(_ input: AgentInput) -> String {
        var instructions: [String] = []

        if !input.previousOutputs.isEmpty {
            instructions.append("Consider previous analysis context:")
            for output in input.previousOutputs.suffix(2) {
                instructions.append("- \(output.content.prefix(500))")
            }
        }

        if let dataType = input.context["data_type"]?.stringValue {
            instructions.append("Data Type: \(dataType)")
        }

        return instructions.joined(separator: "\n")
    }

    private func parseAnalysisResult(_ response: String) -> AnalysisResult {
        // Parse SUMMARY
        var summary = ""
        if let range = response.range(of: "SUMMARY:") {
            let after = response[range.upperBound...]
            if let end = after.range(of: "\nKEY_METRICS:") {
                summary = String(after[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Parse KEY_METRICS
        var metrics: [AnalysisResult.Metric] = []
        if let range = response.range(of: "KEY_METRICS:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("-") {
                    if let metric = parseMetric(line) {
                        metrics.append(metric)
                    }
                } else if line.contains("PATTERNS:") {
                    break
                }
            }
        }

        // Parse PATTERNS
        var patterns: [AnalysisResult.Pattern] = []
        if let range = response.range(of: "PATTERNS:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("-") {
                    if let pattern = parsePattern(line) {
                        patterns.append(pattern)
                    }
                } else if line.contains("ANOMALIES:") {
                    break
                }
            }
        }

        // Parse ANOMALIES
        var anomalies: [AnalysisResult.Anomaly] = []
        if let range = response.range(of: "ANOMALIES:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("-") {
                    if let anomaly = parseAnomaly(line) {
                        anomalies.append(anomaly)
                    }
                } else if line.contains("RECOMMENDATIONS:") {
                    break
                }
            }
        }

        // Parse RECOMMENDATIONS
        var recommendations: [String] = []
        if let range = response.range(of: "RECOMMENDATIONS:") {
            let after = response[range.upperBound...]
            let lines = after.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("-") {
                    recommendations.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
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

        return AnalysisResult(
            summary: summary.isEmpty ? "Analysis completed" : summary,
            keyMetrics: metrics,
            patterns: patterns,
            anomalies: anomalies,
            recommendations: recommendations,
            confidence: confidence
        )
    }

    private func parseMetric(_ line: String) -> AnalysisResult.Metric? {
        let content = line.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "- ", with: "")

        let parts = content.components(separatedBy: " | ")
        guard parts.count >= 1 else { return nil }

        let nameValue = parts[0].components(separatedBy: ": ")
        let name = nameValue.first ?? "Unknown"
        let value = nameValue.count > 1 ? nameValue[1] : ""

        var trend: AnalysisResult.Trend? = nil
        var importance = 0.5

        for part in parts.dropFirst() {
            if part.lowercased().contains("trend:") {
                let trendStr = part.lowercased()
                if trendStr.contains("increasing") {
                    trend = .increasing
                } else if trendStr.contains("decreasing") {
                    trend = .decreasing
                } else if trendStr.contains("stable") {
                    trend = .stable
                } else if trendStr.contains("volatile") {
                    trend = .volatile
                }
            } else if part.lowercased().contains("importance:") {
                if let imp = Double(part.filter { $0.isNumber || $0 == "." }) {
                    importance = min(1.0, max(0.0, imp))
                }
            }
        }

        return AnalysisResult.Metric(
            name: name,
            value: value,
            trend: trend,
            importance: importance
        )
    }

    private func parsePattern(_ line: String) -> AnalysisResult.Pattern? {
        let content = line.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "- Pattern: ", with: "")
            .replacingOccurrences(of: "- ", with: "")

        let parts = content.components(separatedBy: " | ")
        let description = parts.first ?? ""

        var significance = 0.5
        var affected = ""

        for part in parts.dropFirst() {
            if part.lowercased().contains("significance:") {
                if let sig = Double(part.filter { $0.isNumber || $0 == "." }) {
                    significance = min(1.0, max(0.0, sig))
                }
            } else if part.lowercased().contains("affected:") {
                affected = part.replacingOccurrences(of: "Affected:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return AnalysisResult.Pattern(
            description: description,
            significance: significance,
            affectedData: affected
        )
    }

    private func parseAnomaly(_ line: String) -> AnalysisResult.Anomaly? {
        let content = line.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "- Anomaly: ", with: "")
            .replacingOccurrences(of: "- ", with: "")

        let parts = content.components(separatedBy: " | ")
        let description = parts.first ?? ""

        var severity: AnalysisResult.Anomaly.Severity = .medium
        var action = ""

        for part in parts.dropFirst() {
            let partLower = part.lowercased()
            if partLower.contains("severity:") {
                if partLower.contains("critical") {
                    severity = .critical
                } else if partLower.contains("high") {
                    severity = .high
                } else if partLower.contains("low") {
                    severity = .low
                }
            } else if partLower.contains("action:") {
                action = part.replacingOccurrences(of: "Action:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return AnalysisResult.Anomaly(
            description: description,
            severity: severity,
            suggestedAction: action
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
        from result: AnalysisResult,
        processingTime: TimeInterval
    ) -> AgentOutput {
        var content = """
        ## Data Analysis Report

        \(result.summary)

        ### Key Metrics

        """

        for metric in result.keyMetrics {
            let trend = metric.trend?.rawValue ?? "N/A"
            content += "- **\(metric.name)**: \(metric.value) (\(trend))\n"
        }

        if !result.patterns.isEmpty {
            content += "\n### Patterns Identified\n\n"
            for pattern in result.patterns {
                content += "- \(pattern.description) (Significance: \(String(format: "%.0f%%", pattern.significance * 100)))\n"
            }
        }

        if !result.anomalies.isEmpty {
            content += "\n### Anomalies Detected\n\n"
            for anomaly in result.anomalies {
                content += "- ⚠️ **[\(anomaly.severity.rawValue)]** \(anomaly.description)\n"
                if !anomaly.suggestedAction.isEmpty {
                    content += "  → Action: \(anomaly.suggestedAction)\n"
                }
            }
        }

        if !result.recommendations.isEmpty {
            content += "\n### Recommendations\n\n"
            for rec in result.recommendations {
                content += "1. \(rec)\n"
            }
        }

        var structuredData: [String: AnySendable] = [:]
        structuredData["metrics_count"] = AnySendable(result.keyMetrics.count)
        structuredData["patterns_count"] = AnySendable(result.patterns.count)
        structuredData["anomalies_count"] = AnySendable(result.anomalies.count)
        structuredData["analysis_type"] = AnySendable(config.analysisType.rawValue)

        return AgentOutput(
            agentId: id,
            content: content,
            structuredData: structuredData,
            confidence: result.confidence,
            processingTime: processingTime
        )
    }
}
