//
//  GeminiClient+Image.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-19.
//

import Foundation
import SwiftyBeaver

// MARK: - Image Generation Extension

extension GeminiClient {

    // MARK: - Image Manager Access

    /// Create an image manager for advanced image operations
    public func createImageManager() -> GeminiImageManager {
        return GeminiImageManager(client: self, logger: logger)
    }

    // MARK: - Quick Generation Methods

    /// Generate an image from a text prompt
    ///
    /// - Parameters:
    ///   - prompt: Text description of the image to generate
    ///   - model: The image generation model to use (default: gemini25FlashImage)
    ///   - aspectRatio: Aspect ratio for the generated image (default: square)
    /// - Returns: Generated image data and metadata
    public func generateImage(
        prompt: String,
        model: ImageGenerationModel = .gemini25FlashImage,
        aspectRatio: ImageAspectRatio = .square
    ) async throws -> GeneratedImage {
        let manager = createImageManager()
        let config = ImageGenerationConfig(
            numberOfImages: 1,
            aspectRatio: aspectRatio
        )

        return try await manager.generateImage(
            prompt: prompt,
            model: model,
            config: config
        )
    }

    /// Generate multiple images from a text prompt
    ///
    /// - Parameters:
    ///   - prompt: Text description of the images to generate
    ///   - count: Number of images to generate (1-4)
    ///   - model: The image generation model to use
    ///   - aspectRatio: Aspect ratio for the generated images
    /// - Returns: Array of generated images
    public func generateImages(
        prompt: String,
        count: Int = 4,
        model: ImageGenerationModel = .gemini25FlashImage,
        aspectRatio: ImageAspectRatio = .square
    ) async throws -> [GeneratedImage] {
        let manager = createImageManager()

        return try await manager.generateImages(
            prompt: prompt,
            count: count,
            model: model,
            aspectRatio: aspectRatio
        )
    }

    /// Generate a high-resolution image
    ///
    /// - Parameters:
    ///   - prompt: Text description of the image to generate
    ///   - resolution: Output resolution (1K, 2K, or 4K)
    ///   - model: The image generation model to use
    /// - Returns: Generated high-resolution image
    public func generateHighResolutionImage(
        prompt: String,
        resolution: ImageResolution = .resolution4K,
        model: ImageGenerationModel = .gemini3ProImagePreview
    ) async throws -> GeneratedImage {
        let manager = createImageManager()

        return try await manager.generateHighResolutionImage(
            prompt: prompt,
            resolution: resolution,
            model: model
        )
    }

    /// Generate an image based on a reference image
    ///
    /// - Parameters:
    ///   - prompt: Text description of modifications or style
    ///   - referenceImage: Reference image data
    ///   - referenceImageMimeType: MIME type of the reference image
    ///   - model: The image generation model to use
    /// - Returns: Generated image based on reference
    public func generateImageWithReference(
        prompt: String,
        referenceImage: Data,
        referenceImageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> GeneratedImage {
        let manager = createImageManager()

        return try await manager.generateImageWithReference(
            prompt: prompt,
            referenceImage: referenceImage,
            referenceImageMimeType: referenceImageMimeType,
            model: model
        )
    }

    // MARK: - Quick Editing Methods

    /// Edit an image with natural language instructions
    ///
    /// - Parameters:
    ///   - instructions: Natural language editing instructions
    ///   - imageData: Original image data
    ///   - imageMimeType: MIME type of the original image
    ///   - model: The image generation model to use
    /// - Returns: Edited image
    public func editImage(
        instructions: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> GeneratedImage {
        let manager = createImageManager()

        return try await manager.editImage(
            instructions: instructions,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model
        )
    }

    /// Inpaint: Insert new content into a masked area
    ///
    /// - Parameters:
    ///   - prompt: Description of content to insert
    ///   - imageData: Original image data
    ///   - maskData: Mask image data (white = edit area)
    ///   - numberOfImages: Number of variations to generate
    /// - Returns: Array of edited images
    public func inpaintInsert(
        prompt: String,
        imageData: Data,
        maskData: Data,
        numberOfImages: Int = 1
    ) async throws -> [GeneratedImage] {
        let manager = createImageManager()

        return try await manager.inpaintInsert(
            prompt: prompt,
            imageData: imageData,
            maskData: maskData,
            numberOfImages: numberOfImages
        )
    }

    /// Inpaint: Remove content from a masked area
    ///
    /// - Parameters:
    ///   - prompt: Description of the removal operation
    ///   - imageData: Original image data
    ///   - maskData: Mask image data (white = removal area)
    ///   - numberOfImages: Number of variations to generate
    /// - Returns: Array of edited images
    public func inpaintRemove(
        prompt: String,
        imageData: Data,
        maskData: Data,
        numberOfImages: Int = 1
    ) async throws -> [GeneratedImage] {
        let manager = createImageManager()

        return try await manager.inpaintRemove(
            prompt: prompt,
            imageData: imageData,
            maskData: maskData,
            numberOfImages: numberOfImages
        )
    }

    /// Outpaint: Expand image boundaries
    ///
    /// - Parameters:
    ///   - prompt: Description of content to generate in expanded areas
    ///   - imageData: Original image data
    ///   - outputAspectRatio: Target aspect ratio after expansion
    ///   - numberOfImages: Number of variations to generate
    /// - Returns: Array of expanded images
    public func outpaint(
        prompt: String,
        imageData: Data,
        outputAspectRatio: ImageAspectRatio,
        numberOfImages: Int = 1
    ) async throws -> [GeneratedImage] {
        let manager = createImageManager()

        return try await manager.outpaint(
            prompt: prompt,
            imageData: imageData,
            outputAspectRatio: outputAspectRatio,
            numberOfImages: numberOfImages
        )
    }

    /// Remove background from image
    ///
    /// - Parameters:
    ///   - imageData: Original image data
    ///   - prompt: Optional description of the operation
    /// - Returns: Image with background removed
    public func removeBackground(
        imageData: Data,
        prompt: String = "Remove the background"
    ) async throws -> GeneratedImage {
        let manager = createImageManager()

        return try await manager.removeBackground(
            imageData: imageData,
            prompt: prompt
        )
    }

    /// Apply style transfer to an image
    ///
    /// - Parameters:
    ///   - styleDescription: Description of the style to apply
    ///   - imageData: Original image data
    ///   - imageMimeType: MIME type of the original image
    /// - Returns: Stylized image
    public func applyStyle(
        styleDescription: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg"
    ) async throws -> GeneratedImage {
        let manager = createImageManager()

        return try await manager.applyStyle(
            styleDescription: styleDescription,
            imageData: imageData,
            imageMimeType: imageMimeType
        )
    }

    /// Enhance image quality
    ///
    /// - Parameters:
    ///   - imageData: Original image data
    ///   - imageMimeType: MIME type of the original image
    /// - Returns: Enhanced image
    public func enhanceImageQuality(
        imageData: Data,
        imageMimeType: String = "image/jpeg"
    ) async throws -> GeneratedImage {
        let manager = createImageManager()

        return try await manager.enhanceQuality(
            imageData: imageData,
            imageMimeType: imageMimeType
        )
    }

    /// Upscale image
    ///
    /// - Parameters:
    ///   - imageData: Original image data
    ///   - imageMimeType: MIME type of the original image
    ///   - scaleFactor: Scale factor for upscaling
    /// - Returns: Upscaled image
    public func upscaleImage(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        scaleFactor: Int = 2
    ) async throws -> GeneratedImage {
        let manager = createImageManager()

        return try await manager.upscale(
            imageData: imageData,
            imageMimeType: imageMimeType,
            scaleFactor: scaleFactor
        )
    }

    /// Colorize a black and white image
    ///
    /// - Parameters:
    ///   - imageData: Original black and white image data
    ///   - imageMimeType: MIME type of the original image
    ///   - colorHints: Optional hints for coloring
    /// - Returns: Colorized image
    public func colorizeImage(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        colorHints: String? = nil
    ) async throws -> GeneratedImage {
        let manager = createImageManager()

        return try await manager.colorize(
            imageData: imageData,
            imageMimeType: imageMimeType,
            colorHints: colorHints
        )
    }

    // MARK: - Image Analysis

    /// Analyze an image and describe its contents
    ///
    /// - Parameters:
    ///   - imageData: Image data to analyze
    ///   - imageMimeType: MIME type of the image
    ///   - prompt: Custom analysis prompt
    ///   - model: Model to use for analysis
    /// - Returns: Text description of the image
    public func analyzeImageContent(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        prompt: String = "Describe this image in detail.",
        model: Model = .gemini25Flash
    ) async throws -> String {
        let response = try await generateContentWithImage(
            model: model,
            text: prompt,
            imageData: imageData,
            mimeType: imageMimeType
        )

        guard let text = response.candidates.first?.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }

        return text
    }

    /// Compare two images
    ///
    /// - Parameters:
    ///   - image1Data: First image data
    ///   - image2Data: Second image data
    ///   - mimeType: MIME type of the images
    ///   - model: Model to use for comparison
    /// - Returns: Text comparison of the images
    public func compareImages(
        image1Data: Data,
        image2Data: Data,
        mimeType: String = "image/jpeg",
        model: Model = .gemini25Flash
    ) async throws -> String {
        let base64Image1 = image1Data.base64EncodedString()
        let base64Image2 = image2Data.base64EncodedString()

        let imagePart1 = Part(inlineData: InlineData(mimeType: mimeType, data: base64Image1))
        let imagePart2 = Part(inlineData: InlineData(mimeType: mimeType, data: base64Image2))
        let textPart = Part(text: "Compare these two images. Describe their similarities and differences in detail.")

        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [imagePart1, imagePart2, textPart])],
            systemInstruction: nil,
            generationConfig: nil,
            safetySettings: nil
        )

        let response = try await performRequest(model: model, request: request)

        guard let text = response.candidates.first?.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }

        return text
    }

    /// Extract text from an image (OCR)
    ///
    /// - Parameters:
    ///   - imageData: Image data containing text
    ///   - imageMimeType: MIME type of the image
    ///   - model: Model to use for OCR
    /// - Returns: Extracted text from the image
    public func extractTextFromImage(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        model: Model = .gemini25Flash
    ) async throws -> String {
        let prompt = """
        Extract all visible text from this image.
        Preserve the original formatting and structure as much as possible.
        If there are multiple text blocks, separate them clearly.
        """

        return try await analyzeImageContent(
            imageData: imageData,
            imageMimeType: imageMimeType,
            prompt: prompt,
            model: model
        )
    }

    // MARK: - Utility Methods

    /// Generate and save an image to file
    ///
    /// - Parameters:
    ///   - prompt: Text description of the image to generate
    ///   - url: File URL to save the image
    ///   - model: The image generation model to use
    ///   - aspectRatio: Aspect ratio for the generated image
    /// - Returns: URL of the saved image
    @discardableResult
    public func generateAndSaveImage(
        prompt: String,
        to url: URL,
        model: ImageGenerationModel = .gemini25FlashImage,
        aspectRatio: ImageAspectRatio = .square
    ) async throws -> URL {
        let manager = createImageManager()
        let config = ImageGenerationConfig(
            numberOfImages: 1,
            aspectRatio: aspectRatio
        )

        return try await manager.generateAndSave(
            prompt: prompt,
            to: url,
            model: model,
            config: config
        )
    }

    /// Edit and save an image to file
    ///
    /// - Parameters:
    ///   - instructions: Natural language editing instructions
    ///   - imageData: Original image data
    ///   - imageMimeType: MIME type of the original image
    ///   - url: File URL to save the edited image
    ///   - model: The image generation model to use
    /// - Returns: URL of the saved edited image
    @discardableResult
    public func editAndSaveImage(
        instructions: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        to url: URL,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> URL {
        let manager = createImageManager()

        return try await manager.editAndSave(
            instructions: instructions,
            imageData: imageData,
            imageMimeType: imageMimeType,
            to: url,
            model: model
        )
    }
}

// MARK: - Image Session Extension

extension GeminiClient {

    /// Image operation session for batch operations
    public typealias ImageOperationSession = GeminiImageManager.ImageSession

    /// Start an image operation session
    ///
    /// Use this to perform multiple image operations with the same API key
    /// for consistent rate limiting and quota tracking.
    ///
    /// - Returns: An image session for batch operations
    public func startImageSession() -> ImageOperationSession {
        let manager = createImageManager()
        return manager.startSession()
    }

    /// End an image operation session
    ///
    /// - Parameter session: The session to end
    public func endImageSession(_ session: ImageOperationSession) {
        let manager = createImageManager()
        manager.endSession(session)
    }

    /// Generate image within a session
    ///
    /// - Parameters:
    ///   - prompt: Text description of the image to generate
    ///   - model: The image generation model to use
    ///   - aspectRatio: Aspect ratio for the generated image
    ///   - session: The image session to use
    /// - Returns: Generated image
    public func generateImage(
        prompt: String,
        model: ImageGenerationModel = .gemini25FlashImage,
        aspectRatio: ImageAspectRatio = .square,
        session: ImageOperationSession
    ) async throws -> GeneratedImage {
        let manager = createImageManager()
        let config = ImageGenerationConfig(
            numberOfImages: 1,
            aspectRatio: aspectRatio
        )

        return try await manager.generateImage(
            prompt: prompt,
            model: model,
            config: config,
            session: session
        )
    }

    /// Edit image within a session
    ///
    /// - Parameters:
    ///   - instructions: Natural language editing instructions
    ///   - imageData: Original image data
    ///   - imageMimeType: MIME type of the original image
    ///   - model: The image generation model to use
    ///   - session: The image session to use
    /// - Returns: Edited image
    public func editImage(
        instructions: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage,
        session: ImageOperationSession
    ) async throws -> GeneratedImage {
        let manager = createImageManager()

        return try await manager.editImage(
            instructions: instructions,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model,
            session: session
        )
    }
}
