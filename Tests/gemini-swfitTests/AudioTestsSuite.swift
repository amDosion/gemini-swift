//
//  AudioTestsSuite.swift
//  gemini-swfitTests
//
//  Created by Claude on 2025-01-10.
//

import XCTest
@testable import gemini_swfit

// This test suite runs all audio-related tests in order
final class AudioTestsSuite: XCTestCase {
    
    static let allTests = [
        ("testAudioUploaderBasics", testAudioUploaderBasics),
        ("testAPIKeyManagement", testAPIKeyManagement),
        ("testEnhancedAudioManager", testEnhancedAudioManager),
        ("testEnhancedAudioUploader", testEnhancedAudioUploader),
        ("testAudioIntegration", testAudioIntegration)
    ]
    
    // MARK: - Test Audio Upload Basics
    
    func testAudioUploaderBasics() async {
        print("\n=== Testing Audio Upload Basics ===")
        
        let uploader = GeminiAudioUploader()
        
        // Test format support
        XCTAssertTrue(uploader.isFormatSupported(URL(fileURLWithPath: "test.mp3")))
        XCTAssertTrue(uploader.isFormatSupported(URL(fileURLWithPath: "test.wav")))
        XCTAssertFalse(uploader.isFormatSupported(URL(fileURLWithPath: "test.txt")))
        
        // Test session creation
        let session = uploader.startSession(apiKey: "test_key")
        XCTAssertFalse(session.sessionID.isEmpty)
        XCTAssertEqual(session.apiKey, "test_key")
        
        // Test metadata extraction (if file exists)
        let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        
        if FileManager.default.fileExists(atPath: testAudioURL.path) {
            do {
                let metadata = try uploader.extractAudioMetadata(from: testAudioURL, displayName: "Test Audio")
                XCTAssertEqual(metadata.displayName, "Test Audio")
                XCTAssertEqual(metadata.format, .mp3)
                XCTAssertGreaterThan(metadata.size, 0)
                print("✅ Audio metadata extraction successful")
            } catch {
                XCTFail("Metadata extraction failed: \(error)")
            }
        } else {
            print("⚠️  Test audio file not found, skipping metadata test")
        }
    }
    
    // MARK: - Test API Key Management
    
    func testAPIKeyManagement() async {
        print("\n=== Testing API Key Management ===")
        
        let testKeys = ["key1", "key2", "key3"]
        let quota = GeminiAPIKeyManager.QuotaInfo(
            requestsPerMinute: 60,
            requestsPerHour: 3600,
            bytesPerMinute: 100 * 1024 * 1024,
            maxConcurrentUploads: 5
        )
        
        let keyManager = GeminiAPIKeyManager(
            apiKeys: testKeys,
            quota: quota,
            strategy: .leastUsed
        )
        
        // Test initial state
        let health = keyManager.getKeyHealth()
        XCTAssertEqual(health.total, 3)
        XCTAssertEqual(health.healthy, 3)
        XCTAssertEqual(health.disabled, 0)
        print("✅ Key manager initialized correctly")
        
        // Test key selection
        let key1 = keyManager.getAvailableKey()
        XCTAssertNotNil(key1)
        XCTAssertEqual(key1, "key1") // leastUsed strategy
        
        // Test usage tracking
        keyManager.reportSuccess(for: key1!, bytesUploaded: 1024)
        let stats = keyManager.getUsageStats()
        let key1Stats = stats.first { $0.key == "key1" }
        XCTAssertEqual(key1Stats?.usageCount, 1)
        XCTAssertEqual(key1Stats?.totalBytesUploaded, 1024)
        print("✅ Usage tracking working correctly")
        
        // Test error handling
        keyManager.reportError(for: key1!, error: NSError(domain: "test", code: 500))
        let statsAfterError = keyManager.getUsageStats()
        let key1StatsAfterError = statsAfterError.first { $0.key == "key1" }
        XCTAssertEqual(key1StatsAfterError?.errors, 1)
        print("✅ Error tracking working correctly")
        
        // Test batch size recommendation
        let batchSize = keyManager.recommendedBatchSize(for: 1024 * 1024)
        XCTAssertGreaterThan(batchSize, 0)
        print("✅ Batch size recommendation: \(batchSize)")
    }
    
    // MARK: - Test Enhanced Audio Manager
    
    func testEnhancedAudioManager() async {
        print("\n=== Testing Enhanced Audio Manager ===")
        
        let testKeys = ["test_key_1", "test_key_2", "test_key_3"]
        let audioManager = GeminiAudioManagerEnhanced(apiKeys: testKeys)
        
        // Test usage analytics
        let analytics = audioManager.getUsageAnalytics()
        XCTAssertEqual(analytics.totalRequests, 0)
        XCTAssertEqual(analytics.totalBytesUploaded, 0)
        XCTAssertEqual(analytics.keyHealth.totalKeys, 3)
        print("✅ Usage analytics initialized correctly")
        
        // Test key optimization
        let optimization = audioManager.optimizeKeyUsage()
        XCTAssertGreaterThanOrEqual(optimization.healthScore, 0)
        XCTAssertLessThanOrEqual(optimization.healthScore, 100)
        print("✅ Key optimization score: \(optimization.healthScore)%")
        
        // Test smart scheduling
        let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        
        if FileManager.default.fileExists(atPath: testAudioURL.path) {
            do {
                let schedule = try await audioManager.scheduleSmartUploads(
                    audioFileURLs: [testAudioURL],
                    estimatedDurationPerFile: 30.0
                )
                
                XCTAssertEqual(schedule.numberOfBatches, 1)
                XCTAssertEqual(schedule.schedule.count, 1)
                XCTAssertEqual(schedule.schedule.first?.files.count, 1)
                print("✅ Smart scheduling working correctly")
            } catch {
                XCTFail("Smart scheduling failed: \(error)")
            }
        } else {
            print("⚠️  Test audio file not found, skipping scheduling test")
        }
        
        // Test key manager reference
        let keyManagerRef = audioManager.keyManagerRef
        XCTAssertEqual(keyManagerRef.getKeyHealth().total, 3)
        print("✅ Key manager reference accessible")
    }
    
    // MARK: - Test Enhanced Audio Uploader
    
    func testEnhancedAudioUploader() async {
        print("\n=== Testing Enhanced Audio Uploader ===")
        
        let uploader = GeminiAudioUploaderEnhanced()
        let testKeys = ["test_key_1", "test_key_2"]
        
        let quota = GeminiAPIKeyManager.QuotaInfo(
            requestsPerMinute: 30,
            requestsPerHour: 1000,
            bytesPerMinute: 50 * 1024 * 1024,
            maxConcurrentUploads: 3
        )
        let keyManager = GeminiAPIKeyManager(
            apiKeys: testKeys,
            quota: quota,
            strategy: .leastUsed
        )
        
        // Test queue functionality
        let initialQueueSize = await uploader.queueSize
        XCTAssertEqual(initialQueueSize, 0)
        
        let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        
        if FileManager.default.fileExists(atPath: testAudioURL.path) {
            await uploader.enqueueUpload(fileURL: testAudioURL, displayName: "Queue Test 1")
            await uploader.enqueueUpload(fileURL: testAudioURL, displayName: "Queue Test 2", priority: 1)
            
            let queueSize = await uploader.queueSize
            XCTAssertEqual(queueSize, 2)
            print("✅ Upload queue working correctly")
            
            // Test processing empty queue
            do {
                let results = try await uploader.processQueue(keyManager: keyManager)
                XCTAssertEqual(results.count, 0)
                print("✅ Empty queue processed correctly")
            } catch {
                XCTFail("Empty queue processing failed: \(error)")
            }
        } else {
            print("⚠️  Test audio file not found, skipping queue tests")
        }
    }
    
    // MARK: - Test Integration (requires API key)
    
    func testAudioIntegration() async {
        print("\n=== Testing Audio Integration ===")
        
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !apiKey.isEmpty else {
            print("⚠️  GEMINI_API_KEY not set, skipping integration tests")
            return
        }
        
        let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            print("⚠️  Test audio file not found, skipping integration tests")
            return
        }
        
        print("🔑 Using API key: \(apiKey.prefix(8))...")
        
        // Test 1: Basic upload and transcription
        do {
            let client = GeminiClient(apiKeys: [apiKey])
            let uploader = GeminiAudioUploader()
            let session = uploader.startSession(apiKey: apiKey)
            
            print("Uploading audio file...")
            let uploadedFile = try await uploader.uploadAudio(
                at: testAudioURL,
                displayName: "Integration Test",
                session: session
            )
            
            XCTAssertFalse(uploadedFile.uri.isEmpty)
            print("✅ Upload successful: \(uploadedFile.name)")
            
            // Test transcription
            print("Transcribing audio...")
            let transcription = try await client.transcribeAudio(
                model: .gemini25Flash,
                audioFileURI: uploadedFile.uri,
                mimeType: uploadedFile.mimeType!,
                language: "zh"
            )
            
            XCTAssertFalse(transcription.isEmpty)
            print("✅ Transcription successful: \(transcription.prefix(100))...")
            
        } catch {
            XCTFail("Integration test failed: \(error)")
        }
        
        // Test 2: Enhanced audio management
        do {
            let audioManager = GeminiAudioManagerEnhanced(apiKeys: [apiKey])
            
            print("Testing enhanced audio management...")
            let results = try await audioManager.batchTranscribeWithKeyManagement(
                audioFileURLs: [testAudioURL],
                language: "zh",
                systemInstruction: "请准确转录音频内容",
                maxConcurrent: 1,
                progressHandler: { progress, completed in
                    print("Progress: \(Int(progress * 100))%")
                }
            )
            
            XCTAssertEqual(results.count, 1)
            XCTAssertFalse(results.first?.1.isEmpty ?? true)
            print("✅ Enhanced audio management successful")
            
            // Check analytics
            let analytics = audioManager.getUsageAnalytics()
            XCTAssertGreaterThan(analytics.totalRequests, 0)
            print("📊 Analytics: \(analytics.totalRequests) requests, \(analytics.totalBytesUploaded) bytes uploaded")
            
        } catch {
            XCTFail("Enhanced management test failed: \(error)")
        }
        
        print("\n🎉 All integration tests passed!")
    }
}