//
//  GeminiClient+Audio.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import SwiftyBeaver

extension GeminiClient {
    
    // MARK: - Audio Support
    
    /// Generate content with audio file
    public func generateContentWithAudio(
        model: Model,
        audioFileURI: String,
        mimeType: String,
        prompt: String = "Describe this audio clip",
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let audioPart = Part(fileData: FileData(mimeType: mimeType, fileUri: audioFileURI))
        let textPart = Part(text: prompt)
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [textPart, audioPart])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        return try await performRequest(model: model, request: request)
    }
    
    /// Transcribe audio to text
    public func transcribeAudio(
        model: Model,
        audioFileURI: String,
        mimeType: String,
        language: String? = nil,
        systemInstruction: String? = nil
    ) async throws -> String {
        let prompt = language != nil ? 
            "Transcribe this audio to text. Language: \(language!)" : 
            "Transcribe this audio to text."
        
        let response = try await generateContentWithAudio(
            model: model,
            audioFileURI: audioFileURI,
            mimeType: mimeType,
            prompt: prompt,
            systemInstruction: systemInstruction
        )
        
        guard let candidate = response.candidates.first,
              let textPart = candidate.content.parts.first,
              let transcription = textPart.text else {
            throw GeminiError.invalidResponse
        }
        
        return transcription
    }
    
    /// Analyze audio content with custom prompt
    public func analyzeAudio(
        model: Model,
        audioFileURI: String,
        mimeType: String,
        prompt: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        let response = try await generateContentWithAudio(
            model: model,
            audioFileURI: audioFileURI,
            mimeType: mimeType,
            prompt: prompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        guard let candidate = response.candidates.first,
              let textPart = candidate.content.parts.first,
              let analysis = textPart.text else {
            throw GeminiError.invalidResponse
        }
        
        return analysis
    }
    
    /// Convenience method to upload and process audio in one call
    public func processAudio(
        model: Model,
        audioFileURL: URL,
        prompt: String = "Describe this audio clip",
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        displayName: String? = nil
    ) async throws -> String {
        // Create uploader instance
        let uploader = GeminiAudioUploader(baseURL: baseURL.absoluteString, logger: logger)
        
        // Start upload session
        let session = uploader.startSession(apiKey: getNextApiKey())
        
        // Upload audio file
        let fileInfo = try await uploader.uploadAudio(
            at: audioFileURL,
            displayName: displayName,
            session: session
        )
        
        // Process with Gemini
        let result = try await analyzeAudio(
            model: model,
            audioFileURI: fileInfo.uri,
            mimeType: fileInfo.mimeType ?? "audio/mpeg",
            prompt: prompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        // End session
        uploader.endSession(session)
        
        return result
    }
    
    /// Convenience method to upload and transcribe audio in one call
    public func uploadAndTranscribeAudio(
        model: Model,
        audioFileURL: URL,
        language: String? = nil,
        systemInstruction: String? = nil,
        displayName: String? = nil
    ) async throws -> String {
        // Create uploader instance
        let uploader = GeminiAudioUploader(baseURL: baseURL.absoluteString, logger: logger)
        
        // Start upload session
        let session = uploader.startSession(apiKey: getNextApiKey())
        
        // Upload audio file
        let fileInfo = try await uploader.uploadAudio(
            at: audioFileURL,
            displayName: displayName,
            session: session
        )
        
        // Transcribe with Gemini
        let transcription = try await transcribeAudio(
            model: model,
            audioFileURI: fileInfo.uri,
            mimeType: fileInfo.mimeType ?? "audio/mpeg",
            language: language,
            systemInstruction: systemInstruction
        )
        
        // End session
        uploader.endSession(session)
        
        return transcription
    }
}