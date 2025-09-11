//
//  GeminiClient+SessionManagement.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation

public extension GeminiClient {
    
    // MARK: - Session Management
    
    /// Represents a session with a pinned API key
    public struct APISession {
        public let id: String
        public let apiKey: String
        public let createdAt: Date
        
        public init(id: String, apiKey: String) {
            self.id = id
            self.apiKey = apiKey
            self.createdAt = Date()
        }
    }
    
    /// Create a new session with a pinned API key
    /// - Returns: A new session with the next available API key
    public func createSession() -> APISession {
        let apiKey = getNextApiKey()
        return APISession(id: UUID().uuidString, apiKey: apiKey)
    }
    
    /// Create a new session with a specific API key
    /// - Parameter apiKeyIndex: Index of the API key to use
    /// - Returns: A new session with the specified API key
    public func createSession(with apiKeyIndex: Int) -> APISession? {
        guard let apiKey = getApiKey(at: apiKeyIndex) else { return nil }
        return APISession(id: UUID().uuidString, apiKey: apiKey)
    }
    
    /// Generate content using a session (same API key for all requests)
    public func generateContent(
        model: Model,
        text: String,
        session: APISession,
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
        
        return try await performRequest(model: model, request: request, apiKey: session.apiKey)
    }
    
    /// Generate content with files using a session
    public func generateContent(
        model: Model,
        files: [GeminiDocumentUploader.UploadResponse.FileInfo],
        text: String,
        session: APISession,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        var parts: [Part] = []
        
        // Add file parts
        for file in files {
            if let mimeType = file.mimeType {
                parts.append(Part(fileData: FileData(mimeType: mimeType, fileUri: file.uri)))
            }
        }
        
        // Add text part
        parts.append(Part(text: text))
        
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: parts)],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        return try await performRequest(model: model, request: request, apiKey: session.apiKey)
    }
    
    /// Generate content with images using a session
    public func generateContentWithImage(
        model: Model,
        text: String,
        imageData: Data,
        mimeType: String = "image/jpeg",
        session: APISession,
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
        
        return try await performRequest(model: model, request: request, apiKey: session.apiKey)
    }
    
    /// Multi-turn conversation with session
    public func sendMessage(
        model: Model,
        message: String,
        session: APISession,
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
        
        return try await performRequest(model: model, request: request, apiKey: session.apiKey)
    }
    
    // MARK: - Private Methods
    
    private func performRequest(
        model: Model,
        request: GeminiGenerateContentRequest,
        apiKey: String
    ) async throws -> GeminiGenerateContentResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("models/\(model.rawValue):generateContent"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
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