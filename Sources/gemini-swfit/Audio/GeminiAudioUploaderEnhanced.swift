//
//  GeminiAudioUploaderEnhanced.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import SwiftyBeaver

/// Enhanced audio uploader with intelligent key management and retry logic
public class GeminiAudioUploaderEnhanced: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let baseURL: String
    private let session: URLSession
    private let logger: SwiftyBeaver.Type
    @MainActor private var uploadQueue: [(URL, String?, Int)] = []
    
    // MARK: - Initialization
    
    public init(baseURL: String = "https://generativelanguage.googleapis.com", logger: SwiftyBeaver.Type = SwiftyBeaver.self) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)
        self.logger = logger
    }
    
    // MARK: - Enhanced Upload with Key Management
    
    /// Enhanced upload with automatic key management and retry logic
    public func uploadAudioWithKeyManagement(
        at fileURL: URL,
        keyManager: GeminiAPIKeyManager,
        displayName: String? = nil,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) async throws -> GeminiAudioUploader.UploadResponse.FileInfo {
        
        // Get file size for quota management
        let resources = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = resources.fileSize else {
            throw GeminiAudioUploader.UploadError.metadataExtractionFailed
        }
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                // Get available key
                guard let apiKey = await keyManager.getAvailableKey(for: Int64(fileSize)) else {
                    let waitTime = await keyManager.estimatedWaitTime()
                    throw GeminiAudioUploader.UploadError.uploadFailed(
                        NSError(domain: "GeminiAPI", code: 0, userInfo: [
                            "message": "No available API keys",
                            "estimatedWait": waitTime
                        ])
                    )
                }

                logger.info("Uploading audio with key: \(apiKey.prefix(8))... (attempt \(attempt))")

                // Perform upload using original uploader
                let uploader = GeminiAudioUploader(baseURL: baseURL, logger: logger)
                let session = GeminiAudioUploader.AudioSession(sessionID: UUID().uuidString, apiKey: apiKey)
                let result = try await uploader.uploadAudio(at: fileURL, displayName: displayName, session: session)

                // Report success
                await keyManager.reportSuccess(for: apiKey, bytesUploaded: Int64(fileSize))

                return result

            } catch {
                lastError = error

                // Report error to key manager
                if let apiKey = extractAPIKeyFromError(error) {
                    await keyManager.reportError(for: apiKey, error: error)
                }
                
                // Retry with exponential backoff
                if attempt < maxRetries {
                    let delay = retryDelay * pow(2, Double(attempt - 1))
                    logger.warning("Upload failed (attempt \(attempt)), retrying in \(delay)s: \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? GeminiAudioUploader.UploadError.uploadFailed(NSError(domain: "GeminiAPI", code: 0))
    }
    
    // MARK: - Batch Upload with Intelligent Scheduling
    
    /// Upload multiple files with intelligent key rotation and quota management
    public func batchUploadWithKeyManagement(
        audioFiles: [URL],
        displayNames: [String?] = [],
        keyManager: GeminiAPIKeyManager,
        maxConcurrent: Int = 3,
        progressHandler: ((Double, Int) -> Void)? = nil
    ) async throws -> [GeminiAudioUploader.UploadResponse.FileInfo] {
        
        let totalFiles = audioFiles.count
        var results: [GeminiAudioUploader.UploadResponse.FileInfo?] = Array(repeating: nil, count: totalFiles)
        var errors: [Int: Error] = [:]
        
        // Create upload tasks with optimal batch size
        let batchSize = keyManager.recommendedBatchSize(for: 10 * 1024 * 1024) // Assume 10MB average
        let chunks = stride(from: 0, to: totalFiles, by: batchSize).map {
            Array(audioFiles[$0..<min($0 + batchSize, totalFiles)])
        }
        
        var completedCount = 0
        
        for (chunkIndex, chunk) in chunks.enumerated() {
            // Process chunk with semaphore to limit concurrency
            await withTaskGroup(of: (index: Int, result: Result<GeminiAudioUploader.UploadResponse.FileInfo, Error>).self) { group in
                for (index, fileURL) in chunk.enumerated() {
                    let actualIndex = chunkIndex * batchSize + index
                    let displayName = index < displayNames.count ? displayNames[index] : nil
                    
                    group.addTask {
                        do {
                            let result = try await self.uploadAudioWithKeyManagement(
                                at: fileURL,
                                keyManager: keyManager,
                                displayName: displayName
                            )
                            return (actualIndex, .success(result))
                        } catch {
                            return (actualIndex, .failure(error))
                        }
                    }
                }
                
                for await (index, result) in group {
                    switch result {
                    case .success(let fileInfo):
                        results[index] = fileInfo
                    case .failure(let error):
                        errors[index] = error
                    }
                    
                    completedCount += 1
                    let progress = Double(completedCount) / Double(totalFiles)
                    progressHandler?(progress, completedCount)
                }
            }
            
            // Small delay between chunks to respect rate limits
            if chunkIndex < chunks.count - 1 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        // Check if all uploads succeeded
        if errors.isEmpty {
            return results.compactMap { $0 }
        } else {
            let failedIndices = errors.keys.sorted()
            logger.error("\(failedIndices.count) uploads failed: \(failedIndices)")
            
            // Return successful results
            let successfulResults = results.enumerated().compactMap { index, result in
                result != nil ? (index, result!) : nil
            }
            
            if !successfulResults.isEmpty {
                logger.info("Successfully uploaded \(successfulResults.count) out of \(totalFiles) files")
            }
            
            // Throw error with partial success info
            throw GeminiAudioUploader.UploadError.uploadFailed(
                NSError(domain: "GeminiAPI", code: 0, userInfo: [
                    "failedCount": errors.count,
                    "successfulCount": successfulResults.count,
                    "failedIndices": failedIndices
                ])
            )
        }
    }
    
    // MARK: - Upload Queue with Priority
    
    /// Add upload to queue with priority
    @MainActor
    public func enqueueUpload(
        fileURL: URL,
        displayName: String? = nil,
        priority: Int = 0
    ) {
        uploadQueue.append((fileURL, displayName, priority))
        uploadQueue.sort { $0.2 > $1.2 } // Higher priority first
    }
    
    /// Get current queue size
    @MainActor
    public var queueSize: Int {
        return uploadQueue.count
    }
    
    /// Process queued uploads with key management
    public func processQueue(
        keyManager: GeminiAPIKeyManager,
        progressHandler: ((Double, Int) -> Void)? = nil
    ) async throws -> [GeminiAudioUploader.UploadResponse.FileInfo] {
        
        let filesToProcess = await MainActor.run { [self] in
            let files = uploadQueue
            uploadQueue.removeAll()
            return files
        }
        
        guard !filesToProcess.isEmpty else {
            return []
        }
        
        let urls = filesToProcess.map { $0.0 }
        let displayNames = filesToProcess.map { $0.1 }
        
        return try await batchUploadWithKeyManagement(
            audioFiles: urls,
            displayNames: displayNames,
            keyManager: keyManager,
            progressHandler: progressHandler
        )
    }
    
    // MARK: - Private Methods
    
    private func extractAPIKeyFromError(_ error: Error) -> String? {
        // Try to extract API key from error description or user info
        if let nsError = error as NSError?,
           let apiKey = nsError.userInfo["apiKey"] as? String {
            return apiKey
        }
        
        // Look for API key in error description
        let errorDescription = error.localizedDescription
        let pattern = #"AIza[0-9A-Za-z\-_]{35}"#
        if let range = errorDescription.range(of: pattern, options: .regularExpression) {
            return String(errorDescription[range])
        }
        
        return nil
    }
}