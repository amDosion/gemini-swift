import Foundation

public extension GeminiClient {
    
    // MARK: - Convenience Methods
    
    func generateText(
        model: Model = .gemini25Flash,
        prompt: String,
        systemInstruction: String? = nil,
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil
    ) async throws -> String {
        let config = GenerationConfig(
            maxOutputTokens: maxOutputTokens,
            temperature: temperature
        )
        
        let response = try await generateContent(
            model: model,
            text: prompt,
            systemInstruction: systemInstruction,
            generationConfig: config
        )
        
        guard let candidate = response.candidates.first,
              let textPart = candidate.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }
        
        return textPart
    }
    
    func chat(
        model: Model = .gemini25Flash,
        message: String,
        conversationHistory: inout [Content],
        systemInstruction: String? = nil,
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil
    ) async throws -> String {
        let config = GenerationConfig(
            maxOutputTokens: maxOutputTokens,
            temperature: temperature
        )
        
        let response = try await sendMessage(
            model: model,
            message: message,
            history: conversationHistory,
            systemInstruction: systemInstruction,
            generationConfig: config
        )
        
        guard let candidate = response.candidates.first,
              let responseText = candidate.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }
        
        // Add user message and assistant response to history
        conversationHistory.append(Content(role: .user, parts: [Part(text: message)]))
        conversationHistory.append(candidate.content)
        
        return responseText
    }
    
    func chatWithYouTubeVideo(
        model: Model = .gemini25Flash,
        message: String,
        youtubeURL: String,
        conversationHistory: inout [Content],
        systemInstruction: String? = nil,
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil
    ) async throws -> String {
        let config = GenerationConfig(
            maxOutputTokens: maxOutputTokens,
            temperature: temperature
        )
        
        // 创建包含YouTube视频的请求
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [
                Part(text: message),
                Part(fileDataYouTube: YouTubeVideoData(fileUri: youtubeURL))
            ])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: config,
            safetySettings: nil
        )
        
        let response = try await generateContent(model: model, request: request)
        
        guard let candidate = response.candidates.first,
              let responseText = candidate.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }
        
        // Add user message (with YouTube video) and assistant response to history
        conversationHistory.append(Content(role: .user, parts: [
            Part(text: message),
            Part(fileDataYouTube: YouTubeVideoData(fileUri: youtubeURL))
        ]))
        conversationHistory.append(candidate.content)
        
        return responseText
    }
    
    func analyzeImage(
        model: Model = .gemini25Flash,
        prompt: String,
        imageData: Data,
        mimeType: String = "image/jpeg",
        systemInstruction: String? = nil
    ) async throws -> String {
        let response = try await generateContentWithImage(
            model: model,
            text: prompt,
            imageData: imageData,
            mimeType: mimeType,
            systemInstruction: systemInstruction
        )
        
        guard let candidate = response.candidates.first,
              let textPart = candidate.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }
        
        return textPart
    }
    
    // MARK: - Embedding Convenience
    
    func embedText(
        text: String,
        taskType: EmbeddingTaskType? = nil,
        title: String? = nil
    ) async throws -> [Float] {
        let response = try await generateEmbedding(
            text: text,
            taskType: taskType,
            title: title
        )
        return response.embedding
    }
}

// MARK: - Content Convenience

public extension Content {
    static func userMessage(_ text: String) -> Content {
        Content(role: .user, parts: [Part(text: text)])
    }
    
    static func modelMessage(_ text: String) -> Content {
        Content(role: .model, parts: [Part(text: text)])
    }
    
    static func multimodalMessage(text: String, imageData: Data, mimeType: String = "image/jpeg") -> Content {
        let textPart = Part(text: text)
        let imagePart = Part(inlineData: InlineData(mimeType: mimeType, data: imageData.base64EncodedString()))
        return Content(role: .user, parts: [textPart, imagePart])
    }
}

// MARK: - Structured Output Extensions

public extension GeminiClient {
    
    /// Generate structured output using a custom JSON schema
    /// - Parameters:
    ///   - model: Gemini model to use
    ///   - prompt: The text prompt
    ///   - systemInstruction: Optional system instruction
    ///   - schema: JSON schema as a dictionary
    ///   - mimeType: Response MIME type (default: application/json)
    ///   - temperature: Response randomness (0.0-1.0)
    /// - Returns: Decoded response of specified type
    func generateStructured<T: Codable>(
        model: Model = .gemini25Flash,
        prompt: String,
        systemInstruction: String? = nil,
        schema: [String: Any],
        mimeType: String = "application/json",
        temperature: Double? = nil
    ) async throws -> T {
        return try await generateStructuredOutput(
            model: model,
            prompt: prompt,
            systemInstruction: systemInstruction,
            responseSchema: schema,
            responseMimeType: mimeType,
            temperature: temperature
        )
    }
    
    /// Generate structured output automatically from Codable type
    /// - Parameters:
    ///   - model: Gemini model to use
    ///   - prompt: The text prompt
    ///   - systemInstruction: Optional system instruction
    ///   - type: The Codable type to decode to
    ///   - mimeType: Response MIME type (default: application/json)
    ///   - temperature: Response randomness (0.0-1.0)
    /// - Returns: Decoded response of specified type
    func generateStructured<T: Codable>(
        model: Model = .gemini25Flash,
        prompt: String,
        systemInstruction: String? = nil,
        as type: T.Type,
        mimeType: String = "application/json",
        temperature: Double? = nil
    ) async throws -> T {
        return try await generateStructuredOutput(
            model: model,
            prompt: prompt,
            systemInstruction: systemInstruction,
            responseType: type,
            responseMimeType: mimeType,
            temperature: temperature
        )
    }
}

// MARK: - Model Info

public extension GeminiClient.Model {
    var description: String {
        switch self {
        case .gemini25Pro:
            return "Most capable model for complex reasoning and multimodal tasks"
        case .gemini25Flash:
            return "Fast and capable model for high-volume tasks"
        case .gemini25FlashLite:
            return "Lightweight version of Gemini 2.5 Flash for efficiency"
        case .geminiLive25FlashPreview:
            return "Preview model optimized for live conversational AI"
        case .gemini25FlashPreviewNativeAudioDialog:
            return "Preview model with native audio dialog capabilities"
        case .gemini25FlashExpNativeAudioThinkingDialog:
            return "Experimental model with native audio and thinking capabilities"
        case .gemini25FlashImagePreview:
            return "Preview model with enhanced image understanding"
        case .geminiEmbedding001:
            return "Specialized model for generating text embeddings"
        }
    }
    
    var maxInputTokens: Int {
        switch self {
        case .gemini25Pro, .gemini25Flash, .gemini25FlashLite, .geminiLive25FlashPreview,
             .gemini25FlashPreviewNativeAudioDialog, .gemini25FlashExpNativeAudioThinkingDialog,
             .gemini25FlashImagePreview:
            return 1_048_576 // 1M tokens for most 2.5 models
        case .geminiEmbedding001:
            return 2_048 // Smaller context for embeddings
        }
    }
    
    var supportsMultimodal: Bool {
        switch self {
        case .gemini25Pro, .gemini25Flash, .gemini25FlashLite, .geminiLive25FlashPreview,
             .gemini25FlashPreviewNativeAudioDialog, .gemini25FlashExpNativeAudioThinkingDialog,
             .gemini25FlashImagePreview:
            return true
        case .geminiEmbedding001:
            return false // Embedding model is text-only
        }
    }
    
    var supportsAudio: Bool {
        switch self {
        case .gemini25FlashPreviewNativeAudioDialog, .gemini25FlashExpNativeAudioThinkingDialog:
            return true
        default:
            return false
        }
    }
}