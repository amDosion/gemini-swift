//
//  ContextAgent.swift
//  gemini-swfit
//
//  Agent for context management and memory across workflow
//

import Foundation
import SwiftyBeaver

/// Agent that manages context and memory across workflow execution
public final class ContextAgent: Agent, @unchecked Sendable {

    // MARK: - Types

    /// Memory entry for storing context
    public struct MemoryEntry: Sendable {
        public let id: String
        public let key: String
        public let value: String
        public let importance: Double
        public let timestamp: Date
        public let expiresAt: Date?
        public let tags: [String]

        public init(
            id: String = UUID().uuidString,
            key: String,
            value: String,
            importance: Double = 0.5,
            timestamp: Date = Date(),
            expiresAt: Date? = nil,
            tags: [String] = []
        ) {
            self.id = id
            self.key = key
            self.value = value
            self.importance = importance
            self.timestamp = timestamp
            self.expiresAt = expiresAt
            self.tags = tags
        }
    }

    /// Context summary for workflow
    public struct ContextSummary: Sendable {
        public let relevantMemories: [MemoryEntry]
        public let summary: String
        public let keyFacts: [String]
        public let recommendations: [String]
    }

    /// Memory operation types
    public enum MemoryOperation: Sendable {
        case store(key: String, value: String, importance: Double)
        case retrieve(key: String)
        case search(query: String)
        case summarize
        case clear(olderThan: TimeInterval?)
    }

    // MARK: - Properties

    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]

    private let client: GeminiClient
    private let logger: SwiftyBeaver.Type
    private let maxMemorySize: Int
    private let memoryDecayRate: Double

    private let memoryQueue = DispatchQueue(
        label: "com.gemini.context.memory",
        attributes: .concurrent
    )
    private var memories: [MemoryEntry] = []

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        name: String = "Context Agent",
        client: GeminiClient,
        maxMemorySize: Int = 100,
        memoryDecayRate: Double = 0.1,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.id = id
        self.name = name
        self.description = "Manages context and memory across workflow"
        self.capabilities = [.contextManagement, .reasoning]
        self.client = client
        self.maxMemorySize = maxMemorySize
        self.memoryDecayRate = memoryDecayRate
        self.logger = logger
    }

    // MARK: - Agent Protocol

    public func canHandle(input: AgentInput) -> Bool {
        return true
    }

    public func process(input: AgentInput) async throws -> AgentOutput {
        let startTime = Date()
        logger.info("[\(name)] Processing context for input: \(input.id)")

        // Extract and store relevant information from input
        try await extractAndStoreContext(from: input)

        // Build context summary for downstream agents
        let summary = try await buildContextSummary(for: input)

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("[\(name)] Context processed with \(summary.relevantMemories.count) memories")

        return buildOutput(from: summary, processingTime: processingTime)
    }

    // MARK: - Memory Operations

    /// Store a memory entry
    public func store(
        key: String,
        value: String,
        importance: Double = 0.5,
        tags: [String] = [],
        ttl: TimeInterval? = nil
    ) {
        let expiresAt = ttl.map { Date().addingTimeInterval($0) }

        let entry = MemoryEntry(
            key: key,
            value: value,
            importance: min(1.0, max(0.0, importance)),
            expiresAt: expiresAt,
            tags: tags
        )

        memoryQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.memories.append(entry)
            self.pruneMemories()
        }

        logger.debug("[\(name)] Stored memory: \(key)")
    }

    /// Retrieve a memory by key
    public func retrieve(key: String) -> MemoryEntry? {
        memoryQueue.sync {
            memories.first { $0.key == key && !isExpired($0) }
        }
    }

    /// Search memories by query
    public func search(query: String, limit: Int = 10) -> [MemoryEntry] {
        memoryQueue.sync {
            let queryLower = query.lowercased()
            return memories
                .filter { !isExpired($0) }
                .filter {
                    $0.key.lowercased().contains(queryLower) ||
                    $0.value.lowercased().contains(queryLower) ||
                    $0.tags.contains { $0.lowercased().contains(queryLower) }
                }
                .sorted { $0.importance > $1.importance }
                .prefix(limit)
                .map { $0 }
        }
    }

    /// Get memories by tags
    public func getByTags(_ tags: [String]) -> [MemoryEntry] {
        memoryQueue.sync {
            memories
                .filter { !isExpired($0) }
                .filter { memory in
                    tags.contains { tag in memory.tags.contains(tag) }
                }
        }
    }

    /// Clear memories
    public func clear(olderThan: TimeInterval? = nil) {
        memoryQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            if let maxAge = olderThan {
                let cutoff = Date().addingTimeInterval(-maxAge)
                self.memories.removeAll { $0.timestamp < cutoff }
            } else {
                self.memories.removeAll()
            }
        }

        logger.info("[\(name)] Cleared memories")
    }

    // MARK: - Context Processing

    private func extractAndStoreContext(from input: AgentInput) async throws {
        // Store input content as memory
        store(
            key: "input_\(input.id)",
            value: input.content,
            importance: 0.8,
            tags: ["input", "current"]
        )

        // Store previous outputs as context
        for output in input.previousOutputs {
            store(
                key: "output_\(output.agentId)",
                value: output.content,
                importance: output.confidence,
                tags: ["output", output.agentId]
            )
        }

        // Store context variables
        for (key, value) in input.context {
            if let strValue = value.stringValue {
                store(
                    key: "context_\(key)",
                    value: strValue,
                    importance: 0.6,
                    tags: ["context"]
                )
            }
        }

        // Use LLM to extract key facts
        let keyFacts = try await extractKeyFacts(from: input.content)
        for (index, fact) in keyFacts.enumerated() {
            store(
                key: "fact_\(input.id)_\(index)",
                value: fact,
                importance: 0.7,
                tags: ["fact", "extracted"]
            )
        }
    }

    private func extractKeyFacts(from content: String) async throws -> [String] {
        let prompt = """
        Extract the key facts and important information from the following content.
        List each fact on a new line starting with "- ".
        Focus on: names, dates, numbers, key decisions, and important relationships.

        Content:
        \(content.prefix(2000))

        Key Facts:
        """

        let response = try await generateWithLLM(prompt: prompt)

        return response
            .components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") }
            .map { String($0.dropFirst()).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func buildContextSummary(for input: AgentInput) async throws -> ContextSummary {
        // Get relevant memories
        let relevantMemories = getRelevantMemories(for: input.content)

        // Generate summary using LLM
        let memoriesText = relevantMemories
            .map { "[\($0.key)]: \($0.value)" }
            .joined(separator: "\n")

        let summaryPrompt = """
        Summarize the following context information for a task:

        Task: \(input.content.prefix(500))

        Available Context:
        \(memoriesText.prefix(2000))

        Provide:
        1. A brief summary of relevant context
        2. Key facts that are important for this task
        3. Recommendations for how to proceed

        Format:
        SUMMARY: [Your summary]
        KEY_FACTS:
        - [Fact 1]
        - [Fact 2]
        RECOMMENDATIONS:
        - [Recommendation 1]
        - [Recommendation 2]
        """

        let response = try await generateWithLLM(prompt: summaryPrompt)

        return parseContextSummary(response, memories: relevantMemories)
    }

    private func getRelevantMemories(for query: String, limit: Int = 20) -> [MemoryEntry] {
        memoryQueue.sync {
            let now = Date()

            // Score each memory by relevance
            let scored = memories
                .filter { !isExpired($0) }
                .map { memory -> (MemoryEntry, Double) in
                    var score = memory.importance

                    // Recency bonus
                    let age = now.timeIntervalSince(memory.timestamp)
                    let recencyBonus = max(0, 1.0 - (age / 3600)) * 0.3
                    score += recencyBonus

                    // Query match bonus
                    let queryLower = query.lowercased()
                    if memory.key.lowercased().contains(queryLower) ||
                       memory.value.lowercased().contains(queryLower) {
                        score += 0.3
                    }

                    return (memory, score)
                }

            return scored
                .sorted { $0.1 > $1.1 }
                .prefix(limit)
                .map { $0.0 }
        }
    }

    // MARK: - Helper Methods

    private func isExpired(_ entry: MemoryEntry) -> Bool {
        if let expiresAt = entry.expiresAt {
            return Date() > expiresAt
        }
        return false
    }

    private func pruneMemories() {
        // Remove expired memories
        memories.removeAll { isExpired($0) }

        // If still over limit, remove lowest importance memories
        if memories.count > maxMemorySize {
            memories.sort { $0.importance > $1.importance }
            memories = Array(memories.prefix(maxMemorySize))
        }
    }

    private func generateWithLLM(prompt: String) async throws -> String {
        let response = try await client.generateContent(
            model: .gemini25Flash,
            text: prompt,
            generationConfig: GeminiClient.GenerationConfig(temperature: 0.3)
        )

        guard let text = response.text else {
            throw AgentError.processingFailed("No response from LLM")
        }

        return text
    }

    private func parseContextSummary(
        _ response: String,
        memories: [MemoryEntry]
    ) -> ContextSummary {
        // Parse SUMMARY
        var summary = ""
        if let summaryRange = response.range(of: "SUMMARY:") {
            let afterSummary = response[summaryRange.upperBound...]
            if let endRange = afterSummary.range(of: "\nKEY_FACTS:") {
                summary = String(afterSummary[..<endRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Parse KEY_FACTS
        var keyFacts: [String] = []
        if let factsRange = response.range(of: "KEY_FACTS:") {
            let afterFacts = response[factsRange.upperBound...]
            let lines = afterFacts.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("-") {
                    keyFacts.append(
                        String(trimmed.dropFirst())
                            .trimmingCharacters(in: .whitespaces)
                    )
                } else if trimmed.hasPrefix("RECOMMENDATIONS:") {
                    break
                }
            }
        }

        // Parse RECOMMENDATIONS
        var recommendations: [String] = []
        if let recRange = response.range(of: "RECOMMENDATIONS:") {
            let afterRec = response[recRange.upperBound...]
            let lines = afterRec.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("-") {
                    recommendations.append(
                        String(trimmed.dropFirst())
                            .trimmingCharacters(in: .whitespaces)
                    )
                }
            }
        }

        return ContextSummary(
            relevantMemories: memories,
            summary: summary.isEmpty ? "Context processed" : summary,
            keyFacts: keyFacts,
            recommendations: recommendations
        )
    }

    private func buildOutput(
        from summary: ContextSummary,
        processingTime: TimeInterval
    ) -> AgentOutput {
        var content = """
        ## Context Summary

        \(summary.summary)

        ### Key Facts
        """

        for fact in summary.keyFacts {
            content += "\n- \(fact)"
        }

        if !summary.recommendations.isEmpty {
            content += "\n\n### Recommendations"
            for rec in summary.recommendations {
                content += "\n- \(rec)"
            }
        }

        content += "\n\n### Memory Statistics"
        content += "\n- Relevant memories: \(summary.relevantMemories.count)"

        let totalMemories = memoryQueue.sync { memories.count }
        content += "\n- Total memories: \(totalMemories)"

        var structuredData: [String: AnySendable] = [:]
        structuredData["memory_count"] = AnySendable(summary.relevantMemories.count)
        structuredData["key_facts_count"] = AnySendable(summary.keyFacts.count)
        structuredData["summary"] = AnySendable(summary.summary)

        return AgentOutput(
            agentId: id,
            content: content,
            structuredData: structuredData,
            confidence: 0.85,
            processingTime: processingTime
        )
    }
}

// MARK: - Shared Context Manager

/// Singleton context manager for sharing context across agents
public final class SharedContextManager: @unchecked Sendable {
    public static let shared = SharedContextManager()

    private let contextQueue = DispatchQueue(
        label: "com.gemini.shared.context",
        attributes: .concurrent
    )
    private var globalContext: [String: AnySendable] = [:]

    private init() {}

    public func set(key: String, value: AnySendable) {
        contextQueue.async(flags: .barrier) { [weak self] in
            self?.globalContext[key] = value
        }
    }

    public func get(key: String) -> AnySendable? {
        contextQueue.sync {
            globalContext[key]
        }
    }

    public func getAll() -> [String: AnySendable] {
        contextQueue.sync {
            globalContext
        }
    }

    public func clear() {
        contextQueue.async(flags: .barrier) { [weak self] in
            self?.globalContext.removeAll()
        }
    }
}
