//
//  GeminiAPIKeyManagerTests.swift
//  gemini-swfitTests
//
//  Created by Claude on 2025-01-10.
//

import XCTest
@testable import gemini_swfit

final class GeminiAPIKeyManagerTests: XCTestCase {
    
    var keyManager: GeminiAPIKeyManager!
    let testKeys = ["key1", "key2", "key3"]
    
    override func setUp() {
        super.setUp()
        let quota = GeminiAPIKeyManager.QuotaInfo(
            requestsPerMinute: 60,
            requestsPerHour: 3600,
            bytesPerMinute: 100 * 1024 * 1024,
            maxConcurrentUploads: 5
        )
        keyManager = GeminiAPIKeyManager(
            apiKeys: testKeys,
            quota: quota,
            strategy: .leastUsed
        )
    }
    
    override func tearDown() {
        keyManager = nil
        super.tearDown()
    }
    
    // MARK: - Test Key Initialization
    
    func testInitializationWithKeys() {
        XCTAssertEqual(keyManager.getKeyHealth().total, 3)
        XCTAssertEqual(keyManager.getKeyHealth().healthy, 3)
        XCTAssertEqual(keyManager.getKeyHealth().disabled, 0)
    }
    
    func testInitializationWithEmptyKeys() {
        let emptyManager = GeminiAPIKeyManager(apiKeys: [])
        XCTAssertEqual(emptyManager.getKeyHealth().total, 0)
        XCTAssertEqual(emptyManager.getKeyHealth().healthy, 0)
    }
    
    // MARK: - Test Key Selection Strategies
    
    func testRoundRobinStrategy() async {
        let manager = GeminiAPIKeyManager(
            apiKeys: testKeys,
            strategy: .roundRobin
        )
        
        let firstKey = manager.getAvailableKey()
        let secondKey = manager.getAvailableKey()
        let thirdKey = manager.getAvailableKey()
        
        XCTAssertEqual(firstKey, "key1")
        XCTAssertEqual(secondKey, "key2")
        XCTAssertEqual(thirdKey, "key3")
    }
    
    func testLeastUsedStrategy() async {
        // Use key1 multiple times
        _ = keyManager.getAvailableKey()
        keyManager.reportSuccess(for: "key1")
        _ = keyManager.getAvailableKey()
        keyManager.reportSuccess(for: "key1")
        
        // Next key should be key2 (least used)
        let nextKey = keyManager.getAvailableKey()
        XCTAssertEqual(nextKey, "key2")
    }
    
    // MARK: - Test Key Usage Tracking
    
    func testReportSuccess() async {
        let key = keyManager.getAvailableKey()
        XCTAssertEqual(key, "key1")
        
        keyManager.reportSuccess(for: key!, bytesUploaded: 1024)
        
        let stats = keyManager.getUsageStats()
        let key1Stats = stats.first { $0.key == "key1" }
        
        XCTAssertEqual(key1Stats?.usageCount, 1)
        XCTAssertEqual(key1Stats?.totalBytesUploaded, 1024)
        XCTAssertEqual(key1Stats?.errors, 0)
        XCTAssertFalse(key1Stats?.isDisabled ?? true)
    }
    
    func testReportError() async {
        let key = keyManager.getAvailableKey()
        
        // Report multiple errors
        keyManager.reportError(for: key!, error: NSError(domain: "test", code: 500))
        keyManager.reportError(for: key!, error: NSError(domain: "test", code: 500))
        
        let stats = keyManager.getUsageStats()
        let key1Stats = stats.first { $0.key == "key1" }
        
        XCTAssertEqual(key1Stats?.errors, 2)
        XCTAssertFalse(key1Stats?.isDisabled ?? true)
        
        // Third error should disable the key
        keyManager.reportError(for: key!, error: NSError(domain: "test", code: 500))
        
        let health = keyManager.getKeyHealth()
        XCTAssertEqual(health.disabled, 1)
    }
    
    // MARK: - Test Rate Limiting
    
    func testRateLimiting() async {
        let quota = GeminiAPIKeyManager.QuotaInfo(
            requestsPerMinute: 2, // Very low limit for testing
            requestsPerHour: 3600,
            bytesPerMinute: 100 * 1024 * 1024,
            maxConcurrentUploads: 5
        )
        
        let manager = GeminiAPIKeyManager(
            apiKeys: ["key1"],
            quota: quota,
            strategy: .leastUsed
        )
        
        // Use up the quota
        let key1 = manager.getAvailableKey()
        XCTAssertNotNil(key1)
        manager.reportSuccess(for: key1!)
        
        let key2 = manager.getAvailableKey()
        XCTAssertNotNil(key2)
        manager.reportSuccess(for: key2!)
        
        // Next request should be nil (rate limited)
        let key3 = manager.getAvailableKey()
        XCTAssertNil(key3)
    }
    
    // MARK: - Test Quota Management
    
    func testRecommendedBatchSize() async {
        let batchSize = keyManager.recommendedBatchSize(for: 1024 * 1024) // 1MB
        
        XCTAssertGreaterThan(batchSize, 0)
        XCTAssertLessThanOrEqual(batchSize, 100) // Reasonable upper limit
    }
    
    func testEstimatedWaitTime() async {
        // Initially no wait time
        let waitTime = keyManager.estimatedWaitTime()
        XCTAssertEqual(waitTime, 0)
    }
    
    // MARK: - Test Usage Statistics
    
    func testGetUsageStats() async {
        // Use some keys
        let key1 = keyManager.getAvailableKey()
        keyManager.reportSuccess(for: key1!, bytesUploaded: 1024)
        
        let key2 = keyManager.getAvailableKey()
        keyManager.reportError(for: key2!, error: NSError(domain: "test", code: 500))
        
        let stats = keyManager.getUsageStats()
        
        XCTAssertEqual(stats.count, 3)
        XCTAssertTrue(stats.contains { $0.key == "key1" && $0.usageCount == 1 })
        XCTAssertTrue(stats.contains { $0.key == "key2" && $0.errors == 1 })
    }
    
    func testGetKeyHealth() async {
        let health = keyManager.getKeyHealth()
        
        XCTAssertEqual(health.total, 3)
        XCTAssertEqual(health.healthy, 3)
        XCTAssertEqual(health.disabled, 0)
        let healthPercentage = Double(health.healthy) / Double(health.total) * 100
        XCTAssertEqual(healthPercentage, 100.0)
    }
    
    // MARK: - Test Key Reset
    
    func testResetStats() async {
        // Use keys and generate some stats
        let key1 = keyManager.getAvailableKey()
        keyManager.reportSuccess(for: key1!)
        
        let key2 = keyManager.getAvailableKey()
        keyManager.reportError(for: key2!, error: NSError(domain: "test", code: 500))
        
        // Reset stats
        keyManager.resetStats()
        
        let stats = keyManager.getUsageStats()
        for stat in stats {
            XCTAssertEqual(stat.usageCount, 0)
            XCTAssertEqual(stat.errors, 0)
            XCTAssertEqual(stat.totalBytesUploaded, 0)
            XCTAssertFalse(stat.isDisabled)
        }
        
        let health = keyManager.getKeyHealth()
        XCTAssertEqual(health.healthy, 3)
        XCTAssertEqual(health.disabled, 0)
    }
    
    // MARK: - Test Can Use Key
    
    func testCanUseKey() async {
        let key = keyManager.getAvailableKey()
        
        // Key should be usable
        XCTAssertTrue(keyManager.canUseKey(key!))
        
        // Disable the key
        for _ in 0..<3 {
            keyManager.reportError(for: key!, error: NSError(domain: "test", code: 500))
        }
        
        // Key should not be usable
        XCTAssertFalse(keyManager.canUseKey(key!))
    }
    
    // MARK: - Test Custom Strategy
    
    func testCustomStrategy() async {
        let customManager = GeminiAPIKeyManager(
            apiKeys: testKeys,
            strategy: .custom { keys in
                // Always return the first key
                return keys.first
            }
        )
        
        let key1 = customManager.getAvailableKey()
        let key2 = customManager.getAvailableKey()
        
        XCTAssertEqual(key1, "key1")
        XCTAssertEqual(key2, "key1") // Always returns first key
    }
}