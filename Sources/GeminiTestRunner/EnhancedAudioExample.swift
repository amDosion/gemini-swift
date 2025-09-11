//
//  EnhancedAudioExample.swift
//  GeminiTestRunner
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import gemini_swfit

/// Example demonstrating enhanced audio upload with intelligent key management
public class EnhancedAudioExample {
    public let client: GeminiClient
    public let apiKey: String
    
    public init(client: GeminiClient, apiKey: String) {
        self.client = client
        self.apiKey = apiKey
    }
    
    /// Example: Enhanced batch upload with key management
    public func runEnhancedBatchExample() async {
        print("=== Enhanced Batch Upload Example ===")
        
        // Create multiple API keys for demonstration
        let apiKeys = [
            apiKey,
            apiKey, // In real scenario, these would be different keys
            apiKey
        ]
        
        // Initialize key manager with custom quotas
        let quota = GeminiAPIKeyManager.QuotaInfo(
            requestsPerMinute: 30,
            requestsPerHour: 1000,
            bytesPerMinute: 50 * 1024 * 1024, // 50MB per minute
            maxConcurrentUploads: 3
        )
        
        // Get sample audio files
        let audioFiles = getMultipleAudioFiles()
        
        guard !audioFiles.isEmpty else {
            print("No audio files found for testing")
            return
        }
        
        print("Found \(audioFiles.count) audio files")
        print("Starting enhanced batch upload...")
        
        do {
            // Initialize enhanced audio manager
            let audioManager = GeminiAudioManagerEnhanced(
                apiKeys: apiKeys,
                quota: quota,
                strategy: .leastUsed
            )
            
            // Upload and transcribe with key management
            let results = try await audioManager.batchTranscribeWithKeyManagement(
                audioFileURLs: audioFiles,
                language: "en",
                systemInstruction: "Please provide accurate transcription",
                maxConcurrent: 2,
                progressHandler: { progress, completed in
                    print("Progress: \(Int(progress * 100))% (\(completed)/\(audioFiles.count))")
                }
            )
            
            print("\n=== Results ===")
            for (filename, transcription) in results {
                print("\nFile: \(filename)")
                print("Transcription: \(transcription.prefix(100))...")
            }
            
            // Show usage statistics
            let analytics = audioManager.getUsageAnalytics()
            print("\n=== Usage Analytics ===")
            print("Total Requests: \(analytics.totalRequests)")
            print("Total Bytes Uploaded: \(analytics.totalBytesUploaded)")
            print("Key Health: \(analytics.keyHealth.healthPercentage)%")
            print("Average Error Rate: \(String(format: "%.2f", analytics.averageErrorsPerKey))")
            
        } catch {
            print("Enhanced batch upload failed: \(error)")
        }
    }
    
    /// Example: Smart upload scheduling
    public func runSmartSchedulingExample() async {
        print("\n=== Smart Scheduling Example ===")
        
        let apiKeys = [apiKey]
        let audioManager = GeminiAudioManagerEnhanced(apiKeys: apiKeys)
        
        let audioFiles = getMultipleAudioFiles()
        
        guard !audioFiles.isEmpty else {
            print("No audio files found for testing")
            return
        }
        
        do {
            // Get optimal upload schedule
            let schedule = try await audioManager.scheduleSmartUploads(
                audioFileURLs: audioFiles,
                estimatedDurationPerFile: 45.0,
                targetCompletionTime: Date().addingTimeInterval(3600) // 1 hour from now
            )
            
            print("\n=== Upload Schedule ===")
            print("Total Batches: \(schedule.numberOfBatches)")
            print("Batch Size: \(schedule.recommendedBatchSize)")
            print("Estimated Duration: \(String(format: "%.0f", schedule.estimatedTotalDuration / 60)) minutes")
            
            for (index, batch) in schedule.schedule.enumerated() {
                print("\nBatch \(index + 1):")
                print("  - Files: \(batch.files.count)")
                print("  - Scheduled: \(batch.scheduledTime)")
                print("  - Duration: \(String(format: "%.0f", batch.estimatedDuration))s")
            }
            
        } catch {
            print("Smart scheduling failed: \(error)")
        }
    }
    
    /// Example: Key optimization
    public func runKeyOptimizationExample() async {
        print("\n=== Key Optimization Example ===")
        
        // Simulate some usage
        let apiKeys = [apiKey, apiKey, apiKey]
        let keyManager = GeminiAPIKeyManager(apiKeys: apiKeys)
        
        // Simulate some key usage
        for _ in 0..<50 {
            _ = keyManager.getAvailableKey()
        }
        
        // Get optimization recommendations
        let audioManager = GeminiAudioManagerEnhanced(apiKeys: apiKeys)
        let optimization = audioManager.optimizeKeyUsage()
        
        print("\n=== Optimization Results ===")
        print("Health Score: \(String(format: "%.1f", optimization.healthScore))%")
        print("Suggested Strategy: \(optimization.suggestedStrategy)")
        
        if !optimization.recommendations.isEmpty {
            print("\nRecommendations:")
            for recommendation in optimization.recommendations {
                print("  - \(recommendation)")
            }
        }
        
        // Show key health
        let health = keyManager.getKeyHealth()
        print("\nKey Health: \(health.healthy)/\(health.total) healthy")
        
        // Show usage stats
        let stats = keyManager.getUsageStats()
        print("\nUsage Statistics:")
        for stat in stats {
            print("  Key \(stat.key.prefix(8))...: \(stat.usageCount) uses, \(stat.errors) errors")
        }
    }
    
    /// Example: Retry mechanism demonstration
    public func runRetryMechanismExample() async {
        print("\n=== Retry Mechanism Example ===")
        
        let apiKeys = [apiKey]
        let uploader = GeminiAudioUploaderEnhanced()
        let keyManager = GeminiAPIKeyManager(apiKeys: apiKeys)
        
        guard let audioURL = getSampleAudioFile() else {
            print("No sample audio file found")
            return
        }
        
        print("Testing retry mechanism with file: \(audioURL.lastPathComponent)")
        
        do {
            // This will retry on failures
            let fileInfo = try await uploader.uploadAudioWithKeyManagement(
                at: audioURL,
                keyManager: keyManager,
                displayName: "Retry Test",
                maxRetries: 3,
                retryDelay: 2.0
            )
            
            print("Upload successful after retries!")
            print("File URI: \(fileInfo.uri)")
            
        } catch {
            print("Upload failed after all retries: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSampleAudioFile() -> URL? {
        let paths = [
            Bundle.main.path(forResource: "sample", ofType: "mp3"),
            "/tmp/sample.mp3",
            "/Users/Shared/sample.mp3"
        ]
        
        for path in paths {
            if let path = path, FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        return nil
    }
    
    private func getMultipleAudioFiles() -> [URL] {
        let patterns = [
            "/tmp/sample1.mp3",
            "/tmp/sample2.mp3",
            "/tmp/sample3.mp3",
            "/Users/Shared/audio1.mp3",
            "/Users/Shared/audio2.mp3"
        ]
        
        return patterns.compactMap { path in
            FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
        }
    }
}

// MARK: - Extension for GeminiTestRunner

extension GeminiTestRunner {
    public func runEnhancedAudioExamples(client: GeminiClient, apiKey: String) async {
        let example = EnhancedAudioExample(client: client, apiKey: apiKey)
        
        await example.runEnhancedBatchExample()
        await example.runSmartSchedulingExample()
        await example.runKeyOptimizationExample()
        await example.runRetryMechanismExample()
    }
}