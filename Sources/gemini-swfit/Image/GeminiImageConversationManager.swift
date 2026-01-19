//
//  GeminiImageConversationManager.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-19.
//

import Foundation
import SwiftyBeaver

/// Manages multi-turn image editing conversations
///
/// This manager allows users to have a conversation-style interaction
/// with image editing, where context is preserved across multiple turns.
public class GeminiImageConversationManager {

    // MARK: - Types

    /// A single message in the conversation
    public struct ConversationMessage: Sendable {
        public let role: Role
        public let text: String?
        public let imageData: Data?
        public let imageMimeType: String?
        public let timestamp: Date

        public enum Role: String, Sendable {
            case user
            case model
        }

        public init(
            role: Role,
            text: String? = nil,
            imageData: Data? = nil,
            imageMimeType: String? = nil
        ) {
            self.role = role
            self.text = text
            self.imageData = imageData
            self.imageMimeType = imageMimeType
            self.timestamp = Date()
        }
    }

    /// Conversation session state
    public struct ConversationSession: Sendable {
        public let sessionId: String
        public let apiKey: String
        public var messages: [ConversationMessage]
        public var currentImage: Data?
        public var currentImageMimeType: String?
        public let createdAt: Date

        public init(
            sessionId: String = UUID().uuidString,
            apiKey: String,
            initialImage: Data? = nil,
            initialImageMimeType: String? = nil
        ) {
            self.sessionId = sessionId
            self.apiKey = apiKey
            self.messages = []
            self.currentImage = initialImage
            self.currentImageMimeType = initialImageMimeType
            self.createdAt = Date()
        }
    }

    /// Response from a conversation turn
    public struct ConversationResponse: Sendable {
        public let text: String?
        public let image: GeneratedImage?
        public let messageIndex: Int

        public init(text: String?, image: GeneratedImage?, messageIndex: Int) {
            self.text = text
            self.image = image
            self.messageIndex = messageIndex
        }
    }

    // MARK: - Properties

    private let client: GeminiClient
    private let editor: GeminiImageEditor
    private let generator: GeminiImageGenerator
    private let logger: SwiftyBeaver.Type

    private var activeSessions: [String: ConversationSession] = [:]
    private let sessionQueue = DispatchQueue(label: "com.gemini.imageConversation.sessions", attributes: .concurrent)

    /// Maximum image size in bytes (20MB default)
    public var maxImageSize: Int = 20 * 1024 * 1024

    /// Maximum messages to keep in context
    public var maxContextMessages: Int = 10

    // MARK: - Initialization

    public init(
        client: GeminiClient,
        editor: GeminiImageEditor? = nil,
        generator: GeminiImageGenerator? = nil,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.client = client
        self.logger = logger

        let baseURL = client.baseURL.absoluteString

        self.editor = editor ?? GeminiImageEditor(
            baseURL: baseURL,
            logger: logger
        )

        self.generator = generator ?? GeminiImageGenerator(
            baseURL: baseURL,
            logger: logger
        )
    }

    // MARK: - Session Management

    /// Start a new conversation session
    public func startSession(
        withImage imageData: Data? = nil,
        imageMimeType: String? = nil
    ) -> ConversationSession {
        let apiKey = client.getNextApiKey()

        // Validate image size
        if let imageData = imageData, imageData.count > maxImageSize {
            logger.warning("Image size exceeds limit, may cause performance issues")
        }

        let session = ConversationSession(
            apiKey: apiKey,
            initialImage: imageData,
            initialImageMimeType: imageMimeType
        )

        sessionQueue.sync(flags: .barrier) {
            activeSessions[session.sessionId] = session
        }

        logger.info("Started image conversation session: \(session.sessionId)")
        return session
    }

    /// Get a session by ID
    public func getSession(_ sessionId: String) -> ConversationSession? {
        return sessionQueue.sync {
            activeSessions[sessionId]
        }
    }

    /// End a conversation session
    public func endSession(_ sessionId: String) {
        sessionQueue.sync(flags: .barrier) {
            activeSessions.removeValue(forKey: sessionId)
        }
        logger.info("Ended image conversation session: \(sessionId)")
    }

    /// Atomically update a session (prevents race conditions)
    private func updateSession(
        _ sessionId: String,
        update: @escaping (inout ConversationSession) -> Void
    ) -> Bool {
        return sessionQueue.sync(flags: .barrier) {
            guard var session = activeSessions[sessionId] else {
                return false
            }
            update(&session)
            activeSessions[sessionId] = session
            return true
        }
    }

    // MARK: - Conversation Methods

    /// Send a message in the conversation
    public func sendMessage(
        _ message: String,
        sessionId: String,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> ConversationResponse {
        // Atomically read session state and add user message
        let sessionData: (apiKey: String, currentImage: Data?, mimeType: String?, messages: [ConversationMessage], messageCount: Int)?
        sessionData = sessionQueue.sync(flags: .barrier) { () -> (String, Data?, String?, [ConversationMessage], Int)? in
            guard var session = activeSessions[sessionId] else {
                return nil
            }

            // Add user message atomically
            let userMessage = ConversationMessage(
                role: .user,
                text: message
            )
            session.messages.append(userMessage)
            activeSessions[sessionId] = session

            return (session.apiKey, session.currentImage, session.currentImageMimeType, session.messages, session.messages.count)
        }

        guard let data = sessionData else {
            throw GeminiImageError.invalidConfiguration("Session not found")
        }

        // Build conversation context and make API call (outside lock)
        let response: ConversationResponse

        if let currentImage = data.currentImage,
           let mimeType = data.mimeType {
            // Edit existing image with conversation context
            response = try await editWithContext(
                message: message,
                imageData: currentImage,
                imageMimeType: mimeType,
                history: data.messages,
                model: model,
                apiKey: data.apiKey
            )
        } else if isGenerationRequest(message) {
            // Generate new image
            response = try await generateWithContext(
                message: message,
                history: data.messages,
                model: model,
                apiKey: data.apiKey
            )
        } else {
            // Text-only response about image operations
            response = ConversationResponse(
                text: "Please provide an image or ask me to generate one.",
                image: nil,
                messageIndex: data.messageCount
            )
        }

        // Atomically update session with response
        let maxMessages = maxContextMessages
        let updated = updateSession(sessionId) { session in
            // Add model response to history
            let modelMessage = ConversationMessage(
                role: .model,
                text: response.text,
                imageData: response.image?.data,
                imageMimeType: response.image?.mimeType
            )
            session.messages.append(modelMessage)

            // Update current image if new one was generated/edited
            if let newImage = response.image {
                session.currentImage = newImage.data
                session.currentImageMimeType = newImage.mimeType
            }

            // Trim history if too long
            if session.messages.count > maxMessages * 2 {
                session.messages = Array(session.messages.suffix(maxMessages * 2))
            }
        }

        if !updated {
            logger.warning("Session \(sessionId) was ended during message processing")
        }

        return response
    }

    /// Add an image to the current session
    public func addImage(
        _ imageData: Data,
        mimeType: String = "image/jpeg",
        sessionId: String
    ) throws {
        // Validate image size before locking
        guard imageData.count <= maxImageSize else {
            throw GeminiImageError.invalidImageData
        }

        let updated = updateSession(sessionId) { session in
            session.currentImage = imageData
            session.currentImageMimeType = mimeType
        }

        guard updated else {
            throw GeminiImageError.invalidConfiguration("Session not found")
        }

        logger.info("Added image to session: \(sessionId)")
    }

    /// Clear the current image from session
    public func clearImage(sessionId: String) throws {
        let updated = updateSession(sessionId) { session in
            session.currentImage = nil
            session.currentImageMimeType = nil
        }

        guard updated else {
            throw GeminiImageError.invalidConfiguration("Session not found")
        }
    }

    /// Get the current image from session
    public func getCurrentImage(sessionId: String) -> (data: Data, mimeType: String)? {
        guard let session = getSession(sessionId),
              let data = session.currentImage,
              let mimeType = session.currentImageMimeType else {
            return nil
        }
        return (data, mimeType)
    }

    /// Get conversation history
    public func getHistory(sessionId: String) -> [ConversationMessage] {
        return getSession(sessionId)?.messages ?? []
    }

    // MARK: - Private Methods

    private func isGenerationRequest(_ message: String) -> Bool {
        let generationKeywords = [
            "generate", "create", "make", "draw", "produce",
            "design", "生成", "创建", "制作", "画"
        ]
        let lowercased = message.lowercased()
        return generationKeywords.contains { lowercased.contains($0) }
    }

    private func editWithContext(
        message: String,
        imageData: Data,
        imageMimeType: String,
        history: [ConversationMessage],
        model: ImageGenerationModel,
        apiKey: String
    ) async throws -> ConversationResponse {
        // Build context-aware prompt
        let contextPrompt = buildContextPrompt(message: message, history: history)

        let response = try await editor.editWithGemini(
            prompt: contextPrompt,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model,
            apiKey: apiKey
        )

        let image = response.firstImage
        return ConversationResponse(
            text: "I've made the requested changes to your image.",
            image: image,
            messageIndex: history.count
        )
    }

    private func generateWithContext(
        message: String,
        history: [ConversationMessage],
        model: ImageGenerationModel,
        apiKey: String
    ) async throws -> ConversationResponse {
        // Build context-aware prompt
        let contextPrompt = buildContextPrompt(message: message, history: history)

        let response = try await generator.generateWithGemini(
            prompt: contextPrompt,
            model: model,
            config: .default,
            apiKey: apiKey
        )

        let image = response.firstImage
        let text = response.text ?? "I've generated the image based on your description."

        return ConversationResponse(
            text: text,
            image: image,
            messageIndex: history.count
        )
    }

    private func buildContextPrompt(message: String, history: [ConversationMessage]) -> String {
        // Only include recent context to avoid token limits
        let recentHistory = history.suffix(maxContextMessages)

        var contextParts: [String] = []

        for msg in recentHistory where msg.role == .user {
            if let text = msg.text {
                contextParts.append("Previous request: \(text)")
            }
        }

        if contextParts.isEmpty {
            return message
        }

        // Build context string
        let context = contextParts.joined(separator: "\n")
        return """
        Context of our conversation:
        \(context)

        Current request: \(message)
        """
    }
}

// MARK: - Convenience Extensions

extension GeminiImageConversationManager {

    /// Quick edit: start session, add image, send message, return result
    public func quickEdit(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        instruction: String,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> GeneratedImage {
        let session = startSession(withImage: imageData, imageMimeType: imageMimeType)
        defer { endSession(session.sessionId) }

        let response = try await sendMessage(
            instruction,
            sessionId: session.sessionId,
            model: model
        )

        guard let image = response.image else {
            throw GeminiImageError.editingFailed("No image returned")
        }

        return image
    }

    /// Multi-turn edit: apply multiple instructions sequentially
    public func multiTurnEdit(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        instructions: [String],
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> GeneratedImage {
        let session = startSession(withImage: imageData, imageMimeType: imageMimeType)
        defer { endSession(session.sessionId) }

        var lastImage: GeneratedImage?

        for instruction in instructions {
            let response = try await sendMessage(
                instruction,
                sessionId: session.sessionId,
                model: model
            )

            if let image = response.image {
                lastImage = image
            }
        }

        guard let finalImage = lastImage else {
            throw GeminiImageError.editingFailed("No image returned after edits")
        }

        return finalImage
    }
}
