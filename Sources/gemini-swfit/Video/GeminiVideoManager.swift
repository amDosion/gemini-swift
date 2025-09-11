//
//  GeminiVideoManager.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import SwiftyBeaver

/// A high-level manager that combines video upload and Gemini API interactions
public class GeminiVideoManager {
    
    private let client: GeminiClient
    private let uploader: GeminiVideoUploader
    private let logger: SwiftyBeaver.Type
    
    /// Initialize the video manager
    public init(
        client: GeminiClient,
        uploader: GeminiVideoUploader? = nil,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.client = client
        self.uploader = uploader ?? GeminiVideoUploader(
            baseURL: client.baseURL.absoluteString,
            logger: logger
        )
        self.logger = logger
    }
    
    /// Analyze video content with custom prompt
    public func analyze(
        videoFileURL: URL,
        prompt: String,
        model: GeminiClient.Model = .gemini25Flash,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        displayName: String? = nil
    ) async throws -> String {
        let session = uploader.startSession(apiKey: client.getNextApiKey())
        defer { uploader.endSession(session) }
        
        // Upload video
        let fileInfo = try await uploader.uploadVideo(
            at: videoFileURL,
            displayName: displayName,
            session: session
        )
        
        // Analyze
        return try await client.analyzeVideo(
            model: model,
            videoFileURI: fileInfo.uri!,
            mimeType: fileInfo.mimeType ?? "video/mp4",
            prompt: prompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    /// Transcribe video audio to text
    public func transcribe(
        videoFileURL: URL,
        model: GeminiClient.Model = .gemini25Flash,
        language: String? = nil,
        systemInstruction: String? = nil,
        displayName: String? = nil
    ) async throws -> String {
        let prompt = language != nil ?
            "Transcribe the audio from this video to text. Language: \(language!)" :
            "Transcribe the audio from this video to text."
        
        return try await analyze(
            videoFileURL: videoFileURL,
            prompt: prompt,
            model: model,
            systemInstruction: systemInstruction,
            displayName: displayName
        )
    }
    
    /// Summarize video content
    public func summarize(
        videoFileURL: URL,
        maxLength: Int = 200,
        model: GeminiClient.Model = .gemini25Flash
    ) async throws -> String {
        let prompt = """
        Please summarize this video content in \(maxLength) words or less.
        
        Include:
        - Main topics or themes presented
        - Key points or information conveyed
        - Visual elements and their significance
        - Overall message or purpose
        - Important actions or events shown
        """
        
        return try await analyze(
            videoFileURL: videoFileURL,
            prompt: prompt,
            model: model
        )
    }
    
    /// Extract key moments from video
    public func extractKeyMoments(
        videoFileURL: URL,
        model: GeminiClient.Model = .gemini25Flash
    ) async throws -> String {
        let prompt = """
        Analyze this video and identify key moments:
        
        1. Opening/closing scenes
        2. Important transitions
        3. Critical actions or events
        4. Significant visual elements
        5. Key audio cues or dialogue
        6. Notable changes in setting or mood
        
        Please provide timestamps (if possible) and descriptions for each key moment.
        """
        
        return try await analyze(
            videoFileURL: videoFileURL,
            prompt: prompt,
            model: model
        )
    }
    
    /// Generate video quiz with answer key
    public func generateQuiz(
        videoFileURL: URL,
        questionCount: Int = 5,
        model: GeminiClient.Model = .gemini25Flash
    ) async throws -> String {
        let prompt = """
        Based on this video, create a quiz with \(questionCount) questions and an answer key.
        
        The quiz should test comprehension of:
        - Main content and themes
        - Specific details shown
        - Sequence of events
        - Key information presented
        
        Format:
        1. Question text
        A) Option A
        B) Option B
        C) Option C
        D) Option D
        
        Answer Key:
        1. [Correct answer letter]
        """
        
        return try await analyze(
            videoFileURL: videoFileURL,
            prompt: prompt,
            model: model
        )
    }
    
    /// Analyze video content for educational content
    public func analyzeEducationalContent(
        videoFileURL: URL,
        model: GeminiClient.Model = .gemini25Flash
    ) async throws -> String {
        let prompt = """
        Analyze this educational video and provide:
        
        1. Subject matter and topic
        2. Learning objectives
        3. Key concepts taught
        4. Teaching methods used
        5. Target audience level
        6. Educational effectiveness
        7. Suggestions for improvement
        
        Please be specific and detailed in your analysis.
        """
        
        return try await analyze(
            videoFileURL: videoFileURL,
            prompt: prompt,
            model: model
        )
    }
    
    /// Detect objects and scenes in video
    public func detectObjectsAndScenes(
        videoFileURL: URL,
        model: GeminiClient.Model = .gemini25Flash
    ) async throws -> String {
        let prompt = """
        Analyze this video and identify:
        
        1. Main objects present
        2. Settings and environments
        3. People and their roles
        4. Actions and activities
        5. Scene changes and transitions
        6. Visual elements and their significance
        
        Provide timestamps for when different elements appear if possible.
        """
        
        return try await analyze(
            videoFileURL: videoFileURL,
            prompt: prompt,
            model: model
        )
    }
    
    /// Get video file information
    public func getVideoInfo(videoFileURL: URL) throws -> GeminiVideoUploader.VideoMetadata {
        return try uploader.getVideoMetadata(videoFileURL)
    }
    
    /// Check if video format is supported
    public func isFormatSupported(_ fileURL: URL) -> Bool {
        return uploader.isFormatSupported(fileURL)
    }
    
    /// Get supported video formats
    public var supportedFormats: [GeminiVideoUploader.VideoFormat] {
        return uploader.supportedFormats
    }
    
    // MARK: - YouTube Video Methods
    
    /// Analyze YouTube video content
    public func analyzeYouTubeVideo(
        videoURL: String,
        prompt: String,
        model: GeminiClient.Model = .gemini25Flash,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        return try await client.analyzeYouTubeVideo(
            model: model,
            videoURL: videoURL,
            prompt: prompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    /// Summarize YouTube video
    public func summarizeYouTubeVideo(
        videoURL: String,
        maxLength: Int = 100,
        model: GeminiClient.Model = .gemini25Flash,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        return try await client.summarizeYouTubeVideo(
            model: model,
            videoURL: videoURL,
            maxLength: maxLength,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    /// Transcribe YouTube video audio
    public func transcribeYouTubeVideo(
        videoURL: String,
        language: String = "en",
        model: GeminiClient.Model = .gemini25Flash,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        return try await client.transcribeYouTubeVideo(
            model: model,
            videoURL: videoURL,
            language: language,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    /// Generate quiz from YouTube video
    public func generateYouTubeVideoQuiz(
        videoURL: String,
        questionCount: Int = 5,
        model: GeminiClient.Model = .gemini25Flash,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        return try await client.generateYouTubeVideoQuiz(
            model: model,
            videoURL: videoURL,
            questionCount: questionCount,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    /// Extract key moments from YouTube video
    public func extractYouTubeVideoKeyMoments(
        videoURL: String,
        momentCount: Int = 5,
        model: GeminiClient.Model = .gemini25Flash,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        return try await client.extractYouTubeVideoKeyMoments(
            model: model,
            videoURL: videoURL,
            momentCount: momentCount,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
}