import Foundation
import SwiftyBeaver

// MARK: - GeminiClient Image Extension

extension GeminiClient {

    // MARK: - Image Generation

    /// Generate an image from a text prompt
    public func generateImage(
        prompt: String,
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default
    ) async throws -> ImageGenerationResponse {
        let apiKey = getNextApiKey()
        let conversation = ImageConversationManager(
            apiKey: apiKey,
            baseURL: baseURL.absoluteString,
            model: model,
            config: config,
            logger: logger
        )

        return try await conversation.generate(prompt: prompt)
    }

    /// Generate multiple images from a prompt
    public func generateImages(
        prompt: String,
        count: Int = 4,
        model: ImageGenerationModel = .gemini25FlashImage,
        aspectRatio: AspectRatio = .square
    ) async throws -> ImageGenerationResponse {
        let config = ImageGenerationConfig(
            numberOfImages: count,
            aspectRatio: aspectRatio
        )

        return try await generateImage(prompt: prompt, model: model, config: config)
    }

    /// Generate high-quality image with Gemini 3 Pro Image
    public func generateHighQualityImage(
        prompt: String,
        resolution: OutputResolution = .resolution2K,
        aspectRatio: AspectRatio = .square
    ) async throws -> ImageGenerationResponse {
        let config = ImageGenerationConfig(
            outputFormat: .png,
            aspectRatio: aspectRatio,
            outputResolution: resolution
        )

        return try await generateImage(
            prompt: prompt,
            model: .gemini3ProImage,
            config: config
        )
    }

    // MARK: - Image Conversation (Multi-turn Editing)

    /// Create an image conversation session for multi-turn editing
    public func createImageConversation(
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default
    ) -> ImageConversationManager {
        let apiKey = getNextApiKey()
        return ImageConversationManager(
            apiKey: apiKey,
            baseURL: baseURL.absoluteString,
            model: model,
            config: config,
            logger: logger
        )
    }

    /// Quick image editing with conversation
    public func editImage(
        _ image: ImageInput,
        instruction: String,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> ImageGenerationResponse {
        let conversation = createImageConversation(model: model)
        try await conversation.setImage(image)
        return try await conversation.edit(instruction: instruction)
    }

    /// Image conversation builder
    public func imageConversation() -> ImageConversationBuilder {
        let builder = ImageConversationBuilder()
        return builder.apiKey(getNextApiKey())
    }

    // MARK: - Imagen 4

    /// Create an Imagen client for high-quality generation
    public func createImagenClient() -> ImagenClient {
        let apiKey = getNextApiKey()
        return ImagenClient(
            apiKey: apiKey,
            baseURL: baseURL.absoluteString,
            logger: logger
        )
    }

    /// Generate image using Imagen 4
    public func generateWithImagen(
        prompt: String,
        model: ImagenClient.ImagenModel = .imagen4Standard,
        config: ImagenConfig = .default
    ) async throws -> ImagenResponse {
        let client = createImagenClient()
        return try await client.generate(prompt: prompt, model: model, config: config)
    }

    /// Generate image with Imagen 4 Ultra (highest quality)
    public func generateUltraQualityImage(
        prompt: String,
        aspectRatio: ImagenAspectRatio = .square1x1
    ) async throws -> ImagenResponse {
        let config = ImagenConfig(
            aspectRatio: aspectRatio,
            outputOptions: .highQualityPNG
        )
        return try await generateWithImagen(
            prompt: prompt,
            model: .imagen4Ultra,
            config: config
        )
    }

    // MARK: - Image Analysis

    /// Analyze an image and get a description
    public func analyzeImage(
        _ image: ImageInput,
        prompt: String = "Describe this image in detail.",
        model: Model = .gemini25Flash
    ) async throws -> String {
        let imageData: Data
        if let data = image.data {
            imageData = data
        } else if let url = image.url {
            imageData = try Data(contentsOf: url)
        } else {
            throw GeminiError.invalidResponse
        }

        let response = try await generateContentWithImage(
            model: model,
            text: prompt,
            imageData: imageData,
            mimeType: image.mimeType
        )

        return response.candidates.first?.content.parts.compactMap { $0.text }.joined() ?? ""
    }

    /// Analyze multiple images
    public func analyzeImages(
        _ images: [ImageInput],
        prompt: String,
        model: Model = .gemini25Flash
    ) async throws -> String {
        var parts: [Part] = []

        // Add text prompt
        parts.append(Part(text: prompt))

        // Add all images
        for image in images {
            let imageData: Data
            if let data = image.data {
                imageData = data
            } else if let url = image.url {
                imageData = try Data(contentsOf: url)
            } else {
                continue
            }

            let inlineData = InlineData(
                mimeType: image.mimeType,
                data: imageData.base64EncodedString()
            )
            parts.append(Part(inlineData: inlineData))
        }

        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: parts)]
        )

        let response = try await performRequest(model: model, request: request)
        return response.candidates.first?.content.parts.compactMap { $0.text }.joined() ?? ""
    }

    /// Compare two images
    public func compareImages(
        image1: ImageInput,
        image2: ImageInput,
        comparisonPrompt: String = "Compare these two images and describe the differences.",
        model: Model = .gemini25Flash
    ) async throws -> String {
        return try await analyzeImages(
            [image1, image2],
            prompt: comparisonPrompt,
            model: model
        )
    }

    /// Extract text from image (OCR)
    public func extractText(
        from image: ImageInput,
        model: Model = .gemini25Flash
    ) async throws -> String {
        return try await analyzeImage(
            image,
            prompt: "Extract and transcribe all text visible in this image. Return only the extracted text.",
            model: model
        )
    }

    /// Detect objects in image
    public func detectObjects(
        in image: ImageInput,
        model: Model = .gemini25Flash
    ) async throws -> [DetectedObject] {
        let response = try await analyzeImage(
            image,
            prompt: """
            Detect all objects in this image. For each object, provide:
            1. Object name
            2. Approximate location (top-left, top-right, center, bottom-left, bottom-right)
            3. Confidence (high, medium, low)

            Format as JSON array: [{"name": "...", "location": "...", "confidence": "..."}]
            """,
            model: model
        )

        // Parse JSON response
        guard let data = response.data(using: .utf8),
              let objects = try? JSONDecoder().decode([DetectedObject].self, from: data) else {
            return []
        }

        return objects
    }

    // MARK: - Image + Text Generation

    /// Generate text and image in one response
    public func generateTextAndImage(
        prompt: String,
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default
    ) async throws -> (text: String?, images: [GeneratedImage]) {
        let response = try await generateImage(prompt: prompt, model: model, config: config)
        return (response.textResponse, response.images)
    }

    // MARK: - Image Editing Shortcuts

    /// Apply a style to an image
    public func applyStyle(
        to image: ImageInput,
        style: String,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> ImageGenerationResponse {
        return try await editImage(
            image,
            instruction: "Apply \(style) style to this image",
            model: model
        )
    }

    /// Remove background from image
    public func removeBackground(
        from image: ImageInput,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> ImageGenerationResponse {
        return try await editImage(
            image,
            instruction: "Remove the background from this image, keep only the main subject",
            model: model
        )
    }

    /// Change background of image
    public func changeBackground(
        of image: ImageInput,
        to newBackground: String,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> ImageGenerationResponse {
        return try await editImage(
            image,
            instruction: "Change the background to: \(newBackground)",
            model: model
        )
    }

    /// Enhance image quality
    public func enhanceImage(
        _ image: ImageInput,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> ImageGenerationResponse {
        return try await editImage(
            image,
            instruction: "Enhance this image: improve quality, sharpen details, and optimize colors",
            model: model
        )
    }

    /// Colorize a black and white image
    public func colorize(
        _ image: ImageInput,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> ImageGenerationResponse {
        return try await editImage(
            image,
            instruction: "Colorize this black and white image with realistic colors",
            model: model
        )
    }

    /// Expand image (outpainting)
    public func expandImage(
        _ image: ImageInput,
        direction: ExpandDirection,
        description: String? = nil,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> ImageGenerationResponse {
        var instruction = "Expand this image to the \(direction.rawValue)"
        if let desc = description {
            instruction += " with: \(desc)"
        }

        return try await editImage(image, instruction: instruction, model: model)
    }
}

// MARK: - Supporting Types

/// Detected object from image analysis
public struct DetectedObject: Codable, Sendable {
    public let name: String
    public let location: String
    public let confidence: String

    public init(name: String, location: String, confidence: String) {
        self.name = name
        self.location = location
        self.confidence = confidence
    }
}

/// Direction for image expansion
public enum ExpandDirection: String, Sendable {
    case left
    case right
    case top
    case bottom
    case all = "all sides"
}

// MARK: - Convenience Extensions

extension ImageInput {
    /// Create from UIImage data (iOS/macOS compatible)
    public static func fromPNG(_ data: Data) -> ImageInput {
        return ImageInput(data: data, mimeType: "image/png")
    }

    /// Create from JPEG data
    public static func fromJPEG(_ data: Data) -> ImageInput {
        return ImageInput(data: data, mimeType: "image/jpeg")
    }
}

extension GeneratedImage {
    /// Get file extension based on MIME type
    public var fileExtension: String {
        switch mimeType {
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "image/webp": return "webp"
        default: return "png"
        }
    }

    /// Suggested filename
    public var suggestedFilename: String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "generated_\(timestamp)_\(index).\(fileExtension)"
    }
}

extension ImageGenerationResponse {
    /// Get first image or nil
    public var firstImage: GeneratedImage? {
        return images.first
    }

    /// Get first image data or nil
    public var firstImageData: Data? {
        return images.first?.data
    }

    /// Save all images to directory
    public func saveAll(to directory: URL, prefix: String = "image") throws -> [URL] {
        var savedURLs: [URL] = []

        for (index, image) in images.enumerated() {
            let filename = "\(prefix)_\(index).\(image.fileExtension)"
            let fileURL = directory.appendingPathComponent(filename)
            try image.save(to: fileURL)
            savedURLs.append(fileURL)
        }

        return savedURLs
    }
}
