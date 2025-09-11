//
//  GeminiAudioManagerEnhancedTests.swift
//  gemini-swfitTests
//
//  Created by Claude on 2025-01-10.
//

import XCTest
@testable import gemini_swfit

final class GeminiAudioManagerEnhancedTests: XCTestCase {
    
    var audioManager: GeminiAudioManagerEnhanced!
    var testKeys: [String] = []
    let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
    
    override func setUp() {
        super.setUp()
        
        // Get test keys from environment variables
        if let key1 = ProcessInfo.processInfo.environment["GEMINI_API_KEY_1"],
           let key2 = ProcessInfo.processInfo.environment["GEMINI_API_KEY_2"],
           let key3 = ProcessInfo.processInfo.environment["GEMINI_API_KEY_3"] {
            testKeys = [key1, key2, key3]
        } else {
            // Fallback to test key if environment variables not set
            if let testKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
                testKeys = [testKey]
            } else {
                XCTFail("No GEMINI_API_KEY environment variables set")
                return
            }
        }
        
        let quota = GeminiAPIKeyManager.QuotaInfo(
            requestsPerMinute: 30,
            requestsPerHour: 1000,
            bytesPerMinute: 50 * 1024 * 1024,
            maxConcurrentUploads: 3
        )
        audioManager = GeminiAudioManagerEnhanced(
            apiKeys: testKeys,
            quota: quota,
            strategy: .leastUsed
        )
    }
    
    override func tearDown() {
        audioManager = nil
        super.tearDown()
    }
    
    // MARK: - Test Initialization
    
    func testInitialization() {
        XCTAssertNotNil(audioManager)
        XCTAssertEqual(audioManager.keyManagerRef.getKeyHealth().total, 3)
    }
    
    func testInitializationWithDefaults() {
        let defaultManager = GeminiAudioManagerEnhanced(apiKeys: testKeys)
        XCTAssertNotNil(defaultManager)
    }
    
    // MARK: - Test Usage Analytics
    
    func testGetUsageAnalytics() async {
        // Simulate some usage
        _ = audioManager.keyManagerRef.getAvailableKey()
        audioManager.keyManagerRef.reportSuccess(for: testKeys[0], bytesUploaded: 1024)
        
        _ = audioManager.keyManagerRef.getAvailableKey()
        audioManager.keyManagerRef.reportError(for: testKeys[1], error: NSError(domain: "test", code: 500))
        
        let analytics = audioManager.getUsageAnalytics()
        
        XCTAssertEqual(analytics.totalRequests, 2)
        XCTAssertEqual(analytics.totalBytesUploaded, 1024)
        XCTAssertEqual(analytics.keyHealth.healthyKeys, 2)
        XCTAssertEqual(analytics.keyHealth.disabledKeys, 0)
        XCTAssertEqual(analytics.keyHealth.totalKeys, 3)
        XCTAssertEqual(analytics.averageErrorsPerKey, 0.33, accuracy: 0.01)
    }
    
    func testUsageAnalyticsWithNoUsage() async {
        let analytics = audioManager.getUsageAnalytics()
        
        XCTAssertEqual(analytics.totalRequests, 0)
        XCTAssertEqual(analytics.totalBytesUploaded, 0)
        XCTAssertEqual(analytics.keyHealth.healthyKeys, 3)
        XCTAssertEqual(analytics.averageErrorsPerKey, 0)
    }
    
    // MARK: - Test Key Optimization
    
    func testOptimizeKeyUsage() async {
        // Simulate some problematic usage
        for _ in 0..<5 {
            audioManager.keyManagerRef.reportError(for: testKeys[0], error: NSError(domain: "test", code: 500))
        }
        
        // Some successful usage
        for _ in 0..<10 {
            _ = audioManager.keyManagerRef.getAvailableKey()
            audioManager.keyManagerRef.reportSuccess(for: testKeys[1])
        }
        
        let optimization = audioManager.optimizeKeyUsage()
        
        XCTAssertFalse(optimization.recommendations.isEmpty)
        XCTAssertTrue(optimization.recommendations.contains { $0.contains(testKeys[0].prefix(8)) })
        XCTAssertGreaterThan(optimization.healthScore, 0)
        XCTAssertLessThanOrEqual(optimization.healthScore, 100)
    }
    
    func testOptimizeKeyUsageWithHealthyKeys() async {
        // All keys are healthy
        for key in testKeys {
            _ = audioManager.keyManagerRef.getAvailableKey()
            audioManager.keyManagerRef.reportSuccess(for: key)
        }
        
        let optimization = audioManager.optimizeKeyUsage()
        
        XCTAssertEqual(optimization.healthScore, 100)
        XCTAssertTrue(optimization.recommendations.isEmpty)
    }
    
    // MARK: - Test Smart Scheduling
    
    func testScheduleSmartUploads() async throws {
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        let audioFiles = [testAudioURL]
        let targetTime = Date().addingTimeInterval(3600) // 1 hour from now
        
        let schedule = try? await audioManager.scheduleSmartUploads(
            audioFileURLs: audioFiles,
            estimatedDurationPerFile: 30.0,
            targetCompletionTime: targetTime
        )
        
        XCTAssertNotNil(schedule)
        XCTAssertEqual(schedule?.numberOfBatches, 1)
        XCTAssertEqual(schedule?.recommendedBatchSize, 1)
        XCTAssertEqual(schedule?.schedule.count, 1)
        
        if let firstBatch = schedule?.schedule.first {
            XCTAssertEqual(firstBatch.files.count, 1)
            XCTAssertEqual(firstBatch.estimatedDuration, 30.0)
            XCTAssertLessThanOrEqual(firstBatch.scheduledTime, targetTime)
        }
    }
    
    func testScheduleSmartUploadsWithMultipleFiles() async throws {
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        // Create multiple file references (same file for testing)
        let audioFiles = Array(repeating: testAudioURL, count: 5)
        
        let schedule = try? await audioManager.scheduleSmartUploads(
            audioFileURLs: audioFiles,
            estimatedDurationPerFile: 30.0,
            targetCompletionTime: Date().addingTimeInterval(3600)
        )
        
        XCTAssertNotNil(schedule)
        XCTAssertGreaterThan(schedule!.numberOfBatches, 0)
        XCTAssertGreaterThan(schedule!.estimatedTotalDuration, 0)
        XCTAssertEqual(schedule!.schedule.reduce(0) { $0 + $1.files.count }, 5)
    }
    
    func testScheduleSmartUploadsWithEmptyArray() async {
        let schedule = try? await audioManager.scheduleSmartUploads(
            audioFileURLs: [],
            estimatedDurationPerFile: 30.0
        )
        
        XCTAssertNotNil(schedule)
        XCTAssertEqual(schedule?.numberOfBatches, 0)
        XCTAssertEqual(schedule?.schedule.count, 0)
    }
    
    // MARK: - Test Batch Transcription Integration
    
    func testBatchTranscribeWithKeyManagement() async throws {
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !apiKey.isEmpty else {
            throw XCTSkip("GEMINI_API_KEY not set")
        }
        
        // Use real API key for this test
        let realManager = GeminiAudioManagerEnhanced(
            apiKeys: [apiKey],
            strategy: .leastUsed
        )
        
        let progressHandlerExpectation = XCTestExpectation(description: "Progress handler called")
        var progressCalls = 0
        
        do {
            let results = try await realManager.batchTranscribeWithKeyManagement(
                audioFileURLs: [testAudioURL],
                language: "zh",
                systemInstruction: "请准确转录音频内容",
                maxConcurrent: 1,
                progressHandler: { progress, completed in
                    progressCalls += 1
                    if progress == 1.0 {
                        progressHandlerExpectation.fulfill()
                    }
                }
            )
            
            XCTAssertEqual(results.count, 1)
            XCTAssertFalse(results.first?.1.isEmpty ?? true)
            
        } catch {
            // This is expected without valid API key in CI
            print("Batch transcription test skipped due to API error: \(error)")
        }
        
        await fulfillment(of: [progressHandlerExpectation], timeout: 10)
        XCTAssertEqual(progressCalls, 1)
    }
    
    // MARK: - Test Key Manager Reference
    
    func testKeyManagerReference() {
        let keyManagerRef = audioManager.keyManagerRef
        
        XCTAssertNotNil(keyManagerRef)
        XCTAssertEqual(keyManagerRef.getKeyHealth().total, 3)
    }
    
    // MARK: - Test Error Handling
    
    func testErrorHandlingInBatchTranscription() async throws {
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        // Use invalid API key to test error handling
        let invalidManager = GeminiAudioManagerEnhanced(
            apiKeys: ["invalid_key"],
            strategy: .leastUsed
        )
        
        do {
            _ = try await invalidManager.batchTranscribeWithKeyManagement(
                audioFileURLs: [testAudioURL],
                language: "zh"
            )
            
            // Should not reach here
            XCTFail("Expected error with invalid API key")
            
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Test Performance
    
    func testPerformanceWithMultipleKeys() async {
        measure {
            let manager = GeminiAudioManagerEnhanced(
                apiKeys: Array(0..<10).map { "key_\($0)" },
                strategy: .leastUsed
            )
            
            // Simulate usage
            for _ in 0..<100 {
                if let key = manager.keyManagerRef.getAvailableKey() {
                    manager.keyManagerRef.reportSuccess(for: key, bytesUploaded: 1024)
                }
            }
            
            let analytics = manager.getUsageAnalytics()
            XCTAssertEqual(analytics.totalRequests, 100)
        }
    }
}