//
//  TrendAnalyzer.swift
//  gemini-swfit
//
//  Agent for trend analysis and forecasting
//

import Foundation
import SwiftyBeaver

/// Agent specialized in trend detection and analysis
public final class TrendAnalyzerAgent: Agent, @unchecked Sendable {

    // MARK: - Types

    /// Trend analysis result
    public struct TrendResult: Sendable {
        public let trends: [Trend]
        public let forecast: Forecast?
        public let seasonality: Seasonality?
        public let confidence: Double

        public struct Trend: Sendable {
            public let name: String
            public let direction: Direction
            public let strength: Double
            public let duration: String
            public let description: String

            public enum Direction: String, Sendable {
                case upward = "Upward"
                case downward = "Downward"
                case sideways = "Sideways"
                case cyclical = "Cyclical"
            }
        }

        public struct Forecast: Sendable {
            public let shortTerm: String
            public let mediumTerm: String
            public let longTerm: String
            public let keyFactors: [String]
        }

        public struct Seasonality: Sendable {
            public let detected: Bool
            public let pattern: String
            public let peakPeriods: [String]
            public let lowPeriods: [String]
        }
    }

    // MARK: - Properties

    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]

    private let client: GeminiClient
    private let logger: SwiftyBeaver.Type
    private let includeForecast: Bool
    private let forecastHorizon: String

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String = "Trend Analyzer",
        client: GeminiClient,
        includeForecast: Bool = true,
        forecastHorizon: String = "medium-term",
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = "Analyzes trends and provides forecasting"
        self.capabilities = [.dataAnalysis, .reasoning]
        self.client = client
        self.includeForecast = includeForecast
        self.forecastHorizon = forecastHorizon
        self.logger = logger
    }

    // MARK: - Agent Protocol

    public func canHandle(input: AgentInput) -> Bool {
        return !input.content.isEmpty
    }

    public func process(input: AgentInput) async throws -> AgentOutput {
        let startTime = Date()
        logger.info("[\(name)] Starting trend analysis")

        let result = try await analyzeTrends(input: input)

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("[\(name)] Found \(result.trends.count) trends")

        return buildOutput(from: result, processingTime: processingTime)
    }

    // MARK: - Analysis Methods

    private func analyzeTrends(input: AgentInput) async throws -> TrendResult {
        let prompt = """
        Perform comprehensive trend analysis on the following data:

        Data:
        \(input.content.prefix(6000))

        Analyze for:
        1. Major trends and their characteristics
        2. Trend strength and duration
        3. Seasonality patterns (if applicable)
        4. Future projections (\(forecastHorizon))

        Format your response as:

        TRENDS:
        - Name: [Trend name] | Direction: [upward/downward/sideways/cyclical] | Strength: [0.X] | Duration: [time period]
          Description: [Detailed description]

        SEASONALITY:
        Detected: [yes/no]
        Pattern: [Description of seasonal pattern]
        Peak Periods: [Period 1], [Period 2]
        Low Periods: [Period 1], [Period 2]

        FORECAST:
        Short Term: [1-3 months projection]
        Medium Term: [3-12 months projection]
        Long Term: [12+ months projection]
        Key Factors:
        - [Factor 1]
        - [Factor 2]

        CONFIDENCE: [0.X]
        """

        let response = try await generateWithLLM(prompt: prompt)
        return parseTrendResult(response)
    }

    private func parseTrendResult(_ response: String) -> TrendResult {
        var trends: [TrendResult.Trend] = []
        var forecast: TrendResult.Forecast? = nil
        var seasonality: TrendResult.Seasonality? = nil
        var confidence = 0.7

        // Parse TRENDS
        if let trendsRange = response.range(of: "TRENDS:") {
            let after = response[trendsRange.upperBound...]
            let lines = after.components(separatedBy: "\n")

            var currentTrend: (name: String, direction: TrendResult.Trend.Direction, strength: Double, duration: String)? = nil

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("- Name:") || trimmed.hasPrefix("-Name:") {
                    // Save previous trend if exists
                    if let current = currentTrend {
                        trends.append(TrendResult.Trend(
                            name: current.name,
                            direction: current.direction,
                            strength: current.strength,
                            duration: current.duration,
                            description: ""
                        ))
                    }

                    // Parse new trend header
                    currentTrend = parseTrendHeader(trimmed)

                } else if trimmed.hasPrefix("Description:") {
                    if var current = currentTrend {
                        let desc = trimmed.replacingOccurrences(of: "Description:", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        trends.append(TrendResult.Trend(
                            name: current.name,
                            direction: current.direction,
                            strength: current.strength,
                            duration: current.duration,
                            description: desc
                        ))
                        currentTrend = nil
                    }
                } else if trimmed.contains("SEASONALITY:") {
                    break
                }
            }
        }

        // Parse SEASONALITY
        if let seasRange = response.range(of: "SEASONALITY:") {
            let after = response[seasRange.upperBound...]
            var detected = false
            var pattern = ""
            var peaks: [String] = []
            var lows: [String] = []

            let lines = after.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("detected:") {
                    detected = trimmed.lowercased().contains("yes")
                } else if trimmed.hasPrefix("Pattern:") {
                    pattern = trimmed.replacingOccurrences(of: "Pattern:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("Peak Periods:") {
                    peaks = trimmed.replacingOccurrences(of: "Peak Periods:", with: "")
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                } else if trimmed.hasPrefix("Low Periods:") {
                    lows = trimmed.replacingOccurrences(of: "Low Periods:", with: "")
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                } else if trimmed.contains("FORECAST:") {
                    break
                }
            }

            if detected || !pattern.isEmpty {
                seasonality = TrendResult.Seasonality(
                    detected: detected,
                    pattern: pattern,
                    peakPeriods: peaks,
                    lowPeriods: lows
                )
            }
        }

        // Parse FORECAST
        if includeForecast, let foreRange = response.range(of: "FORECAST:") {
            let after = response[foreRange.upperBound...]
            var shortTerm = ""
            var mediumTerm = ""
            var longTerm = ""
            var factors: [String] = []

            let lines = after.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("Short Term:") {
                    shortTerm = trimmed.replacingOccurrences(of: "Short Term:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("Medium Term:") {
                    mediumTerm = trimmed.replacingOccurrences(of: "Medium Term:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("Long Term:") {
                    longTerm = trimmed.replacingOccurrences(of: "Long Term:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("-") && !trimmed.contains("Name:") {
                    factors.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                } else if trimmed.contains("CONFIDENCE:") {
                    break
                }
            }

            forecast = TrendResult.Forecast(
                shortTerm: shortTerm,
                mediumTerm: mediumTerm,
                longTerm: longTerm,
                keyFactors: factors
            )
        }

        // Parse CONFIDENCE
        if let confRange = response.range(of: "CONFIDENCE:") {
            let after = response[confRange.upperBound...].prefix(10)
            if let parsed = Double(after.filter { $0.isNumber || $0 == "." }) {
                confidence = min(1.0, max(0.0, parsed))
            }
        }

        return TrendResult(
            trends: trends,
            forecast: forecast,
            seasonality: seasonality,
            confidence: confidence
        )
    }

    private func parseTrendHeader(_ line: String) -> (name: String, direction: TrendResult.Trend.Direction, strength: Double, duration: String) {
        let content = line.replacingOccurrences(of: "- Name:", with: "")
            .replacingOccurrences(of: "-Name:", with: "")
        let parts = content.components(separatedBy: " | ")

        var name = parts.first?.trimmingCharacters(in: .whitespaces) ?? "Unknown"
        var direction: TrendResult.Trend.Direction = .sideways
        var strength = 0.5
        var duration = ""

        for part in parts.dropFirst() {
            let partLower = part.lowercased()
            if partLower.contains("direction:") {
                if partLower.contains("upward") {
                    direction = .upward
                } else if partLower.contains("downward") {
                    direction = .downward
                } else if partLower.contains("cyclical") {
                    direction = .cyclical
                }
            } else if partLower.contains("strength:") {
                if let str = Double(part.filter { $0.isNumber || $0 == "." }) {
                    strength = min(1.0, max(0.0, str))
                }
            } else if partLower.contains("duration:") {
                duration = part.replacingOccurrences(of: "Duration:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return (name, direction, strength, duration)
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
        from result: TrendResult,
        processingTime: TimeInterval
    ) -> AgentOutput {
        var content = """
        ## Trend Analysis Report

        ### Identified Trends

        """

        for (index, trend) in result.trends.enumerated() {
            let arrow = trend.direction == .upward ? "📈" :
                       (trend.direction == .downward ? "📉" : "📊")
            content += """

            #### \(index + 1). \(trend.name) \(arrow)
            - **Direction:** \(trend.direction.rawValue)
            - **Strength:** \(String(format: "%.0f%%", trend.strength * 100))
            - **Duration:** \(trend.duration)
            \(trend.description.isEmpty ? "" : "\n\(trend.description)")

            """
        }

        if let seasonality = result.seasonality, seasonality.detected {
            content += """

            ### Seasonality
            - **Pattern:** \(seasonality.pattern)
            - **Peak Periods:** \(seasonality.peakPeriods.joined(separator: ", "))
            - **Low Periods:** \(seasonality.lowPeriods.joined(separator: ", "))

            """
        }

        if let forecast = result.forecast {
            content += """

            ### Forecast
            - **Short Term:** \(forecast.shortTerm)
            - **Medium Term:** \(forecast.mediumTerm)
            - **Long Term:** \(forecast.longTerm)

            **Key Factors:**
            """
            for factor in forecast.keyFactors {
                content += "\n- \(factor)"
            }
        }

        var structuredData: [String: AnySendable] = [:]
        structuredData["trends_count"] = AnySendable(result.trends.count)
        structuredData["has_seasonality"] = AnySendable(result.seasonality?.detected ?? false)
        structuredData["has_forecast"] = AnySendable(result.forecast != nil)

        return AgentOutput(
            agentId: id,
            content: content,
            structuredData: structuredData,
            confidence: result.confidence,
            processingTime: processingTime
        )
    }
}
