//
//  GeminiAudioManagerEnhanced.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import SwiftyBeaver

/// Enhanced audio manager with intelligent key management
public class GeminiAudioManagerEnhanced {
    
    // MARK: - Properties
    
    private let client: GeminiClient
    private let uploader: GeminiAudioUploader
    private let keyManager: GeminiAPIKeyManager
    private let logger: SwiftyBeaver.Type
    
    // MARK: - Initialization
    
    /// Initialize with automatic key management
    public init(
        apiKeys: [String],
        quota: GeminiAPIKeyManager.QuotaInfo? = nil,
        strategy: GeminiAPIKeyManager.SelectionStrategy = .leastUsed,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.client = GeminiClient(apiKeys: apiKeys, logger: logger)
        self.keyManager = GeminiAPIKeyManager(
            apiKeys: apiKeys,
            quota: quota ?? GeminiAPIKeyManager.QuotaInfo(),
            strategy: strategy,
            logger: logger
        )
        self.uploader = GeminiAudioUploader(baseURL: client.baseURL.absoluteString, logger: logger)
        self.logger = logger
    }
    
    // MARK: - Enhanced Batch Processing
    
    /// Enhanced batch transcription with intelligent key management
    public func batchTranscribeWithKeyManagement(
        audioFileURLs: [URL],
        displayNames: [String?] = [],
        language: String? = nil,
        systemInstruction: String? = nil,
        maxConcurrent: Int = 3,
        progressHandler: ((Double, Int) -> Void)? = nil
    ) async throws -> [(String, String)] {
        
        // Step 1: Upload all files with key management
        let uploaderEnhanced = GeminiAudioUploaderEnhanced(baseURL: client.baseURL.absoluteString, logger: logger)
        let uploadedFiles = try await uploaderEnhanced.batchUploadWithKeyManagement(
            audioFiles: audioFileURLs,
            displayNames: displayNames,
            keyManager: keyManager,
            maxConcurrent: maxConcurrent,
            progressHandler: progressHandler
        )
        
        // Step 2: Transcribe all uploaded files
        var results: [(String, String)] = []
        let totalFiles = uploadedFiles.count
        
        for (index, fileInfo) in uploadedFiles.enumerated() {
            guard let mimeType = fileInfo.mimeType else { continue }
            
            do {
                let transcription = try await client.transcribeAudio(
                    model: .gemini25Flash,
                    audioFileURI: fileInfo.uri,
                    mimeType: mimeType,
                    language: language,
                    systemInstruction: systemInstruction
                )
                
                results.append((fileInfo.displayName ?? fileInfo.name, transcription))
                
                // Report success to key manager
                if let apiKey = keyManager.getAvailableKey() {
                    keyManager.reportSuccess(for: apiKey)
                }
                
                // Update progress
                let progress = Double(index + 1) / Double(totalFiles)
                progressHandler?(progress, index + 1)
                
            } catch {
                logger.error("Failed to transcribe \(fileInfo.displayName ?? fileInfo.name): \(error)")
                
                // Report error
                if let apiKey = keyManager.getAvailableKey() {
                    keyManager.reportError(for: apiKey, error: error)
                }
                
                // Add error result
                results.append((fileInfo.displayName ?? fileInfo.name, "Error: \(error.localizedDescription)"))
            }
        }
        
        return results
    }
    
    // MARK: - Smart Upload Scheduling
    
    /// Schedule uploads to optimize key usage and avoid rate limits
    public func scheduleSmartUploads(
        audioFileURLs: [URL],
        displayNames: [String?] = [],
        estimatedDurationPerFile: TimeInterval = 30.0,
        targetCompletionTime: Date? = nil
    ) async throws -> ScheduledUploadResult {
        
        let totalFiles = audioFileURLs.count
        let estimatedTotalTime = TimeInterval(totalFiles) * estimatedDurationPerFile
        
        // Calculate optimal batch size and timing
        let batchSize = keyManager.recommendedBatchSize(for: 10 * 1024 * 1024) // 10MB estimate
        let numberOfBatches = Int(ceil(Double(totalFiles) / Double(batchSize)))
        
        // Calculate start times for each batch
        var schedule: [ScheduledBatch] = []
        let now = Date()
        
        for batchIndex in 0..<numberOfBatches {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, totalFiles)
            let batchFiles = Array(audioFileURLs[startIndex..<endIndex])
            let batchNames = displayNames.isEmpty ? [] : Array(displayNames[startIndex..<endIndex])
            
            // Calculate delay to avoid rate limits
            let delay = TimeInterval(batchIndex) * 60.0 // 1 minute between batches
            
            schedule.append(ScheduledBatch(
                files: batchFiles,
                displayNames: batchNames,
                scheduledTime: now.addingTimeInterval(delay),
                estimatedDuration: TimeInterval(batchFiles.count) * estimatedDurationPerFile
            ))
        }
        
        return ScheduledUploadResult(
            schedule: schedule,
            estimatedTotalDuration: estimatedTotalTime,
            recommendedBatchSize: batchSize,
            numberOfBatches: numberOfBatches
        )
    }
    
    // MARK: - Usage Analytics
    
    /// Get comprehensive usage statistics
    public func getUsageAnalytics() -> UsageAnalytics {
        let keyStats = keyManager.getUsageStats()
        let health = keyManager.getKeyHealth()
        
        return UsageAnalytics(
            totalRequests: keyStats.reduce(0) { $0 + $1.usageCount },
            totalBytesUploaded: keyStats.reduce(0) { $0 + $1.totalBytesUploaded },
            averageErrorsPerKey: keyStats.count > 0 ? 
                Double(keyStats.reduce(0) { $0 + $1.errors }) / Double(keyStats.count) : 0,
            keyHealth: KeyHealthStats(
                healthyKeys: health.healthy,
                disabledKeys: health.disabled,
                totalKeys: health.total
            ),
            topPerformingKey: keyStats.max { $0.usageCount < $1.usageCount },
            leastUsedKey: keyStats.min { $0.usageCount < $1.usageCount },
            timestamp: Date()
        )
    }
    
    /// Optimize key usage based on historical data
    public func optimizeKeyUsage() -> KeyOptimizationResult {
        let stats = keyManager.getUsageStats()
        var recommendations: [String] = []
        
        // Analyze usage patterns and generate recommendations
        for keyStat in stats {
            if Double(keyStat.errors) > Double(keyStat.usageCount) * 0.1 { // >10% error rate
                recommendations.append("Key \(keyStat.key.prefix(8))... has high error rate (\(keyStat.errors)/\(keyStat.usageCount))")
            }
            
            if keyStat.usageCount == 0 {
                recommendations.append("Key \(keyStat.key.prefix(8))... has never been used")
            }
            
            if keyStat.isDisabled {
                recommendations.append("Key \(keyStat.key.prefix(8))... is currently disabled")
            }
        }
        
        return KeyOptimizationResult(
            recommendations: recommendations,
            suggestedStrategy: stats.count > 5 ? .leastUsed : .roundRobin,
            healthScore: calculateHealthScore(stats)
        )
    }
    
    // MARK: - Access to Key Manager
    
    /// Get the underlying key manager for advanced operations
    public var keyManagerRef: GeminiAPIKeyManager {
        return keyManager
    }
    
    // MARK: - Private Methods
    
    private func calculateHealthScore(_ stats: [GeminiAPIKeyManager.KeyUsage]) -> Double {
        let totalKeys = stats.count
        guard totalKeys > 0 else { return 0 }
        
        let healthyKeys = stats.filter { !$0.isDisabled }.count
        let totalErrors = stats.reduce(0) { $0 + $1.errors }
        let totalUsage = stats.reduce(0) { $0 + $1.usageCount }
        let errorRate = totalUsage > 0 ? Double(totalErrors) / Double(totalUsage) : 0
        
        let healthScore = (Double(healthyKeys) / Double(totalKeys)) * 100 * (1 - errorRate)
        return max(0, min(100, healthScore))
    }
}

// MARK: - Supporting Types

public struct ScheduledUploadResult {
    public let schedule: [ScheduledBatch]
    public let estimatedTotalDuration: TimeInterval
    public let recommendedBatchSize: Int
    public let numberOfBatches: Int
}

public struct ScheduledBatch {
    public let files: [URL]
    public let displayNames: [String?]
    public let scheduledTime: Date
    public let estimatedDuration: TimeInterval
}

public struct UsageAnalytics {
    public let totalRequests: Int
    public let totalBytesUploaded: Int64
    public let averageErrorsPerKey: Double
    public let keyHealth: KeyHealthStats
    public let topPerformingKey: GeminiAPIKeyManager.KeyUsage?
    public let leastUsedKey: GeminiAPIKeyManager.KeyUsage?
    public let timestamp: Date
}

public struct KeyHealthStats {
    public let healthyKeys: Int
    public let disabledKeys: Int
    public let totalKeys: Int
    
    public var healthPercentage: Double {
        return totalKeys > 0 ? Double(healthyKeys) / Double(totalKeys) * 100 : 0
    }
}

public struct KeyOptimizationResult {
    public let recommendations: [String]
    public let suggestedStrategy: GeminiAPIKeyManager.SelectionStrategy
    public let healthScore: Double
}