//
//  GeminiAudioManager.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import SwiftyBeaver

/// A high-level manager that combines audio upload and Gemini API interactions
public class GeminiAudioManager {
    
    private let client: GeminiClient
    private let uploader: GeminiAudioUploader
    private let logger: SwiftyBeaver.Type
    
    /// Initialize the audio manager
    public init(
        client: GeminiClient,
        uploader: GeminiAudioUploader? = nil,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.client = client
        self.uploader = uploader ?? GeminiAudioUploader(
            baseURL: client.baseURL.absoluteString,
            logger: logger
        )
        self.logger = logger
    }
    
    /// Transcribe audio file to text
    public func transcribe(
        audioFileURL: URL,
        model: GeminiClient.Model = .gemini25Flash,
        language: String? = nil,
        systemInstruction: String? = nil,
        displayName: String? = nil
    ) async throws -> String {
        let session = uploader.startSession(apiKey: client.getNextApiKey())
        defer { uploader.endSession(session) }
        
        // Upload audio
        let fileInfo = try await uploader.uploadAudio(
            at: audioFileURL,
            displayName: displayName,
            session: session
        )
        
        // Transcribe
        return try await client.transcribeAudio(
            model: model,
            audioFileURI: fileInfo.uri,
            mimeType: fileInfo.mimeType ?? "audio/mpeg",
            language: language,
            systemInstruction: systemInstruction
        )
    }
    
    /// Analyze audio content with custom prompt
    public func analyze(
        audioFileURL: URL,
        prompt: String,
        model: GeminiClient.Model = .gemini25Flash,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        displayName: String? = nil
    ) async throws -> String {
        let session = uploader.startSession(apiKey: client.getNextApiKey())
        defer { uploader.endSession(session) }
        
        // Upload audio
        let fileInfo = try await uploader.uploadAudio(
            at: audioFileURL,
            displayName: displayName,
            session: session
        )
        
        // Analyze
        return try await client.analyzeAudio(
            model: model,
            audioFileURI: fileInfo.uri,
            mimeType: fileInfo.mimeType ?? "audio/mpeg",
            prompt: prompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    /// Transcribe multiple audio files
    public func batchTranscribe(
        audioFileURLs: [URL],
        displayNames: [String?] = [],
        model: GeminiClient.Model = .gemini25Flash,
        language: String? = nil,
        systemInstruction: String? = nil
    ) async throws -> [(String, String)] {
        let session = uploader.startSession(apiKey: client.getNextApiKey())
        defer { uploader.endSession(session) }
        
        // Upload all files
        let fileInfos = try await uploader.uploadAudioFiles(
            at: audioFileURLs,
            displayNames: displayNames,
            session: session
        )
        
        // Transcribe all files
        var results: [(String, String)] = []
        
        for fileInfo in fileInfos {
            guard let mimeType = fileInfo.mimeType else { continue }
            
            let transcription = try await client.transcribeAudio(
                model: model,
                audioFileURI: fileInfo.uri,
                mimeType: mimeType,
                language: language,
                systemInstruction: systemInstruction
            )
            
            results.append((
                fileInfo.displayName ?? fileInfo.name,
                transcription
            ))
        }
        
        return results
    }
    
    /// Get audio file information
    public func getAudioInfo(audioFileURL: URL) -> GeminiAudioUploader.AudioMetadata {
        return GeminiAudioUploader.AudioMetadata(
            url: audioFileURL,
            mimeType: "audio/mpeg", // Will be updated by extractor
            format: .mp3, // Will be updated by extractor
            size: 0, // Will be updated by extractor
            displayName: audioFileURL.lastPathComponent
        )
    }
    
    /// Check if audio format is supported
    public func isFormatSupported(_ fileURL: URL) -> Bool {
        return uploader.isFormatSupported(fileURL)
    }
    
    /// Get supported audio formats
    public var supportedFormats: [GeminiAudioUploader.AudioFormat] {
        return uploader.supportedFormats
    }
}

// MARK: - Convenience Methods

extension GeminiAudioManager {
    
    /// Transcribe with custom instructions
    public func transcribeWithInstructions(
        audioFileURL: URL,
        instructions: String,
        model: GeminiClient.Model = .gemini25Flash,
        language: String? = nil
    ) async throws -> String {
        let systemInstruction = """
        You are a professional transcriber. \(instructions)
        
        Please provide:
        1. Accurate transcription of all spoken words
        2. Proper punctuation and capitalization
        3. Speaker identification if multiple speakers are present
        4. Timestamps for important sections
        5. Notes on any unclear or ambiguous sections
        """
        
        return try await transcribe(
            audioFileURL: audioFileURL,
            model: model,
            language: language,
            systemInstruction: systemInstruction
        )
    }
    
    /// Summarize audio content
    public func summarize(
        audioFileURL: URL,
        maxLength: Int = 200,
        model: GeminiClient.Model = .gemini25Flash
    ) async throws -> String {
        let prompt = """
        Please summarize this audio content in \(maxLength) words or less.
        
        Include:
        - Main topics discussed
        - Key points or decisions made
        - Overall sentiment or tone
        - Action items or next steps (if any)
        """
        
        return try await analyze(
            audioFileURL: audioFileURL,
            prompt: prompt,
            model: model
        )
    }
    
    /// Extract key insights from audio
    public func extractInsights(
        audioFileURL: URL,
        model: GeminiClient.Model = .gemini25Flash
    ) async throws -> String {
        let prompt = """
        Analyze this audio and extract key insights:
        
        1. Main themes or topics
        2. Important quotes or statements
        3. Decisions or conclusions
        4. Action items or next steps
        5. Sentiment analysis
        6. Any notable patterns or trends
        
        Please format your response clearly with bullet points.
        """
        
        return try await analyze(
            audioFileURL: audioFileURL,
            prompt: prompt,
            model: model
        )
    }
}