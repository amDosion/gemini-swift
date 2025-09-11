import Foundation
import SwiftyBeaver

public class GeminiClient {
    private var apiKeys: [String]
    private var currentKeyIndex: Int
    internal let baseURL: URL
    internal let session: URLSession
    internal let logger: SwiftyBeaver.Type
    internal let keyQueue = DispatchQueue(label: "com.gemini.swift.keyQueue", attributes: .concurrent)
    
    public enum Model: String, CaseIterable, Sendable {
        case gemini25Pro = "gemini-2.5-pro"
        case gemini25Flash = "gemini-2.5-flash"
        case gemini25FlashLite = "gemini-2.5-flash-lite"
        case geminiLive25FlashPreview = "gemini-live-2.5-flash-preview"
        case gemini25FlashPreviewNativeAudioDialog = "gemini-2.5-flash-preview-native-audio-dialog"
        case gemini25FlashExpNativeAudioThinkingDialog = "gemini-2.5-flash-exp-native-audio-thinking-dialog"
        case gemini25FlashImagePreview = "gemini-2.5-flash-image-preview"
        case geminiEmbedding001 = "gemini-embedding-001"
        
        public var displayName: String {
            switch self {
            case .gemini25Pro: return "Gemini 2.5 Pro"
            case .gemini25Flash: return "Gemini 2.5 Flash"
            case .gemini25FlashLite: return "Gemini 2.5 Flash Lite"
            case .geminiLive25FlashPreview: return "Gemini Live 2.5 Flash Preview"
            case .gemini25FlashPreviewNativeAudioDialog: return "Gemini 2.5 Flash Preview (Native Audio Dialog)"
            case .gemini25FlashExpNativeAudioThinkingDialog: return "Gemini 2.5 Flash Experimental (Native Audio Thinking)"
            case .gemini25FlashImagePreview: return "Gemini 2.5 Flash Image Preview"
            case .geminiEmbedding001: return "Gemini Embedding 001"
            }
        }
    }
    
    public enum GeminiError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case requestFailed(Error)
        case decodingError(Error)
        case apiError(String, Int?)
        case invalidModel(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .invalidResponse: return "Invalid response from server"
            case .requestFailed(let error): return "Request failed: \(error.localizedDescription)"
            case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
            case .apiError(let message, let code): 
                return "API Error: \(message)" + (code != nil ? " (Code: \(code!))" : "")
            case .invalidModel(let message): return message
            }
        }
    }
    
    public init(apiKeys: [String], baseURL: URL? = nil, logger: SwiftyBeaver.Type = SwiftyBeaver.self) {
        guard !apiKeys.isEmpty else {
            fatalError("API keys array cannot be empty")
        }
        
        // Ensure logging is always initialized
        GeminiLogger.shared.setup()
        
        self.apiKeys = apiKeys
        self.currentKeyIndex = 0
        self.baseURL = baseURL ?? URL(string: "https://generativelanguage.googleapis.com/v1beta/")!
        self.session = URLSession.shared
        self.logger = logger
    }
    
    // Convenience initializer for single API key
    public convenience init(apiKey: String, baseURL: URL? = nil, logger: SwiftyBeaver.Type = SwiftyBeaver.self) {
        self.init(apiKeys: [apiKey], baseURL: baseURL, logger: logger)
    }
    
    // MARK: - Private Key Management
    
    internal func getNextApiKey() -> String {
        return keyQueue.sync(flags: .barrier) {
            let key = apiKeys[currentKeyIndex]
            currentKeyIndex = (currentKeyIndex + 1) % apiKeys.count
            return key
        }
    }
    
    internal func getApiKey(at index: Int) -> String? {
        return keyQueue.sync {
            guard index < apiKeys.count else { return nil }
            return apiKeys[index]
        }
    }
    
    // MARK: - API Key Management
    
    /// Get the current API key count (public version)
    public var apiKeyCount: Int {
        return keyQueue.sync { apiKeys.count }
    }
    
    /// Get the current API key index (for debugging)
    public var currentApiKeyIndex: Int {
        return keyQueue.sync { currentKeyIndex }
    }
    
    /// Add new API keys to the rotation
    public func addApiKeys(_ keys: [String]) {
        keyQueue.sync(flags: .barrier) {
            self.apiKeys.append(contentsOf: keys)
        }
    }
    
    /// Remove an API key by index
    public func removeApiKey(at index: Int) {
        keyQueue.sync(flags: .barrier) {
            guard apiKeys.count > 1 else {
                fatalError("Cannot remove the last API key")
            }
            guard index < apiKeys.count else {
                fatalError("Index out of range")
            }
            apiKeys.remove(at: index)
            if currentKeyIndex >= apiKeys.count {
                currentKeyIndex = 0
            }
        }
    }
    
    /// Reset key rotation to start from the beginning
    public func resetKeyRotation() {
        keyQueue.sync(flags: .barrier) {
            currentKeyIndex = 0
        }
    }
    
    // MARK: - Generate Content
    
    public func generateContent(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [Part(text: text)])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        return try await performRequest(model: model, request: request)
    }
    
    // MARK: - Google Search
    
    public func generateContentWithGoogleSearch(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [Part(text: text)])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings,
            tools: [Tool.googleSearch()]
        )
        
        return try await performRequest(model: model, request: request)
    }
    
    // MARK: - URL Context
    
    public func generateContentWithUrlContext(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        onUrlDetected: (([URL]) -> Bool)? = nil
    ) async throws -> GeminiGenerateContentResponse {
        // Extract URLs from the text
        let detectedUrls = extractUrls(from: text)
        
        // If URLs are detected and callback is provided, ask for confirmation
        if !detectedUrls.isEmpty, let onUrlDetected = onUrlDetected {
            let shouldProceed = onUrlDetected(detectedUrls)
            guard shouldProceed else {
                throw GeminiError.invalidModel("URL context access denied by user")
            }
        }
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [Part(text: text)])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings,
            tools: [Tool.urlContext()]
        )
        
        return try await performRequest(model: model, request: request)
    }
    
    // MARK: - Combined Tools
    
    public func generateContentWithSearchAndUrlContext(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        onUrlDetected: (([URL]) -> Bool)? = nil
    ) async throws -> GeminiGenerateContentResponse {
        // Extract URLs from the text
        let detectedUrls = extractUrls(from: text)
        
        // If URLs are detected and callback is provided, ask for confirmation
        if !detectedUrls.isEmpty, let onUrlDetected = onUrlDetected {
            let shouldProceed = onUrlDetected(detectedUrls)
            guard shouldProceed else {
                throw GeminiError.invalidModel("URL context access denied by user")
            }
        }
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [Part(text: text)])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings,
            tools: [Tool.urlContext(), Tool.googleSearch()]
        )
        
        return try await performRequest(model: model, request: request)
    }
    
    // MARK: - Private Methods
    
    private func extractUrls(from text: String) -> [URL] {
        var urls: [URL] = []
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        
        if let matches = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let url = match.url {
                    urls.append(url)
                }
            }
        }
        
        return urls
    }
    
    // MARK: - Structured Output
    
    public func generateStructuredOutput<T: Codable>(
        model: Model,
        prompt: String,
        systemInstruction: String? = nil,
        structuredConfig: StructuredOutputConfig,
        temperature: Double? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> T {
        let generationConfig = GenerationConfig(
            temperature: temperature,
            responseMimeType: structuredConfig.responseMimeType,
            responseSchema: structuredConfig.responseSchema
        )
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [Part(text: prompt)])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        let response = try await performRequest(model: model, request: request)
        
        guard let candidate = response.candidates.first,
              let textPart = candidate.content.parts.first,
              let responseText = textPart.text,
              let responseData = responseText.data(using: .utf8) else {
            throw GeminiError.invalidResponse
        }
        
        do {
            let decodedObject = try JSONDecoder().decode(T.self, from: responseData)
            return decodedObject
        } catch {
            logger.error("Failed to decode structured response: \(error.localizedDescription)")
            throw GeminiError.decodingError(error)
        }
    }
    
    public func generateStructuredOutput<T: Codable>(
        model: Model,
        prompt: String,
        systemInstruction: String? = nil,
        responseSchema: [String: Any],
        responseMimeType: String = "application/json",
        temperature: Double? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> T {
        let config = StructuredOutputConfig(
            responseMimeType: responseMimeType,
            responseSchema: responseSchema
        )
        
        return try await generateStructuredOutput(
            model: model,
            prompt: prompt,
            systemInstruction: systemInstruction,
            structuredConfig: config,
            temperature: temperature,
            safetySettings: safetySettings
        )
    }
    
    public func generateStructuredOutput<T: Codable>(
        model: Model,
        prompt: String,
        systemInstruction: String? = nil,
        responseType: T.Type,
        responseMimeType: String = "application/json",
        temperature: Double? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> T {
        let config = try StructuredOutputConfig(
            responseMimeType: responseMimeType,
            for: responseType
        )
        
        return try await generateStructuredOutput(
            model: model,
            prompt: prompt,
            systemInstruction: systemInstruction,
            structuredConfig: config,
            temperature: temperature,
            safetySettings: safetySettings
        )
    }
    
    // MARK: - Embeddings
    
    public func generateEmbedding(
        text: String,
        taskType: EmbeddingTaskType? = nil,
        title: String? = nil
    ) async throws -> GeminiEmbeddingResponse {
        let embeddingModel = Model.geminiEmbedding001
        let currentApiKey = getNextApiKey()
        
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("models/\(embeddingModel.rawValue):embedContent"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: currentApiKey)]
        
        let request = GeminiEmbeddingRequest(
            model: embeddingModel.rawValue,
            content: Content(parts: [Part(text: text)]),
            taskType: taskType,
            title: title
        )
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        logger.info("Making embedding request to: \(urlComponents.url?.absoluteString ?? "invalid")")
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw GeminiError.apiError("Embedding request failed", httpResponse.statusCode)
            }
            
            return try JSONDecoder().decode(GeminiEmbeddingResponse.self, from: data)
        } catch {
            logger.error("Embedding request failed: \(error.localizedDescription)")
            throw GeminiError.requestFailed(error)
        }
    }
    
    public func generateContent(
        model: Model,
        request: GeminiGenerateContentRequest
    ) async throws -> GeminiGenerateContentResponse {
        return try await performRequest(model: model, request: request)
    }
    
    // MARK: - Multi-turn Conversation
    
    public func sendMessage(
        model: Model,
        message: String,
        history: [Content] = [],
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        var contents = history
        contents.append(Content(role: .user, parts: [Part(text: message)]))
        
        let request = GeminiGenerateContentRequest(
            contents: contents,
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        return try await performRequest(model: model, request: request)
    }
    
    // MARK: - Multimodal Support
    
    public func generateContentWithImage(
        model: Model,
        text: String,
        imageData: Data,
        mimeType: String = "image/jpeg",
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let base64Image = imageData.base64EncodedString()
        let imagePart = Part(inlineData: InlineData(mimeType: mimeType, data: base64Image))
        let textPart = Part(text: text)
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [textPart, imagePart])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        return try await performRequest(model: model, request: request)
    }
    
    // MARK: - Internal Methods
    
    internal func performRequest(
        model: Model,
        request: GeminiGenerateContentRequest
    ) async throws -> GeminiGenerateContentResponse {
        let currentApiKey = getNextApiKey()
        var components = URLComponents(url: baseURL.appendingPathComponent("models/\(model.rawValue):generateContent"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: currentApiKey)]
        let url = components.url!
        
        logger.info("Making request to: \(url.absoluteString)")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Custom encoding to handle responseSchema properly
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        
        // If responseSchema is present, decode and re-encode to ensure it's a proper JSON object
        if let requestDict = try JSONSerialization.jsonObject(with: requestData) as? [String: Any],
           let generationConfig = requestDict["generationConfig"] as? [String: Any],
           let responseSchema = generationConfig["responseSchema"] as? String,
           let schemaData = responseSchema.data(using: .utf8),
           let schemaObject = try? JSONSerialization.jsonObject(with: schemaData) {
            
            var updatedRequest = requestDict
            var updatedConfig = generationConfig
            updatedConfig["responseSchema"] = schemaObject
            updatedRequest["generationConfig"] = updatedConfig
            
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: updatedRequest)
        } else {
            urlRequest.httpBody = requestData
        }
        
        // Log request body
        if let requestBody = String(data: urlRequest.httpBody!, encoding: .utf8) {
            logger.debug("Request body: \(requestBody)")
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }
            
            logger.debug("Response status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMessage = errorResponse["error"] {
                    throw GeminiError.apiError(errorMessage, httpResponse.statusCode)
                }
                throw GeminiError.apiError("Unknown error", httpResponse.statusCode)
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            return geminiResponse
            
        } catch let error as GeminiError {
            throw error
        } catch {
            logger.error("Request failed: \(error.localizedDescription)")
            throw GeminiError.requestFailed(error)
        }
    }
}