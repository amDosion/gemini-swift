//
//  GeminiImageManager.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-19.
//

import Foundation
import SwiftyBeaver

/// High-level coordinator for all image operations
///
/// GeminiImageManager provides a unified interface for:
/// - Image generation (Gemini and Imagen models)
/// - Image editing (inpainting, outpainting, style transfer)
/// - Image upload and management
/// - Batch operations
///
/// This class coordinates between GeminiImageGenerator, GeminiImageEditor,
/// and GeminiImageUploader to provide a seamless experience.
public class GeminiImageManager {

    // MARK: - Properties

    /// The underlying Gemini client
    private let client: GeminiClient

    /// Image generator for creating new images
    public let generator: GeminiImageGenerator

    /// Image editor for modifying existing images
    public let editor: GeminiImageEditor

    /// Image uploader for file operations
    public let uploader: GeminiImageUploader

    /// Logger instance
    private let logger: SwiftyBeaver.Type

    // MARK: - Initialization

    /// Initialize the image manager with a GeminiClient
    public init(
        client: GeminiClient,
        generator: GeminiImageGenerator? = nil,
        editor: GeminiImageEditor? = nil,
        uploader: GeminiImageUploader? = nil,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.client = client
        self.logger = logger

        let baseURL = client.baseURL.absoluteString

        self.generator = generator ?? GeminiImageGenerator(
            baseURL: baseURL,
            logger: logger
        )

        self.editor = editor ?? GeminiImageEditor(
            baseURL: baseURL,
            logger: logger
        )

        self.uploader = uploader ?? GeminiImageUploader(
            baseURL: baseURL,
            logger: logger
        )
    }

    // MARK: - Generation Methods

    /// Generate an image from a text prompt
    public func generateImage(
        prompt: String,
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        let response: ImageGenerationResponse

        if model.requiresResponseModalities {
            response = try await generator.generateWithGemini(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: apiKey
            )
        } else {
            response = try await generator.generateWithImagen(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: apiKey
            )
        }

        guard let image = response.firstImage else {
            throw GeminiImageError.generationFailed("No image generated")
        }

        logger.info("Generated image with model: \(model.displayName)")
        return image
    }

    /// Generate multiple images from a text prompt
    public func generateImages(
        prompt: String,
        count: Int = 4,
        model: ImageGenerationModel = .gemini25FlashImage,
        aspectRatio: ImageAspectRatio = .square
    ) async throws -> [GeneratedImage] {
        let apiKey = client.getNextApiKey()

        let config = ImageGenerationConfig(
            numberOfImages: count,
            aspectRatio: aspectRatio
        )

        let response: ImageGenerationResponse

        if model.requiresResponseModalities {
            response = try await generator.generateWithGemini(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: apiKey
            )
        } else {
            response = try await generator.generateWithImagen(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: apiKey
            )
        }

        let validImages = response.images.filter { !$0.wasFiltered }
        logger.info("Generated \(validImages.count) images with model: \(model.displayName)")

        return validImages
    }

    /// Generate an image with a specific aspect ratio
    public func generateImageWithAspectRatio(
        prompt: String,
        aspectRatio: ImageAspectRatio,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        let config = ImageGenerationConfig(
            numberOfImages: 1,
            aspectRatio: aspectRatio
        )

        let response: ImageGenerationResponse

        if model.requiresResponseModalities {
            response = try await generator.generateWithGemini(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: apiKey
            )
        } else {
            response = try await generator.generateWithImagen(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: apiKey
            )
        }

        guard let image = response.firstImage else {
            throw GeminiImageError.generationFailed("No image generated")
        }

        return image
    }

    /// Generate a high-resolution image
    public func generateHighResolutionImage(
        prompt: String,
        resolution: ImageResolution = .resolution4K,
        model: ImageGenerationModel = .gemini3ProImagePreview
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        return try await generator.generateHighResolutionImage(
            prompt: prompt,
            resolution: resolution,
            model: model,
            apiKey: apiKey
        )
    }

    /// Generate an image based on a reference image
    public func generateImageWithReference(
        prompt: String,
        referenceImage: Data,
        referenceImageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        let response = try await generator.generateWithGeminiAndReference(
            prompt: prompt,
            referenceImage: referenceImage,
            referenceImageMimeType: referenceImageMimeType,
            model: model,
            config: config,
            apiKey: apiKey
        )

        guard let image = response.firstImage else {
            throw GeminiImageError.generationFailed("No image generated")
        }

        return image
    }

    // MARK: - Editing Methods

    /// Edit an image with natural language instructions
    public func editImage(
        instructions: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        let response = try await editor.editWithGemini(
            prompt: instructions,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model,
            apiKey: apiKey
        )

        guard let image = response.firstImage else {
            throw GeminiImageError.editingFailed("No edited image returned")
        }

        logger.info("Edited image with instructions: \(instructions.prefix(50))...")
        return image
    }

    /// Inpaint: Insert new content into a masked area
    public func inpaintInsert(
        prompt: String,
        imageData: Data,
        maskData: Data,
        numberOfImages: Int = 1
    ) async throws -> [GeneratedImage] {
        let apiKey = client.getNextApiKey()

        let response = try await editor.inpaintInsert(
            prompt: prompt,
            imageData: imageData,
            maskData: maskData,
            numberOfImages: numberOfImages,
            apiKey: apiKey
        )

        return response.images.filter { !$0.wasFiltered }
    }

    /// Inpaint: Remove content from a masked area
    public func inpaintRemove(
        prompt: String,
        imageData: Data,
        maskData: Data,
        numberOfImages: Int = 1
    ) async throws -> [GeneratedImage] {
        let apiKey = client.getNextApiKey()

        let response = try await editor.inpaintRemove(
            prompt: prompt,
            imageData: imageData,
            maskData: maskData,
            numberOfImages: numberOfImages,
            apiKey: apiKey
        )

        return response.images.filter { !$0.wasFiltered }
    }

    /// Outpaint: Expand image boundaries
    public func outpaint(
        prompt: String,
        imageData: Data,
        outputAspectRatio: ImageAspectRatio,
        numberOfImages: Int = 1
    ) async throws -> [GeneratedImage] {
        let apiKey = client.getNextApiKey()

        let response = try await editor.outpaint(
            prompt: prompt,
            imageData: imageData,
            outputAspectRatio: outputAspectRatio,
            numberOfImages: numberOfImages,
            apiKey: apiKey
        )

        return response.images.filter { !$0.wasFiltered }
    }

    /// Remove foreground from image
    public func removeForeground(
        imageData: Data,
        prompt: String = "Remove the foreground objects"
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        let response = try await editor.removeForeground(
            imageData: imageData,
            prompt: prompt,
            apiKey: apiKey
        )

        guard let image = response.firstImage else {
            throw GeminiImageError.editingFailed("No edited image returned")
        }

        return image
    }

    /// Remove background from image
    public func removeBackground(
        imageData: Data,
        prompt: String = "Remove the background"
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        let response = try await editor.removeBackground(
            imageData: imageData,
            prompt: prompt,
            apiKey: apiKey
        )

        guard let image = response.firstImage else {
            throw GeminiImageError.editingFailed("No edited image returned")
        }

        return image
    }

    /// Apply style transfer to an image
    public func applyStyle(
        styleDescription: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg"
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        return try await editor.applyStyle(
            styleDescription: styleDescription,
            imageData: imageData,
            imageMimeType: imageMimeType,
            apiKey: apiKey
        )
    }

    /// Enhance image quality
    public func enhanceQuality(
        imageData: Data,
        imageMimeType: String = "image/jpeg"
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        return try await editor.enhanceQuality(
            imageData: imageData,
            imageMimeType: imageMimeType,
            apiKey: apiKey
        )
    }

    /// Colorize a black and white image
    public func colorize(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        colorHints: String? = nil
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        return try await editor.colorize(
            imageData: imageData,
            imageMimeType: imageMimeType,
            colorHints: colorHints,
            apiKey: apiKey
        )
    }

    /// Upscale image
    public func upscale(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        scaleFactor: Int = 2
    ) async throws -> GeneratedImage {
        let apiKey = client.getNextApiKey()

        return try await editor.upscale(
            imageData: imageData,
            imageMimeType: imageMimeType,
            scaleFactor: scaleFactor,
            apiKey: apiKey
        )
    }

    // MARK: - Upload Methods

    /// Upload an image file
    public func uploadImage(at fileURL: URL, displayName: String? = nil) async throws -> ImageUploadInfo {
        let apiKey = client.getNextApiKey()
        let session = uploader.startSession(apiKey: apiKey)
        defer { uploader.endSession(session) }

        let fileInfo = try await uploader.uploadImage(
            at: fileURL,
            displayName: displayName,
            session: session
        )

        return uploader.createUploadInfo(from: fileInfo)
    }

    /// Upload image from Data
    public func uploadImage(
        data: Data,
        mimeType: String = "image/jpeg",
        displayName: String
    ) async throws -> ImageUploadInfo {
        let apiKey = client.getNextApiKey()
        let session = uploader.startSession(apiKey: apiKey)
        defer { uploader.endSession(session) }

        let fileInfo = try await uploader.uploadImage(
            data: data,
            mimeType: mimeType,
            displayName: displayName,
            session: session
        )

        return uploader.createUploadInfo(from: fileInfo)
    }

    /// Upload multiple images
    public func uploadImages(at fileURLs: [URL]) async throws -> [ImageUploadInfo] {
        let apiKey = client.getNextApiKey()
        let session = uploader.startSession(apiKey: apiKey)
        defer { uploader.endSession(session) }

        let fileInfos = try await uploader.uploadImages(
            at: fileURLs,
            session: session
        )

        return fileInfos.map { uploader.createUploadInfo(from: $0) }
    }

    /// Delete an uploaded image
    public func deleteUploadedImage(uri: String) async throws {
        let apiKey = client.getNextApiKey()
        try await uploader.deleteUploadedImage(fileURI: uri, apiKey: apiKey)
    }

    // MARK: - Batch Operations

    /// Maximum concurrent operations for batch processing
    public static var maxConcurrentOperations: Int = 4

    /// Generate images in batch with concurrent processing
    public func batchGenerateImages(
        prompts: [String],
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default,
        maxConcurrent: Int? = nil
    ) async throws -> [ImageGenerationResponse] {
        let concurrentLimit = maxConcurrent ?? Self.maxConcurrentOperations

        return try await withThrowingTaskGroup(of: (Int, ImageGenerationResponse).self) { group in
            var results: [(Int, ImageGenerationResponse)] = []
            var currentIndex = 0

            // Add initial batch of tasks
            for i in 0..<min(concurrentLimit, prompts.count) {
                let prompt = prompts[i]
                let index = i
                let apiKey = client.getNextApiKey()

                group.addTask {
                    let response: ImageGenerationResponse
                    if model.requiresResponseModalities {
                        response = try await self.generator.generateWithGemini(
                            prompt: prompt,
                            model: model,
                            config: config,
                            apiKey: apiKey
                        )
                    } else {
                        response = try await self.generator.generateWithImagen(
                            prompt: prompt,
                            model: model,
                            config: config,
                            apiKey: apiKey
                        )
                    }
                    return (index, response)
                }
            }
            currentIndex = min(concurrentLimit, prompts.count)

            // Process results and add new tasks
            while let result = try await group.next() {
                results.append(result)

                // Add next task if available
                if currentIndex < prompts.count {
                    let prompt = prompts[currentIndex]
                    let index = currentIndex
                    let apiKey = client.getNextApiKey()

                    group.addTask {
                        let response: ImageGenerationResponse
                        if model.requiresResponseModalities {
                            response = try await self.generator.generateWithGemini(
                                prompt: prompt,
                                model: model,
                                config: config,
                                apiKey: apiKey
                            )
                        } else {
                            response = try await self.generator.generateWithImagen(
                                prompt: prompt,
                                model: model,
                                config: config,
                                apiKey: apiKey
                            )
                        }
                        return (index, response)
                    }
                    currentIndex += 1
                }
            }

            // Sort by original index and return responses
            logger.info("Batch generated \(results.count) image sets concurrently")
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    /// Edit multiple images with the same instructions (concurrent)
    public func batchEditImages(
        instructions: String,
        images: [(data: Data, mimeType: String)],
        model: ImageGenerationModel = .gemini25FlashImage,
        maxConcurrent: Int? = nil
    ) async throws -> [GeneratedImage] {
        let concurrentLimit = maxConcurrent ?? Self.maxConcurrentOperations

        return try await withThrowingTaskGroup(of: (Int, GeneratedImage).self) { group in
            var results: [(Int, GeneratedImage)] = []
            var currentIndex = 0

            // Add initial batch of tasks
            for i in 0..<min(concurrentLimit, images.count) {
                let image = images[i]
                let index = i

                group.addTask {
                    let editedImage = try await self.editImage(
                        instructions: instructions,
                        imageData: image.data,
                        imageMimeType: image.mimeType,
                        model: model
                    )
                    return (index, editedImage)
                }
            }
            currentIndex = min(concurrentLimit, images.count)

            // Process results and add new tasks
            while let result = try await group.next() {
                results.append(result)

                if currentIndex < images.count {
                    let image = images[currentIndex]
                    let index = currentIndex

                    group.addTask {
                        let editedImage = try await self.editImage(
                            instructions: instructions,
                            imageData: image.data,
                            imageMimeType: image.mimeType,
                            model: model
                        )
                        return (index, editedImage)
                    }
                    currentIndex += 1
                }
            }

            logger.info("Batch edited \(results.count) images concurrently")
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Convenience Methods

    /// Generate and save image to file
    public func generateAndSave(
        prompt: String,
        to url: URL,
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default
    ) async throws -> URL {
        let image = try await generateImage(
            prompt: prompt,
            model: model,
            config: config
        )

        try image.data.write(to: url)
        logger.info("Generated and saved image to: \(url.path)")

        return url
    }

    /// Edit and save image to file
    public func editAndSave(
        instructions: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        to url: URL,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> URL {
        let editedImage = try await editImage(
            instructions: instructions,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model
        )

        try editedImage.data.write(to: url)
        logger.info("Edited and saved image to: \(url.path)")

        return url
    }

    /// Analyze an image and generate variations
    public func generateVariations(
        of imageData: Data,
        imageMimeType: String = "image/jpeg",
        count: Int = 4,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> [GeneratedImage] {
        // First, analyze the image to understand its content
        let analysisPrompt = "Describe this image in detail including the subject, style, colors, and composition."

        // Use the client to analyze
        let analysisResponse = try await client.generateContentWithImage(
            model: .gemini25Flash,
            text: analysisPrompt,
            imageData: imageData,
            mimeType: imageMimeType
        )

        guard let description = analysisResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiImageError.generationFailed("Could not analyze image")
        }

        // Generate variations based on the description
        let variationPrompt = "Create a similar image with these characteristics: \(description)"

        return try await generateImages(
            prompt: variationPrompt,
            count: count,
            model: model
        )
    }
}

// MARK: - Session-Based Operations

extension GeminiImageManager {

    /// Create an image session for multiple operations with the same API key
    public struct ImageSession: Sendable {
        let apiKey: String
        let uploadSession: GeminiImageUploader.ImageUploadSession

        fileprivate init(apiKey: String, uploadSession: GeminiImageUploader.ImageUploadSession) {
            self.apiKey = apiKey
            self.uploadSession = uploadSession
        }
    }

    /// Start an image session
    public func startSession() -> ImageSession {
        let apiKey = client.getNextApiKey()
        let uploadSession = uploader.startSession(apiKey: apiKey)
        return ImageSession(apiKey: apiKey, uploadSession: uploadSession)
    }

    /// End an image session
    public func endSession(_ session: ImageSession) {
        uploader.endSession(session.uploadSession)
    }

    /// Generate image within a session
    public func generateImage(
        prompt: String,
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default,
        session: ImageSession
    ) async throws -> GeneratedImage {
        let response: ImageGenerationResponse

        if model.requiresResponseModalities {
            response = try await generator.generateWithGemini(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: session.apiKey
            )
        } else {
            response = try await generator.generateWithImagen(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: session.apiKey
            )
        }

        guard let image = response.firstImage else {
            throw GeminiImageError.generationFailed("No image generated")
        }

        return image
    }

    /// Edit image within a session
    public func editImage(
        instructions: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage,
        session: ImageSession
    ) async throws -> GeneratedImage {
        let response = try await editor.editWithGemini(
            prompt: instructions,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model,
            apiKey: session.apiKey
        )

        guard let image = response.firstImage else {
            throw GeminiImageError.editingFailed("No edited image returned")
        }

        return image
    }

    /// Upload image within a session
    public func uploadImage(
        at fileURL: URL,
        displayName: String? = nil,
        session: ImageSession
    ) async throws -> ImageUploadInfo {
        let fileInfo = try await uploader.uploadImage(
            at: fileURL,
            displayName: displayName,
            session: session.uploadSession
        )

        return uploader.createUploadInfo(from: fileInfo)
    }
}
