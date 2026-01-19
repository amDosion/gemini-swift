//
//  GeminiImageEditor.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-19.
//

import Foundation
import SwiftyBeaver

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Handles image editing operations (inpainting, outpainting, object removal)
public class GeminiImageEditor {

    // MARK: - Properties

    private let baseURL: String
    private let session: URLSession
    private let logger: SwiftyBeaver.Type

    /// API base URL
    private var apiBaseURL: String {
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

    // MARK: - Gemini-based Editing (Conversational)

    /// Edit an image using Gemini models with natural language instructions
    public func editWithGemini(
        prompt: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage,
        apiKey: String
    ) async throws -> ImageEditingResponse {
        guard model.supportsEditing else {
            throw GeminiImageError.modelNotSupported(
                "\(model.rawValue) does not support image editing"
            )
        }

        let endpoint = "\(apiBaseURL)models/\(model.rawValue):generateContent"

        guard let url = URL(string: endpoint) else {
            throw GeminiImageError.invalidConfiguration("Invalid URL")
        }

        // Build request with image and editing prompt
        let requestBody = buildGeminiEditRequest(
            prompt: prompt,
            imageData: imageData,
            mimeType: imageMimeType
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        logger.info("Editing image with Gemini model: \(model.rawValue)")
        logger.debug("Edit prompt: \(prompt)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiImageError.editingFailed("Invalid response")
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Image editing failed: \(errorMessage)")

                if httpResponse.statusCode == 429 {
                    throw GeminiImageError.quotaExceeded
                }

                throw GeminiImageError.serverError(httpResponse.statusCode, errorMessage)
            }

            return try parseGeminiEditResponse(data: data, model: model.rawValue)

        } catch let error as GeminiImageError {
            throw error
        } catch {
            throw GeminiImageError.editingFailed(error.localizedDescription)
        }
    }

    // MARK: - Imagen-based Editing

    /// Edit an image using Imagen models with mask
    public func editWithImagen(
        prompt: String,
        imageData: Data,
        config: ImageEditingConfig,
        model: ImageEditingModel = .imagen3Capability,
        apiKey: String
    ) async throws -> ImageEditingResponse {
        let endpoint = "\(apiBaseURL)models/\(model.rawValue):predict"

        guard let url = URL(string: endpoint) else {
            throw GeminiImageError.invalidConfiguration("Invalid URL")
        }

        // Build Imagen edit request
        let requestBody = buildImagenEditRequest(
            prompt: prompt,
            imageData: imageData,
            config: config
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        logger.info("Editing image with Imagen model: \(model.rawValue)")
        logger.debug("Edit mode: \(config.editMode.rawValue)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiImageError.editingFailed("Invalid response")
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Imagen editing failed: \(errorMessage)")

                if httpResponse.statusCode == 429 {
                    throw GeminiImageError.quotaExceeded
                }

                throw GeminiImageError.serverError(httpResponse.statusCode, errorMessage)
            }

            return try parseImagenEditResponse(
                data: data,
                editMode: config.editMode,
                model: model.rawValue
            )

        } catch let error as GeminiImageError {
            throw error
        } catch {
            throw GeminiImageError.editingFailed(error.localizedDescription)
        }
    }

    // MARK: - Convenience Editing Methods

    /// Inpaint: Insert content into a masked area
    public func inpaintInsert(
        prompt: String,
        imageData: Data,
        maskData: Data,
        numberOfImages: Int = 1,
        model: ImageEditingModel = .imagen3Capability,
        apiKey: String
    ) async throws -> ImageEditingResponse {
        let config = ImageEditingConfig.inpaint(
            maskData: maskData,
            insertContent: true,
            numberOfImages: numberOfImages
        )

        return try await editWithImagen(
            prompt: prompt,
            imageData: imageData,
            config: config,
            model: model,
            apiKey: apiKey
        )
    }

    /// Inpaint: Remove content from a masked area
    public func inpaintRemove(
        prompt: String,
        imageData: Data,
        maskData: Data,
        numberOfImages: Int = 1,
        model: ImageEditingModel = .imagen3Capability,
        apiKey: String
    ) async throws -> ImageEditingResponse {
        let config = ImageEditingConfig.inpaint(
            maskData: maskData,
            insertContent: false,
            numberOfImages: numberOfImages
        )

        return try await editWithImagen(
            prompt: prompt,
            imageData: imageData,
            config: config,
            model: model,
            apiKey: apiKey
        )
    }

    /// Outpaint: Expand image boundaries
    public func outpaint(
        prompt: String,
        imageData: Data,
        outputAspectRatio: ImageAspectRatio,
        numberOfImages: Int = 1,
        model: ImageEditingModel = .imagen3Capability,
        apiKey: String
    ) async throws -> ImageEditingResponse {
        let config = ImageEditingConfig.outpaint(
            outputAspectRatio: outputAspectRatio,
            blendingFactor: 0.01,
            numberOfImages: numberOfImages
        )

        return try await editWithImagen(
            prompt: prompt,
            imageData: imageData,
            config: config,
            model: model,
            apiKey: apiKey
        )
    }

    /// Remove foreground from image
    public func removeForeground(
        imageData: Data,
        prompt: String = "Remove the foreground objects",
        numberOfImages: Int = 1,
        model: ImageEditingModel = .imagen3Capability,
        apiKey: String
    ) async throws -> ImageEditingResponse {
        let config = ImageEditingConfig.removeForeground(numberOfImages: numberOfImages)

        return try await editWithImagen(
            prompt: prompt,
            imageData: imageData,
            config: config,
            model: model,
            apiKey: apiKey
        )
    }

    /// Remove background from image
    public func removeBackground(
        imageData: Data,
        prompt: String = "Remove the background",
        numberOfImages: Int = 1,
        model: ImageEditingModel = .imagen3Capability,
        apiKey: String
    ) async throws -> ImageEditingResponse {
        let config = ImageEditingConfig.removeBackground(numberOfImages: numberOfImages)

        return try await editWithImagen(
            prompt: prompt,
            imageData: imageData,
            config: config,
            model: model,
            apiKey: apiKey
        )
    }

    /// Edit image with natural language (Gemini)
    public func editWithInstructions(
        instructions: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage,
        apiKey: String
    ) async throws -> GeneratedImage {
        let response = try await editWithGemini(
            prompt: instructions,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model,
            apiKey: apiKey
        )

        guard let image = response.firstImage else {
            throw GeminiImageError.editingFailed("No edited image returned")
        }

        return image
    }

    // MARK: - Advanced Editing

    /// Apply style transfer to an image
    public func applyStyle(
        styleDescription: String,
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage,
        apiKey: String
    ) async throws -> GeneratedImage {
        let prompt = "Transform this image to have the following style: \(styleDescription). " +
                     "Maintain the original composition and subject matter while applying the new style."

        return try await editWithInstructions(
            instructions: prompt,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model,
            apiKey: apiKey
        )
    }

    /// Enhance image quality
    public func enhanceQuality(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        model: ImageGenerationModel = .gemini25FlashImage,
        apiKey: String
    ) async throws -> GeneratedImage {
        let prompt = "Enhance this image by improving its quality, sharpness, and clarity. " +
                     "Fix any noise, blur, or compression artifacts while preserving the original content."

        return try await editWithInstructions(
            instructions: prompt,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model,
            apiKey: apiKey
        )
    }

    /// Colorize a black and white image
    public func colorize(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        colorHints: String? = nil,
        model: ImageGenerationModel = .gemini25FlashImage,
        apiKey: String
    ) async throws -> GeneratedImage {
        var prompt = "Colorize this black and white image with natural, realistic colors."

        if let hints = colorHints {
            prompt += " Use these color hints: \(hints)"
        }

        return try await editWithInstructions(
            instructions: prompt,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model,
            apiKey: apiKey
        )
    }

    /// Upscale image
    public func upscale(
        imageData: Data,
        imageMimeType: String = "image/jpeg",
        scaleFactor: Int = 2,
        model: ImageGenerationModel = .gemini25FlashImage,
        apiKey: String
    ) async throws -> GeneratedImage {
        let prompt = "Upscale this image by \(scaleFactor)x while maintaining sharpness and " +
                     "adding realistic details. Preserve the original content and composition."

        return try await editWithInstructions(
            instructions: prompt,
            imageData: imageData,
            imageMimeType: imageMimeType,
            model: model,
            apiKey: apiKey
        )
    }

    // MARK: - Request Builders

    private func buildGeminiEditRequest(
        prompt: String,
        imageData: Data,
        mimeType: String
    ) -> GeminiImageGenerationRequest {
        let base64Image = imageData.base64EncodedString()

        let parts: [GeminiImageGenerationRequest.ImagePart] = [
            GeminiImageGenerationRequest.ImagePart(
                text: nil,
                inlineData: GeminiImageGenerationRequest.InlineImageData(
                    mimeType: mimeType,
                    data: base64Image
                )
            ),
            GeminiImageGenerationRequest.ImagePart(text: prompt, inlineData: nil)
        ]

        let contents: [GeminiImageGenerationRequest.ImageContent] = [
            GeminiImageGenerationRequest.ImageContent(role: "user", parts: parts)
        ]

        let generationConfig = GeminiImageGenerationRequest.ImageGenerationAPIConfig(
            responseModalities: ["TEXT", "IMAGE"],
            candidateCount: 1
        )

        return GeminiImageGenerationRequest(
            contents: contents,
            generationConfig: generationConfig
        )
    }

    private func buildImagenEditRequest(
        prompt: String,
        imageData: Data,
        config: ImageEditingConfig
    ) -> ImagenEditRequest {
        let base64Image = imageData.base64EncodedString()

        // Build mask if provided
        var mask: ImagenEditRequest.ImagenMask?
        if let maskData = config.maskImageData {
            let base64Mask = maskData.base64EncodedString()
            mask = ImagenEditRequest.ImagenMask(
                image: ImagenEditRequest.ImagenImage(bytesBase64Encoded: base64Mask),
                maskMode: config.maskMode.rawValue,
                dilation: config.maskDilation
            )
        } else if config.maskMode != .userProvided {
            // Auto-detect mask mode
            mask = ImagenEditRequest.ImagenMask(
                image: nil,
                maskMode: config.maskMode.rawValue,
                dilation: config.maskDilation
            )
        }

        let instance = ImagenEditRequest.ImagenEditInstance(
            prompt: prompt,
            image: ImagenEditRequest.ImagenImage(bytesBase64Encoded: base64Image),
            mask: mask
        )

        // Build edit config
        var outpaintingConfig: ImagenEditRequest.ImagenEditParameters.EditConfig.OutpaintingConfig?
        if config.editMode == .outpaint {
            outpaintingConfig = ImagenEditRequest.ImagenEditParameters.EditConfig.OutpaintingConfig(
                blendingMode: config.blendingMode,
                blendingFactor: config.blendingFactor,
                targetAspectRatio: config.outputAspectRatio?.rawValue
            )
        }

        let editConfig = ImagenEditRequest.ImagenEditParameters.EditConfig(
            editSteps: config.editSteps,
            outpaintingConfig: outpaintingConfig
        )

        let parameters = ImagenEditRequest.ImagenEditParameters(
            sampleCount: config.numberOfImages,
            editMode: config.editMode.rawValue,
            editConfig: editConfig
        )

        return ImagenEditRequest(
            instances: [instance],
            parameters: parameters
        )
    }

    // MARK: - Response Parsers

    private func parseGeminiEditResponse(
        data: Data,
        model: String
    ) throws -> ImageEditingResponse {
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(GeminiImageGenerationAPIResponse.self, from: data)

        // Check for blocked content
        if let blockReason = apiResponse.promptFeedback?.blockReason {
            throw GeminiImageError.safetyFilterBlocked(blockReason)
        }

        var images: [GeneratedImage] = []

        if let candidates = apiResponse.candidates {
            for candidate in candidates {
                for part in candidate.content.parts {
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

        logger.info("Edited image with Gemini, generated \(images.count) image(s)")

        return ImageEditingResponse(
            images: images,
            originalImageURI: nil,
            editMode: .default_,
            model: model
        )
    }

    private func parseImagenEditResponse(
        data: Data,
        editMode: ImageEditMode,
        model: String
    ) throws -> ImageEditingResponse {
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

        logger.info("Edited image with Imagen, generated \(images.count) image(s)")

        return ImageEditingResponse(
            images: images,
            originalImageURI: nil,
            editMode: editMode,
            model: model
        )
    }
}

// MARK: - Mask Generation Helpers

extension GeminiImageEditor {

    #if canImport(CoreGraphics)
    /// Create a rectangular mask
    /// - Parameters:
    ///   - imageWidth: Width of the mask image
    ///   - imageHeight: Height of the mask image
    ///   - maskRect: Rectangle defining the mask area
    ///   - inverted: If true, inverts the mask
    /// - Returns: PNG data of the mask, or nil if generation fails
    public static func createRectangularMask(
        imageWidth: Int,
        imageHeight: Int,
        maskRect: CGRect,
        inverted: Bool = false
    ) -> Data? {
        let bytesPerPixel = 1
        let bytesPerRow = imageWidth * bytesPerPixel
        let bitsPerComponent = 8

        guard let context = CGContext(
            data: nil,
            width: imageWidth,
            height: imageHeight,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        // Fill with background color
        let backgroundColor: CGFloat = inverted ? 1.0 : 0.0
        let foregroundColor: CGFloat = inverted ? 0.0 : 1.0

        context.setFillColor(gray: backgroundColor, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        // Draw mask rectangle
        context.setFillColor(gray: foregroundColor, alpha: 1.0)
        context.fill(maskRect)

        guard let cgImage = context.makeImage() else {
            return nil
        }

        return convertCGImageToData(cgImage, width: imageWidth, height: imageHeight)
    }

    /// Create a circular mask
    /// - Parameters:
    ///   - imageWidth: Width of the mask image
    ///   - imageHeight: Height of the mask image
    ///   - center: Center point of the circle
    ///   - radius: Radius of the circle
    ///   - inverted: If true, inverts the mask
    /// - Returns: PNG data of the mask, or nil if generation fails
    public static func createCircularMask(
        imageWidth: Int,
        imageHeight: Int,
        center: CGPoint,
        radius: CGFloat,
        inverted: Bool = false
    ) -> Data? {
        let bytesPerPixel = 1
        let bytesPerRow = imageWidth * bytesPerPixel
        let bitsPerComponent = 8

        guard let context = CGContext(
            data: nil,
            width: imageWidth,
            height: imageHeight,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        // Fill with background color
        let backgroundColor: CGFloat = inverted ? 1.0 : 0.0
        let foregroundColor: CGFloat = inverted ? 0.0 : 1.0

        context.setFillColor(gray: backgroundColor, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        // Draw mask circle
        context.setFillColor(gray: foregroundColor, alpha: 1.0)
        context.fillEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        guard let cgImage = context.makeImage() else {
            return nil
        }

        return convertCGImageToData(cgImage, width: imageWidth, height: imageHeight)
    }

    /// Convert CGImage to PNG Data
    private static func convertCGImageToData(_ cgImage: CGImage, width: Int, height: Int) -> Data? {
        #if canImport(UIKit)
        return UIImage(cgImage: cgImage).pngData()
        #elseif canImport(AppKit)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }
    #endif
}
