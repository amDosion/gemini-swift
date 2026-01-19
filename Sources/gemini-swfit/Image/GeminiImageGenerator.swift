//
//  GeminiImageGenerator.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-19.
//

import Foundation
import SwiftyBeaver

/// Handles image generation using Gemini and Imagen models
public class GeminiImageGenerator {

    // MARK: - Properties

    private let baseURL: String
    private let session: URLSession
    private let logger: SwiftyBeaver.Type

    /// Gemini API base URL
    private var geminiBaseURL: String {
        return baseURL.hasSuffix("/") ? baseURL : "\(baseURL)/"
    }

    // MARK: - Initialization

    public init(
        baseURL: String = "https://generativelanguage.googleapis.com/v1beta",
        session: URLSession = .shared,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.baseURL = baseURL
        self.session = session
        self.logger = logger
    }

    // MARK: - Gemini Image Generation

    /// Generate images using Gemini models (gemini-2.5-flash-image, gemini-3-pro-image-preview)
    public func generateWithGemini(
        prompt: String,
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default,
        apiKey: String
    ) async throws -> ImageGenerationResponse {
        guard model.requiresResponseModalities else {
            throw GeminiImageError.modelNotSupported(
                "\(model.rawValue) does not support responseModalities. Use generateWithImagen instead."
            )
        }

        let endpoint = "\(geminiBaseURL)models/\(model.rawValue):generateContent"

        guard let url = URL(string: endpoint) else {
            throw GeminiImageError.invalidConfiguration("Invalid URL")
        }

        // Build request body
        let requestBody = buildGeminiRequest(prompt: prompt, config: config)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        logger.info("Generating image with Gemini model: \(model.rawValue)")
        logger.debug("Prompt: \(prompt)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiImageError.generationFailed("Invalid response")
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Image generation failed: \(errorMessage)")

                if httpResponse.statusCode == 429 {
                    throw GeminiImageError.quotaExceeded
                }

                throw GeminiImageError.serverError(httpResponse.statusCode, errorMessage)
            }

            return try parseGeminiResponse(data: data, prompt: prompt, model: model.rawValue)

        } catch let error as GeminiImageError {
            throw error
        } catch {
            throw GeminiImageError.generationFailed(error.localizedDescription)
        }
    }

    /// Generate images with reference image (Gemini models)
    public func generateWithGeminiAndReference(
        prompt: String,
        referenceImage: Data,
        referenceImageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage,
        config: ImageGenerationConfig = .default,
        apiKey: String
    ) async throws -> ImageGenerationResponse {
        guard model.requiresResponseModalities else {
            throw GeminiImageError.modelNotSupported(
                "\(model.rawValue) does not support reference images with responseModalities."
            )
        }

        let endpoint = "\(geminiBaseURL)models/\(model.rawValue):generateContent"

        guard let url = URL(string: endpoint) else {
            throw GeminiImageError.invalidConfiguration("Invalid URL")
        }

        // Build request body with reference image
        let requestBody = buildGeminiRequestWithImage(
            prompt: prompt,
            imageData: referenceImage,
            mimeType: referenceImageMimeType,
            config: config
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        logger.info("Generating image with reference using Gemini model: \(model.rawValue)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiImageError.generationFailed("Invalid response")
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GeminiImageError.serverError(httpResponse.statusCode, errorMessage)
            }

            return try parseGeminiResponse(data: data, prompt: prompt, model: model.rawValue)

        } catch let error as GeminiImageError {
            throw error
        } catch {
            throw GeminiImageError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Imagen Generation

    /// Generate images using Imagen models
    public func generateWithImagen(
        prompt: String,
        model: ImageGenerationModel = .imagen3,
        config: ImageGenerationConfig = .default,
        apiKey: String
    ) async throws -> ImageGenerationResponse {
        guard !model.requiresResponseModalities else {
            throw GeminiImageError.modelNotSupported(
                "\(model.rawValue) requires responseModalities. Use generateWithGemini instead."
            )
        }

        let endpoint = "\(geminiBaseURL)models/\(model.rawValue):predict"

        guard let url = URL(string: endpoint) else {
            throw GeminiImageError.invalidConfiguration("Invalid URL")
        }

        // Build Imagen request
        let requestBody = buildImagenRequest(prompt: prompt, config: config)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        logger.info("Generating image with Imagen model: \(model.rawValue)")
        logger.debug("Prompt: \(prompt)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiImageError.generationFailed("Invalid response")
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Imagen generation failed: \(errorMessage)")

                if httpResponse.statusCode == 429 {
                    throw GeminiImageError.quotaExceeded
                }

                throw GeminiImageError.serverError(httpResponse.statusCode, errorMessage)
            }

            return try parseImagenResponse(data: data, prompt: prompt, model: model.rawValue)

        } catch let error as GeminiImageError {
            throw error
        } catch {
            throw GeminiImageError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Request Builders

    private func buildGeminiRequest(
        prompt: String,
        config: ImageGenerationConfig
    ) -> GeminiImageGenerationRequest {
        let parts: [GeminiImageGenerationRequest.ImagePart] = [
            GeminiImageGenerationRequest.ImagePart(text: prompt, inlineData: nil)
        ]

        let contents: [GeminiImageGenerationRequest.ImageContent] = [
            GeminiImageGenerationRequest.ImageContent(role: "user", parts: parts)
        ]

        let generationConfig = GeminiImageGenerationRequest.ImageGenerationAPIConfig(
            responseModalities: ["TEXT", "IMAGE"],
            candidateCount: config.numberOfImages
        )

        return GeminiImageGenerationRequest(
            contents: contents,
            generationConfig: generationConfig
        )
    }

    private func buildGeminiRequestWithImage(
        prompt: String,
        imageData: Data,
        mimeType: String,
        config: ImageGenerationConfig
    ) -> GeminiImageGenerationRequest {
        let base64Image = imageData.base64EncodedString()

        let parts: [GeminiImageGenerationRequest.ImagePart] = [
            GeminiImageGenerationRequest.ImagePart(text: prompt, inlineData: nil),
            GeminiImageGenerationRequest.ImagePart(
                text: nil,
                inlineData: GeminiImageGenerationRequest.InlineImageData(
                    mimeType: mimeType,
                    data: base64Image
                )
            )
        ]

        let contents: [GeminiImageGenerationRequest.ImageContent] = [
            GeminiImageGenerationRequest.ImageContent(role: "user", parts: parts)
        ]

        let generationConfig = GeminiImageGenerationRequest.ImageGenerationAPIConfig(
            responseModalities: ["TEXT", "IMAGE"],
            candidateCount: config.numberOfImages
        )

        return GeminiImageGenerationRequest(
            contents: contents,
            generationConfig: generationConfig
        )
    }

    private func buildImagenRequest(
        prompt: String,
        config: ImageGenerationConfig
    ) -> ImagenGenerationRequest {
        let instance = ImagenGenerationRequest.ImagenInstance(prompt: prompt)

        let outputOptions: ImagenGenerationRequest.ImagenParameters.OutputOptions?
        if config.outputFormat != .png {
            outputOptions = ImagenGenerationRequest.ImagenParameters.OutputOptions(
                mimeType: config.outputFormat.rawValue
            )
        } else {
            outputOptions = nil
        }

        let parameters = ImagenGenerationRequest.ImagenParameters(
            sampleCount: config.numberOfImages,
            aspectRatio: config.aspectRatio.rawValue,
            negativePrompt: config.negativePrompt,
            personGeneration: config.personFilterLevel.rawValue.lowercased(),
            safetyFilterLevel: config.safetyFilterLevel.rawValue,
            addWatermark: config.addWatermark,
            includeRaiReason: config.includeRAIReason,
            language: config.language,
            outputOptions: outputOptions
        )

        return ImagenGenerationRequest(
            instances: [instance],
            parameters: parameters
        )
    }

    // MARK: - Response Parsers

    private func parseGeminiResponse(
        data: Data,
        prompt: String,
        model: String
    ) throws -> ImageGenerationResponse {
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(GeminiImageGenerationAPIResponse.self, from: data)

        // Check for blocked content
        if let blockReason = apiResponse.promptFeedback?.blockReason {
            throw GeminiImageError.safetyFilterBlocked(blockReason)
        }

        var images: [GeneratedImage] = []
        var textResponse: String?

        // Parse candidates
        if let candidates = apiResponse.candidates {
            for candidate in candidates {
                for part in candidate.content.parts {
                    if let text = part.text {
                        textResponse = text
                    }

                    if let inlineData = part.inlineData,
                       let imageData = Data(base64Encoded: inlineData.data) {
                        let image = GeneratedImage(
                            data: imageData,
                            mimeType: inlineData.mimeType,
                            seed: nil,
                            raiFilterReason: nil,
                            wasFiltered: false
                        )
                        images.append(image)
                    }
                }
            }
        }

        // Convert safety ratings
        let safetyRatings = apiResponse.candidates?.first?.safetyRatings?.map { rating in
            ImageSafetyRating(
                category: rating.category,
                probability: rating.probability,
                blocked: rating.blocked ?? false
            )
        }

        logger.info("Generated \(images.count) image(s) with Gemini")

        return ImageGenerationResponse(
            images: images,
            text: textResponse,
            prompt: prompt,
            model: model,
            safetyRatings: safetyRatings
        )
    }

    private func parseImagenResponse(
        data: Data,
        prompt: String,
        model: String
    ) throws -> ImageGenerationResponse {
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ImagenAPIResponse.self, from: data)

        var images: [GeneratedImage] = []

        if let predictions = apiResponse.predictions {
            for prediction in predictions {
                // Check for filtered content
                if let raiReason = prediction.raiFilteredReason, !raiReason.isEmpty {
                    let image = GeneratedImage(
                        data: Data(),
                        mimeType: "image/png",
                        seed: nil,
                        raiFilterReason: raiReason,
                        wasFiltered: true
                    )
                    images.append(image)
                    continue
                }

                // Parse image data
                if let base64String = prediction.bytesBase64Encoded,
                   let imageData = Data(base64Encoded: base64String) {
                    let mimeType = prediction.mimeType ?? "image/png"
                    let image = GeneratedImage(
                        data: imageData,
                        mimeType: mimeType,
                        seed: nil,
                        raiFilterReason: nil,
                        wasFiltered: false
                    )
                    images.append(image)
                }
            }
        }

        logger.info("Generated \(images.count) image(s) with Imagen")

        return ImageGenerationResponse(
            images: images,
            text: nil,
            prompt: prompt,
            model: model,
            safetyRatings: nil
        )
    }

    // MARK: - Convenience Methods

    /// Generate a single image with default settings
    public func generateImage(
        prompt: String,
        model: ImageGenerationModel = .gemini25FlashImage,
        apiKey: String
    ) async throws -> GeneratedImage {
        let response: ImageGenerationResponse

        if model.requiresResponseModalities {
            response = try await generateWithGemini(
                prompt: prompt,
                model: model,
                config: .default,
                apiKey: apiKey
            )
        } else {
            response = try await generateWithImagen(
                prompt: prompt,
                model: model,
                config: .default,
                apiKey: apiKey
            )
        }

        guard let image = response.firstImage else {
            throw GeminiImageError.generationFailed("No image generated")
        }

        return image
    }

    /// Generate multiple images
    public func generateImages(
        prompt: String,
        count: Int = 4,
        model: ImageGenerationModel = .gemini25FlashImage,
        aspectRatio: ImageAspectRatio = .square,
        apiKey: String
    ) async throws -> [GeneratedImage] {
        let config = ImageGenerationConfig(
            numberOfImages: count,
            aspectRatio: aspectRatio
        )

        let response: ImageGenerationResponse

        if model.requiresResponseModalities {
            response = try await generateWithGemini(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: apiKey
            )
        } else {
            response = try await generateWithImagen(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: apiKey
            )
        }

        return response.images.filter { !$0.wasFiltered }
    }

    /// Generate image with specific aspect ratio
    public func generateImageWithAspectRatio(
        prompt: String,
        aspectRatio: ImageAspectRatio,
        model: ImageGenerationModel = .gemini25FlashImage,
        apiKey: String
    ) async throws -> GeneratedImage {
        let config = ImageGenerationConfig(
            numberOfImages: 1,
            aspectRatio: aspectRatio
        )

        let response: ImageGenerationResponse

        if model.requiresResponseModalities {
            response = try await generateWithGemini(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: apiKey
            )
        } else {
            response = try await generateWithImagen(
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

    /// Generate high-resolution image
    public func generateHighResolutionImage(
        prompt: String,
        resolution: ImageResolution = .resolution4K,
        model: ImageGenerationModel = .gemini3ProImagePreview,
        apiKey: String
    ) async throws -> GeneratedImage {
        let config = ImageGenerationConfig(
            numberOfImages: 1,
            aspectRatio: .square,
            resolution: resolution,
            outputFormat: .png,
            safetyFilterLevel: .blockMediumAndAbove,
            personFilterLevel: .allowAdult,
            addWatermark: true
        )

        let response: ImageGenerationResponse

        if model.requiresResponseModalities {
            response = try await generateWithGemini(
                prompt: prompt,
                model: model,
                config: config,
                apiKey: apiKey
            )
        } else {
            response = try await generateWithImagen(
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
}
