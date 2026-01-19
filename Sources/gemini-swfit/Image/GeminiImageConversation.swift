import Foundation
import SwiftyBeaver

// MARK: - Image Conversation Manager

/// Manages multi-turn image generation and editing conversations
public actor ImageConversationManager {
    private let apiKey: String
    private let baseURL: String
    private let model: ImageGenerationModel
    private let config: ImageGenerationConfig
    private let session: URLSession
    private let logger: SwiftyBeaver.Type

    /// Conversation history
    private var history: [ImageConversationTurn] = []

    /// Current thought signature for context preservation
    private var currentThoughtSignature: ThoughtSignature?

    /// Current working image
    private var currentImage: GeneratedImage?

    /// Session ID
    public let sessionId: String

    public init(
        apiKey: String,
        baseURL: String = "https://generativelanguage.googleapis.com/v1beta",
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.config = config
        self.session = URLSession.shared
        self.logger = logger
        self.sessionId = UUID().uuidString
    }

    // MARK: - Public Methods

    /// Generate a new image from text prompt
    public func generate(prompt: String) async throws -> ImageGenerationResponse {
        let turn = ImageConversationTurn(
            role: .user,
            content: .text(prompt)
        )
        history.append(turn)

        let response = try await performGeneration(prompt: prompt, image: nil)

        // Store the response
        if let image = response.images.first {
            currentImage = image
        }
        if let signature = response.thoughtSignature {
            currentThoughtSignature = ThoughtSignature(signature: signature, model: model.rawValue)
        }

        // Add model response to history
        let modelTurn = ImageConversationTurn(
            role: .model,
            content: .image(response.images.first),
            thoughtSignature: response.thoughtSignature
        )
        history.append(modelTurn)

        logger.info("Generated image in session \(sessionId)")
        return response
    }

    /// Edit the current image with a text instruction
    public func edit(instruction: String) async throws -> ImageGenerationResponse {
        guard let currentImage = currentImage else {
            throw ImageConversationError.noImageToEdit
        }

        let turn = ImageConversationTurn(
            role: .user,
            content: .text(instruction)
        )
        history.append(turn)

        let response = try await performGeneration(
            prompt: instruction,
            image: currentImage,
            thoughtSignature: currentThoughtSignature
        )

        // Update current state
        if let image = response.images.first {
            self.currentImage = image
        }
        if let signature = response.thoughtSignature {
            currentThoughtSignature = ThoughtSignature(signature: signature, model: model.rawValue)
        }

        // Add model response to history
        let modelTurn = ImageConversationTurn(
            role: .model,
            content: .image(response.images.first),
            thoughtSignature: response.thoughtSignature
        )
        history.append(modelTurn)

        logger.info("Edited image in session \(sessionId)")
        return response
    }

    /// Edit with a reference image
    public func editWithReference(
        instruction: String,
        referenceImage: ImageInput
    ) async throws -> ImageGenerationResponse {
        let turn = ImageConversationTurn(
            role: .user,
            content: .textAndImage(instruction, referenceImage)
        )
        history.append(turn)

        let response = try await performGenerationWithReference(
            prompt: instruction,
            referenceImage: referenceImage
        )

        if let image = response.images.first {
            currentImage = image
        }
        if let signature = response.thoughtSignature {
            currentThoughtSignature = ThoughtSignature(signature: signature, model: model.rawValue)
        }

        let modelTurn = ImageConversationTurn(
            role: .model,
            content: .image(response.images.first),
            thoughtSignature: response.thoughtSignature
        )
        history.append(modelTurn)

        return response
    }

    /// Set a new base image for editing
    public func setImage(_ image: ImageInput) async throws {
        let data: Data
        if let imageData = image.data {
            data = imageData
        } else if let url = image.url {
            data = try Data(contentsOf: url)
        } else {
            throw ImageConversationError.invalidImage
        }

        currentImage = GeneratedImage(
            data: data,
            mimeType: image.mimeType
        )

        // Clear thought signature when setting new image
        currentThoughtSignature = nil

        let turn = ImageConversationTurn(
            role: .user,
            content: .image(currentImage)
        )
        history.append(turn)

        logger.info("Set new base image in session \(sessionId)")
    }

    /// Get the current image
    public func getCurrentImage() -> GeneratedImage? {
        return currentImage
    }

    /// Get conversation history
    public func getHistory() -> [ImageConversationTurn] {
        return history
    }

    /// Clear conversation and start fresh
    public func reset() {
        history.removeAll()
        currentImage = nil
        currentThoughtSignature = nil
        logger.info("Reset image conversation session \(sessionId)")
    }

    /// Undo last edit (revert to previous image)
    public func undo() -> GeneratedImage? {
        // Find the last model turn with an image before the current one
        var lastImage: GeneratedImage?
        var foundCurrent = false

        for turn in history.reversed() {
            if case .image(let img) = turn.content, let image = img {
                if foundCurrent {
                    lastImage = image
                    break
                }
                if turn.role == .model {
                    foundCurrent = true
                }
            }
        }

        if let lastImage = lastImage {
            currentImage = lastImage
            // Remove last two turns (user instruction + model response)
            if history.count >= 2 {
                history.removeLast(2)
            }
        }

        return lastImage
    }

    // MARK: - Private Methods

    private func performGeneration(
        prompt: String,
        image: GeneratedImage?,
        thoughtSignature: ThoughtSignature? = nil
    ) async throws -> ImageGenerationResponse {
        let url = URL(string: "\(baseURL)/models/\(model.rawValue):generateContent?key=\(apiKey)")!

        var parts: [[String: Any]] = []

        // Add thought signature if available (for multi-turn context)
        if let signature = thoughtSignature, signature.isValid {
            parts.append(["thoughtSignature": signature.signature])
        }

        // Add image if editing
        if let image = image {
            parts.append([
                "inlineData": [
                    "mimeType": image.mimeType,
                    "data": image.base64String
                ]
            ])
        }

        // Add text prompt
        parts.append(["text": prompt])

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": parts]
            ],
            "generationConfig": buildGenerationConfig()
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageConversationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Image generation failed: \(errorMessage)")
            throw ImageConversationError.generationFailed(errorMessage)
        }

        return try parseResponse(data)
    }

    private func performGenerationWithReference(
        prompt: String,
        referenceImage: ImageInput
    ) async throws -> ImageGenerationResponse {
        let url = URL(string: "\(baseURL)/models/\(model.rawValue):generateContent?key=\(apiKey)")!

        var parts: [[String: Any]] = []

        // Add thought signature if available
        if let signature = currentThoughtSignature, signature.isValid {
            parts.append(["thoughtSignature": signature.signature])
        }

        // Add current image if exists
        if let current = currentImage {
            parts.append([
                "inlineData": [
                    "mimeType": current.mimeType,
                    "data": current.base64String
                ]
            ])
        }

        // Add reference image
        if let refData = referenceImage.data {
            parts.append([
                "inlineData": [
                    "mimeType": referenceImage.mimeType,
                    "data": refData.base64EncodedString()
                ]
            ])
        } else if let fileUri = referenceImage.fileUri {
            parts.append([
                "fileData": [
                    "mimeType": referenceImage.mimeType,
                    "fileUri": fileUri
                ]
            ])
        }

        // Add text prompt
        parts.append(["text": prompt])

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": parts]
            ],
            "generationConfig": buildGenerationConfig()
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageConversationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageConversationError.generationFailed(errorMessage)
        }

        return try parseResponse(data)
    }

    private func buildGenerationConfig() -> [String: Any] {
        var imageConfig: [String: Any] = [
            "numberOfImages": config.numberOfImages,
            "aspectRatio": config.aspectRatio.rawValue,
            "safetyFilterLevel": config.safetyFilterLevel.rawValue,
            "personGeneration": config.personGeneration.rawValue,
            "addWatermark": config.addWatermark
        ]

        if let resolution = config.outputResolution {
            imageConfig["outputResolution"] = resolution.rawValue
        }

        return [
            "responseModalities": ["IMAGE", "TEXT"],
            "responseMimeType": "image/\(config.outputFormat.rawValue)",
            "imageGenerationConfig": imageConfig
        ]
    }

    private func parseResponse(_ data: Data) throws -> ImageGenerationResponse {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Check for blocked content
        if let promptFeedback = json?["promptFeedback"] as? [String: Any],
           let blockReason = promptFeedback["blockReason"] as? String {
            return ImageGenerationResponse(
                images: [],
                wasFiltered: true,
                filterReason: blockReason
            )
        }

        guard let candidates = json?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw ImageConversationError.invalidResponse
        }

        var images: [GeneratedImage] = []
        var textResponse: String?
        var thoughtSignature: String?

        for (index, part) in parts.enumerated() {
            if let inlineData = part["inlineData"] as? [String: Any],
               let mimeType = inlineData["mimeType"] as? String,
               let base64Data = inlineData["data"] as? String,
               let imageData = Data(base64Encoded: base64Data) {
                images.append(GeneratedImage(
                    data: imageData,
                    mimeType: mimeType,
                    index: index
                ))
            }

            if let text = part["text"] as? String {
                textResponse = text
            }

            if let signature = part["thoughtSignature"] as? String {
                thoughtSignature = signature
            }
        }

        return ImageGenerationResponse(
            images: images,
            thoughtSignature: thoughtSignature,
            textResponse: textResponse
        )
    }
}

// MARK: - Conversation Turn

/// A single turn in an image conversation
public struct ImageConversationTurn: Sendable {
    public let id: String
    public let role: ConversationRole
    public let content: TurnContent
    public let timestamp: Date
    public let thoughtSignature: String?

    public init(
        id: String = UUID().uuidString,
        role: ConversationRole,
        content: TurnContent,
        timestamp: Date = Date(),
        thoughtSignature: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.thoughtSignature = thoughtSignature
    }
}

/// Role in conversation
public enum ConversationRole: String, Sendable {
    case user
    case model
}

/// Content of a conversation turn
public enum TurnContent: Sendable {
    case text(String)
    case image(GeneratedImage?)
    case textAndImage(String, ImageInput)
}

// MARK: - Errors

public enum ImageConversationError: Error, LocalizedError {
    case noImageToEdit
    case invalidImage
    case invalidResponse
    case generationFailed(String)
    case signatureExpired
    case modelNotSupported

    public var errorDescription: String? {
        switch self {
        case .noImageToEdit:
            return "No image available to edit. Generate or set an image first."
        case .invalidImage:
            return "Invalid image input"
        case .invalidResponse:
            return "Invalid response from server"
        case .generationFailed(let message):
            return "Image generation failed: \(message)"
        case .signatureExpired:
            return "Thought signature has expired. Start a new editing session."
        case .modelNotSupported:
            return "This model does not support multi-turn editing"
        }
    }
}

// MARK: - Image Conversation Builder

/// Builder for creating image conversations with fluent API
public class ImageConversationBuilder {
    private var apiKey: String?
    private var model: ImageGenerationModel = .gemini25FlashImage
    private var config: ImageGenerationConfig = .default
    private var initialPrompt: String?
    private var initialImage: ImageInput?

    public init() {}

    @discardableResult
    public func apiKey(_ key: String) -> Self {
        self.apiKey = key
        return self
    }

    @discardableResult
    public func model(_ model: ImageGenerationModel) -> Self {
        self.model = model
        return self
    }

    @discardableResult
    public func config(_ config: ImageGenerationConfig) -> Self {
        self.config = config
        return self
    }

    @discardableResult
    public func numberOfImages(_ count: Int) -> Self {
        self.config = ImageGenerationConfig(
            numberOfImages: count,
            outputFormat: config.outputFormat,
            aspectRatio: config.aspectRatio,
            safetyFilterLevel: config.safetyFilterLevel,
            personGeneration: config.personGeneration,
            outputResolution: config.outputResolution,
            addWatermark: config.addWatermark
        )
        return self
    }

    @discardableResult
    public func aspectRatio(_ ratio: AspectRatio) -> Self {
        self.config = ImageGenerationConfig(
            numberOfImages: config.numberOfImages,
            outputFormat: config.outputFormat,
            aspectRatio: ratio,
            safetyFilterLevel: config.safetyFilterLevel,
            personGeneration: config.personGeneration,
            outputResolution: config.outputResolution,
            addWatermark: config.addWatermark
        )
        return self
    }

    @discardableResult
    public func resolution(_ resolution: OutputResolution) -> Self {
        self.config = ImageGenerationConfig(
            numberOfImages: config.numberOfImages,
            outputFormat: config.outputFormat,
            aspectRatio: config.aspectRatio,
            safetyFilterLevel: config.safetyFilterLevel,
            personGeneration: config.personGeneration,
            outputResolution: resolution,
            addWatermark: config.addWatermark
        )
        return self
    }

    @discardableResult
    public func initialPrompt(_ prompt: String) -> Self {
        self.initialPrompt = prompt
        return self
    }

    @discardableResult
    public func startWith(image: ImageInput) -> Self {
        self.initialImage = image
        return self
    }

    /// Build the conversation manager
    public func build() throws -> ImageConversationManager {
        guard let apiKey = apiKey else {
            throw ImageConversationError.invalidResponse
        }

        return ImageConversationManager(
            apiKey: apiKey,
            model: model,
            config: config
        )
    }

    /// Build and start with initial prompt
    public func buildAndGenerate() async throws -> (ImageConversationManager, ImageGenerationResponse) {
        let manager = try build()

        if let image = initialImage {
            try await manager.setImage(image)
        }

        guard let prompt = initialPrompt else {
            throw ImageConversationError.invalidResponse
        }

        let response = try await manager.generate(prompt: prompt)
        return (manager, response)
    }
}
