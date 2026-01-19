//
//  GeminiAPIKeyManager.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import SwiftyBeaver

/// Manages API key usage, quotas, and intelligent rotation for multiple audio uploads
public class GeminiAPIKeyManager: @unchecked Sendable, ObservableObject {
    
    // MARK: - Types
    
    public struct KeyUsage: Codable, Identifiable {
        public let id = UUID()
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
            self.key = key
        }
    }
    
    public struct QuotaInfo {
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
    
    public enum SelectionStrategy {
        case roundRobin
        case leastUsed
        case weightedRandom
        case custom(([KeyUsage]) -> KeyUsage?)
    }
    
    // MARK: - Properties
    
    private let logger: SwiftyBeaver.Type
    private let queue = DispatchQueue(label: "com.gemini.swift.keyManager", attributes: .concurrent)
    private var keyUsages: [String: KeyUsage] = [:]
    private let quota: QuotaInfo
    private let strategy: SelectionStrategy
    private var currentIndex = 0
    private var usageHistory: [Date] = []
    
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
        
        // Initialize key usage tracking
        for key in apiKeys {
            keyUsages[key] = KeyUsage(key: key)
        }
        
        // Start periodic cleanup
        startPeriodicCleanup()
    }
    
    // MARK: - Public Methods
    
    /// Get the best available API key for a request
    public func getAvailableKey(for requestSize: Int64 = 0) -> String? {
        return queue.sync(flags: .barrier) {
            cleanupExpiredUsage()
            
            let availableKeys = keyUsages.values
                .filter { !$0.isDisabled && canUseKey($0, for: requestSize) }
                .sorted(by: keyPriority)
            
            guard !availableKeys.isEmpty else {
                logger.warning("No available API keys")
                return nil
            }
            
            let selectedKey = selectKey(from: availableKeys)
            recordUsage(selectedKey, requestSize: requestSize)
            
            return selectedKey.key
        }
    }
    
    /// Check if a specific key can be used
    public func canUseKey(_ key: String, for requestSize: Int64 = 0) -> Bool {
        return queue.sync {
            guard let usage = keyUsages[key] else { return false }
            return canUseKey(usage, for: requestSize)
        }
    }
    
    /// Report successful usage of a key
    public func reportSuccess(for key: String, bytesUploaded: Int64 = 0) {
        queue.sync(flags: .barrier) {
            guard var usage = keyUsages[key] else { return }
            
            usage.usageCount += 1
            usage.lastUsed = Date()
            usage.totalBytesUploaded += bytesUploaded
            usage.errors = 0 // Reset error count on success
            
            keyUsages[key] = usage
        }
    }
    
    /// Report error for a key
    public func reportError(for key: String, error: Error) {
        queue.sync(flags: .barrier) {
            guard var usage = keyUsages[key] else { return }
            
            usage.errors += 1
            
            // Temporarily disable key if too many errors
            if usage.errors >= 3 {
                usage.isDisabled = true
                usage.disabledUntil = Date().addingTimeInterval(60) // Disable for 1 minute
                logger.warning("API key temporarily disabled due to errors: \(key.prefix(8))...")
            }
            
            keyUsages[key] = usage
        }
    }
    
    /// Get usage statistics
    public func getUsageStats() -> [KeyUsage] {
        return queue.sync {
            Array(keyUsages.values).sorted { $0.usageCount > $1.usageCount }
        }
    }
    
    /// Get key health status
    public func getKeyHealth() -> (healthy: Int, disabled: Int, total: Int) {
        return queue.sync {
            let all = keyUsages.values
            let disabled = all.filter { $0.isDisabled }.count
            return (all.count - disabled, disabled, all.count)
        }
    }
    
    /// Reset usage statistics for all keys
    public func resetStats() {
        queue.sync(flags: .barrier) {
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
    }
    
    // MARK: - Private Methods
    
    private func canUseKey(_ usage: KeyUsage, for requestSize: Int64) -> Bool {
        // Check if key is disabled
        if usage.isDisabled {
            if let disabledUntil = usage.disabledUntil, disabledUntil > Date() {
                return false
            } else {
                // Re-enable key if disable period has passed
                var updatedUsage = usage
                updatedUsage.isDisabled = false
                updatedUsage.disabledUntil = nil
                keyUsages[usage.key] = updatedUsage
            }
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
    
    private func selectKey(from keys: [KeyUsage]) -> KeyUsage {
        // Precondition: keys must not be empty (caller ensures this)
        precondition(!keys.isEmpty, "selectKey called with empty keys array")

        switch strategy {
        case .roundRobin:
            currentIndex = (currentIndex + 1) % keys.count
            return keys[currentIndex]

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

        case .custom(let selector):
            return selector(keys) ?? keys[0]
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
    
    private func recordUsage(_ usage: KeyUsage, requestSize: Int64) {
        var updatedUsage = usage
        updatedUsage.usageCount += 1
        updatedUsage.lastUsed = Date()
        updatedUsage.requestsThisMinute += 1
        updatedUsage.requestsThisHour += 1
        updatedUsage.totalBytesUploaded += requestSize
        
        keyUsages[usage.key] = updatedUsage
        usageHistory.append(Date())
    }
    
    private func cleanupExpiredUsage() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        
        // Clean old usage history
        usageHistory.removeAll { $0 < oneHourAgo }
        
        // Reset hourly counters
        for key in keyUsages.keys {
            if var usage = keyUsages[key] {
                usage.requestsThisHour = 0
                keyUsages[key] = usage
            }
        }
    }
    
    private func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.queue.sync(flags: .barrier) {
                    self?.cleanupExpiredUsage()
                }
            }
        }
    }
}

// MARK: - Convenience Extensions

extension GeminiAPIKeyManager {
    
    /// Estimate time until next available key
    public func estimatedWaitTime() -> TimeInterval {
        return queue.sync {
            let now = Date()
            let recentUsage = usageHistory.filter { $0 > now.addingTimeInterval(-60) }
            
            if recentUsage.count < quota.requestsPerMinute {
                return 0
            }
            
            guard let oldestRecent = recentUsage.first else { return 0 }
            return oldestRecent.addingTimeInterval(60).timeIntervalSince(now)
        }
    }
    
    /// Get recommended batch size based on available quotas
    public func recommendedBatchSize(for estimatedFileSize: Int64) -> Int {
        return queue.sync {
            let availableKeys = keyUsages.values.filter { !$0.isDisabled }.count
            let requestsPerKey = max(1, quota.requestsPerMinute / availableKeys)
            let bytesPerKey = quota.bytesPerMinute / Int64(availableKeys)
            let filesPerKey = max(1, Int(bytesPerKey / estimatedFileSize))
            
            return min(requestsPerKey, filesPerKey)
        }
    }
}