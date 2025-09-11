//
//  GeminiClient+Video.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import SwiftyBeaver

extension GeminiClient {
    
    // MARK: - Video Support
    
    /// Generate content with video file
    public func generateContentWithVideo(
        model: Model,
        videoFileURI: String,
        mimeType: String,
        prompt: String = "Analyze this video",
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let videoPart = Part(fileData: FileData(mimeType: mimeType, fileUri: videoFileURI))
        let textPart = Part(text: prompt)
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [textPart, videoPart])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        return try await performRequest(model: model, request: request)
    }
    
    /// Analyze video content with custom prompt
    public func analyzeVideo(
        model: Model,
        videoFileURI: String,
        mimeType: String,
        prompt: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        let response = try await generateContentWithVideo(
            model: model,
            videoFileURI: videoFileURI,
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
    
    /// Transcribe video audio to text
    public func transcribeVideo(
        model: Model,
        videoFileURI: String,
        mimeType: String,
        language: String? = nil,
        systemInstruction: String? = nil
    ) async throws -> String {
        let prompt = language != nil ?
            "Transcribe the audio from this video to text. Language: \(language!)" :
            "Transcribe the audio from this video to text."
        
        let response = try await generateContentWithVideo(
            model: model,
            videoFileURI: videoFileURI,
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
    
    /// Summarize video content
    public func summarizeVideo(
        model: Model,
        videoFileURI: String,
        mimeType: String,
        maxLength: Int = 200,
        systemInstruction: String? = nil
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
        
        return try await analyzeVideo(
            model: model,
            videoFileURI: videoFileURI,
            mimeType: mimeType,
            prompt: prompt,
            systemInstruction: systemInstruction
        )
    }
    
    /// Extract key moments from video
    public func extractKeyMoments(
        model: Model,
        videoFileURI: String,
        mimeType: String,
        systemInstruction: String? = nil
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
        
        return try await analyzeVideo(
            model: model,
            videoFileURI: videoFileURI,
            mimeType: mimeType,
            prompt: prompt,
            systemInstruction: systemInstruction
        )
    }
    
    /// Generate video quiz with answer key
    public func generateVideoQuiz(
        model: Model,
        videoFileURI: String,
        mimeType: String,
        questionCount: Int = 5,
        systemInstruction: String? = nil
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
        
        return try await analyzeVideo(
            model: model,
            videoFileURI: videoFileURI,
            mimeType: mimeType,
            prompt: prompt,
            systemInstruction: systemInstruction
        )
    }
    
    /// Analyze video content for educational purposes
    public func analyzeEducationalVideo(
        model: Model,
        videoFileURI: String,
        mimeType: String,
        systemInstruction: String? = nil
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
        
        return try await analyzeVideo(
            model: model,
            videoFileURI: videoFileURI,
            mimeType: mimeType,
            prompt: prompt,
            systemInstruction: systemInstruction
        )
    }
    
    /// Detect objects and scenes in video
    public func detectVideoObjects(
        model: Model,
        videoFileURI: String,
        mimeType: String,
        systemInstruction: String? = nil
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
        
        return try await analyzeVideo(
            model: model,
            videoFileURI: videoFileURI,
            mimeType: mimeType,
            prompt: prompt,
            systemInstruction: systemInstruction
        )
    }
    
    /// Convenience method to upload and process video in one call
    public func processVideo(
        model: Model,
        videoFileURL: URL,
        prompt: String = "Analyze this video",
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        displayName: String? = nil
    ) async throws -> String {
        let uploader = GeminiVideoUploader(
            baseURL: baseURL.absoluteString,
            logger: SwiftyBeaver.self
        )
        
        let session = uploader.startSession(apiKey: getNextApiKey())
        defer { uploader.endSession(session) }
        
        // Upload video
        let fileInfo = try await uploader.uploadVideo(
            at: videoFileURL,
            displayName: displayName,
            session: session
        )
        
        // Process video
        return try await analyzeVideo(
            model: model,
            videoFileURI: fileInfo.uri!,
            mimeType: fileInfo.mimeType ?? "video/mp4",
            prompt: prompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    // MARK: - YouTube Video Support
    
    /// Generate content with YouTube video
    public func generateContentWithYouTubeVideo(
        model: Model,
        videoURL: String,
        prompt: String = "Analyze this YouTube video",
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let youtubePart = Part(fileDataYouTube: YouTubeVideoData(fileUri: videoURL))
        let textPart = Part(text: prompt)
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [textPart, youtubePart])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        return try await performRequest(model: model, request: request)
    }
    
    /// Analyze YouTube video content
    public func analyzeYouTubeVideo(
        model: Model,
        videoURL: String,
        prompt: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        let response = try await generateContentWithYouTubeVideo(
            model: model,
            videoURL: videoURL,
            prompt: prompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        guard let candidate = response.candidates.first,
              let textPart = candidate.content.parts.first,
              let text = textPart.text else {
            throw GeminiError.invalidResponse
        }
        
        return text
    }
    
    /// Summarize YouTube video
    public func summarizeYouTubeVideo(
        model: Model,
        videoURL: String,
        maxLength: Int = 100,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        let summaryPrompt = """
        Please summarize this YouTube video in \(maxLength) words or less.
        
        Include:
        - Main topics or themes presented
        - Key points or information conveyed
        - Visual elements and their significance
        - Overall message or purpose
        - Important actions or events shown
        """
        
        return try await analyzeYouTubeVideo(
            model: model,
            videoURL: videoURL,
            prompt: summaryPrompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    /// Transcribe YouTube video audio
    public func transcribeYouTubeVideo(
        model: Model,
        videoURL: String,
        language: String = "en",
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        let transcriptionPrompt = "Transcribe the audio from this YouTube video to text. Language: \(language)"
        
        return try await analyzeYouTubeVideo(
            model: model,
            videoURL: videoURL,
            prompt: transcriptionPrompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    /// Generate quiz from YouTube video content
    public func generateYouTubeVideoQuiz(
        model: Model,
        videoURL: String,
        questionCount: Int = 5,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        let quizPrompt = """
        Based on this YouTube video, create a quiz with \(questionCount) multiple choice questions.
        
        For each question, provide:
        1. The question
        2. 4 possible answers (A, B, C, D)
        3. The correct answer
        4. A brief explanation
        
        Format the quiz clearly with numbered questions.
        """
        
        return try await analyzeYouTubeVideo(
            model: model,
            videoURL: videoURL,
            prompt: quizPrompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    /// Extract key moments from YouTube video
    public func extractYouTubeVideoKeyMoments(
        model: Model,
        videoURL: String,
        momentCount: Int = 5,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> String {
        let momentsPrompt = """
        Identify \(momentCount) key moments or highlights from this YouTube video.
        
        For each moment, describe:
        1. What happens in the moment
        2. Why it's significant
        3. Approximate timestamp if possible
        
        Format as a numbered list of key moments.
        """
        
        return try await analyzeYouTubeVideo(
            model: model,
            videoURL: videoURL,
            prompt: momentsPrompt,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
}