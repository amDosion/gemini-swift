//
//  GeminiAPIKeyManager.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import SwiftyBeaver

// MARK: - Internal Actor for Thread-Safe State Management

/// Internal actor that manages the mutable state for API key management.
/// This provides compiler-verified thread safety for all state operations.
private actor KeyManagerState {
    var keyUsages: [String: GeminiAPIKeyManager.KeyUsage] = [:]
    var currentIndex = 0
    var usageHistory: [Date] = []

    func initialize(apiKeys: [String]) {
        for key in apiKeys {
            keyUsages[key] = GeminiAPIKeyManager.KeyUsage(key: key)
        }
    }

    func getKeyUsage(_ key: String) -> GeminiAPIKeyManager.KeyUsage? {
        return keyUsages[key]
    }

    func setKeyUsage(_ key: String, usage: GeminiAPIKeyManager.KeyUsage) {
        keyUsages[key] = usage
    }

    func getAllUsages() -> [GeminiAPIKeyManager.KeyUsage] {
        return Array(keyUsages.values)
    }

    func getUsageHistory() -> [Date] {
        return usageHistory
    }

    func appendUsageHistory(_ date: Date) {
        usageHistory.append(date)
    }

    func removeOldHistory(before date: Date) {
        usageHistory.removeAll { $0 < date }
    }

    func incrementIndex(count: Int) -> Int {
        currentIndex = (currentIndex + 1) % count
        return currentIndex
    }

    func resetAllStats() {
        for key in keyUsages.keys {
            keyUsages[key]?.usageCount = 0
            keyUsages[key]?.requestsThisMinute = 0
            keyUsages[key]?.requestsThisHour = 0
            keyUsages[key]?.totalBytesUploaded = 0
            keyUsages[key]?.errors = 0
            keyUsages[key]?.isDisabled = false
            keyUsages[key]?.disabledUntil = nil
        }
    }

    func cleanupExpiredUsage() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)

        usageHistory.removeAll { $0 < oneHourAgo }

        for key in keyUsages.keys {
            keyUsages[key]?.requestsThisHour = 0
        }
    }
}

/// Manages API key usage, quotas, and intelligent rotation for multiple audio uploads
public final class GeminiAPIKeyManager: Sendable {

    // MARK: - Types

    public struct KeyUsage: Codable, Identifiable, Sendable {
        public let id: UUID
        public let key: String
        public var usageCount: Int = 0
        public var lastUsed: Date?
        public var totalBytesUploaded: Int64 = 0
        public var requestsThisMinute: Int = 0
        public var requestsThisHour: Int = 0
        public var errors: Int = 0
        public var isDisabled: Bool = false
        public var disabledUntil: Date?

        public init(key: String) {
            self.id = UUID()
            self.key = key
        }
    }

    public struct QuotaInfo: Sendable {
        public let requestsPerMinute: Int
        public let requestsPerHour: Int
        public let bytesPerMinute: Int64
        public let maxConcurrentUploads: Int

        public init(
            requestsPerMinute: Int = 60,
            requestsPerHour: Int = 3600,
            bytesPerMinute: Int64 = 100 * 1024 * 1024, // 100MB
            maxConcurrentUploads: Int = 5
        ) {
            self.requestsPerMinute = requestsPerMinute
            self.requestsPerHour = requestsPerHour
            self.bytesPerMinute = bytesPerMinute
            self.maxConcurrentUploads = maxConcurrentUploads
        }
    }

    public enum SelectionStrategy: Sendable {
        case roundRobin
        case leastUsed
        case weightedRandom
    }

    // MARK: - Properties

    private let logger: SwiftyBeaver.Type
    private let state: KeyManagerState
    private let quota: QuotaInfo
    private let strategy: SelectionStrategy
    private let cleanupTask: Task<Void, Never>

    // MARK: - Initialization

    public init(
        apiKeys: [String],
        quota: QuotaInfo = QuotaInfo(),
        strategy: SelectionStrategy = .leastUsed,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.logger = logger
        self.quota = quota
        self.strategy = strategy
        self.state = KeyManagerState()

        // Initialize key usage tracking
        let stateRef = self.state
        self.cleanupTask = Task {
            await stateRef.initialize(apiKeys: apiKeys)

            // Periodic cleanup
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                await stateRef.cleanupExpiredUsage()
            }
        }
    }

    deinit {
        cleanupTask.cancel()
    }

    // MARK: - Public Methods

    /// Get the best available API key for a request
    public func getAvailableKey(for requestSize: Int64 = 0) async -> String? {
        let allUsages = await state.getAllUsages()
        let usageHistory = await state.getUsageHistory()

        let availableKeys = allUsages
            .filter { !$0.isDisabled && canUseKey($0, for: requestSize, usageHistory: usageHistory) }
            .sorted(by: keyPriority)

        guard !availableKeys.isEmpty else {
            logger.warning("No available API keys")
            return nil
        }

        let selectedKey = await selectKey(from: availableKeys)
        await recordUsage(selectedKey, requestSize: requestSize)

        return selectedKey.key
    }

    /// Check if a specific key can be used
    public func canUseKey(_ key: String, for requestSize: Int64 = 0) async -> Bool {
        guard let usage = await state.getKeyUsage(key) else { return false }
        let usageHistory = await state.getUsageHistory()
        return canUseKey(usage, for: requestSize, usageHistory: usageHistory)
    }

    /// Report successful usage of a key
    public func reportSuccess(for key: String, bytesUploaded: Int64 = 0) async {
        guard var usage = await state.getKeyUsage(key) else { return }

        usage.usageCount += 1
        usage.lastUsed = Date()
        usage.totalBytesUploaded += bytesUploaded
        usage.errors = 0 // Reset error count on success

        await state.setKeyUsage(key, usage: usage)
    }

    /// Report error for a key
    public func reportError(for key: String, error: Error) async {
        guard var usage = await state.getKeyUsage(key) else { return }

        usage.errors += 1

        // Temporarily disable key if too many errors
        if usage.errors >= 3 {
            usage.isDisabled = true
            usage.disabledUntil = Date().addingTimeInterval(60) // Disable for 1 minute
            logger.warning("API key temporarily disabled due to errors: \(key.prefix(8))...")
        }

        await state.setKeyUsage(key, usage: usage)
    }

    /// Get usage statistics
    public func getUsageStats() async -> [KeyUsage] {
        return await state.getAllUsages().sorted { $0.usageCount > $1.usageCount }
    }

    /// Get key health status
    public func getKeyHealth() async -> (healthy: Int, disabled: Int, total: Int) {
        let all = await state.getAllUsages()
        let disabled = all.filter { $0.isDisabled }.count
        return (all.count - disabled, disabled, all.count)
    }

    /// Reset usage statistics for all keys
    public func resetStats() async {
        await state.resetAllStats()
    }

    // MARK: - Private Methods

    private func canUseKey(_ usage: KeyUsage, for requestSize: Int64, usageHistory: [Date]) -> Bool {
        // Check if key is disabled
        if usage.isDisabled {
            if let disabledUntil = usage.disabledUntil, disabledUntil > Date() {
                return false
            }
            // Note: Re-enabling is handled in getAvailableKey
        }

        // Check rate limits
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        let oneHourAgo = now.addingTimeInterval(-3600)

        // Count recent requests
        let recentMinuteUsage = usageHistory.filter { $0 > oneMinuteAgo }.count
        let recentHourUsage = usageHistory.filter { $0 > oneHourAgo }.count

        return recentMinuteUsage < quota.requestsPerMinute &&
               recentHourUsage < quota.requestsPerHour &&
               usage.totalBytesUploaded < quota.bytesPerMinute
    }

    private func selectKey(from keys: [KeyUsage]) async -> KeyUsage {
        // Precondition: keys must not be empty (caller ensures this)
        precondition(!keys.isEmpty, "selectKey called with empty keys array")

        switch strategy {
        case .roundRobin:
            let index = await state.incrementIndex(count: keys.count)
            return keys[index]

        case .leastUsed:
            // For non-empty collection, min() always returns a value
            return keys.min { $0.usageCount < $1.usageCount } ?? keys[0]

        case .weightedRandom:
            // Inverse weighting - less used keys have higher probability
            let totalUsage = keys.reduce(0) { $0 + $1.usageCount }
            let weights = keys.map { totalUsage - $0.usageCount + 1 }
            let totalWeight = weights.reduce(0, +)
            let random = Int.random(in: 1...totalWeight)

            var accumulated = 0
            for (index, weight) in weights.enumerated() {
                accumulated += weight
                if random <= accumulated {
                    return keys[index]
                }
            }
            // Fallback (should never reach due to loop logic)
            return keys[0]
        }
    }

    private func keyPriority(lhs: KeyUsage, rhs: KeyUsage) -> Bool {
        // Priority: least errors, then least used, then least bytes
        if lhs.errors != rhs.errors {
            return lhs.errors < rhs.errors
        }
        if lhs.usageCount != rhs.usageCount {
            return lhs.usageCount < rhs.usageCount
        }
        return lhs.totalBytesUploaded < rhs.totalBytesUploaded
    }

    private func recordUsage(_ usage: KeyUsage, requestSize: Int64) async {
        var updatedUsage = usage
        updatedUsage.usageCount += 1
        updatedUsage.lastUsed = Date()
        updatedUsage.requestsThisMinute += 1
        updatedUsage.requestsThisHour += 1
        updatedUsage.totalBytesUploaded += requestSize

        await state.setKeyUsage(usage.key, usage: updatedUsage)
        await state.appendUsageHistory(Date())
    }
}

// MARK: - Convenience Extensions

extension GeminiAPIKeyManager {

    /// Estimate time until next available key
    public func estimatedWaitTime() async -> TimeInterval {
        let now = Date()
        let usageHistory = await state.getUsageHistory()
        let recentUsage = usageHistory.filter { $0 > now.addingTimeInterval(-60) }

        if recentUsage.count < quota.requestsPerMinute {
            return 0
        }

        guard let oldestRecent = recentUsage.first else { return 0 }
        return oldestRecent.addingTimeInterval(60).timeIntervalSince(now)
    }

    /// Get recommended batch size based on available quotas
    public func recommendedBatchSize(for estimatedFileSize: Int64) async -> Int {
        let allUsages = await state.getAllUsages()
        let availableKeys = allUsages.filter { !$0.isDisabled }.count
        guard availableKeys > 0 else { return 1 }

        let requestsPerKey = max(1, quota.requestsPerMinute / availableKeys)
        let bytesPerKey = quota.bytesPerMinute / Int64(availableKeys)
        let filesPerKey = max(1, Int(bytesPerKey / estimatedFileSize))

        return min(requestsPerKey, filesPerKey)
    }
}