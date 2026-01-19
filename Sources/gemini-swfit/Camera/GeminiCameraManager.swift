//
//  GeminiCameraManager.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-19.
//

import Foundation
import SwiftyBeaver

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Camera capture and photo editing manager
///
/// This manager provides camera capture capabilities and integrates
/// with the image editing conversation manager for interactive editing.
public class GeminiCameraManager {

    // MARK: - Types

    /// Camera capture configuration
    public struct CaptureConfig: Sendable {
        /// Output image quality (0.0 - 1.0)
        public let quality: Double
        /// Maximum output dimension (width or height)
        public let maxDimension: Int?
        /// Output format
        public let format: ImageOutputFormat
        /// Auto-correct orientation
        public let correctOrientation: Bool

        public init(
            quality: Double = 0.8,
            maxDimension: Int? = 2048,
            format: ImageOutputFormat = .jpeg,
            correctOrientation: Bool = true
        ) {
            self.quality = min(max(quality, 0.0), 1.0)
            self.maxDimension = maxDimension
            self.format = format
            self.correctOrientation = correctOrientation
        }

        public static let `default` = CaptureConfig()

        public static let highQuality = CaptureConfig(
            quality: 1.0,
            maxDimension: 4096,
            format: .png,
            correctOrientation: true
        )

        public static let lowBandwidth = CaptureConfig(
            quality: 0.5,
            maxDimension: 1024,
            format: .jpeg,
            correctOrientation: true
        )
    }

    /// Image metadata that conforms to Sendable
    public struct ImageMetadata: Sendable, Equatable {
        public let colorSpace: String?
        public let orientation: Int?
        public let dpi: Int?
        public let hasAlpha: Bool?
        public let bitDepth: Int?
        public let profileName: String?

        public init(
            colorSpace: String? = nil,
            orientation: Int? = nil,
            dpi: Int? = nil,
            hasAlpha: Bool? = nil,
            bitDepth: Int? = nil,
            profileName: String? = nil
        ) {
            self.colorSpace = colorSpace
            self.orientation = orientation
            self.dpi = dpi
            self.hasAlpha = hasAlpha
            self.bitDepth = bitDepth
            self.profileName = profileName
        }

        public static let empty = ImageMetadata()
    }

    /// Captured photo data
    public struct CapturedPhoto: Sendable {
        public let data: Data
        public let mimeType: String
        public let width: Int?
        public let height: Int?
        public let timestamp: Date
        public let metadata: ImageMetadata?

        public init(
            data: Data,
            mimeType: String,
            width: Int? = nil,
            height: Int? = nil,
            metadata: ImageMetadata? = nil
        ) {
            self.data = data
            self.mimeType = mimeType
            self.width = width
            self.height = height
            self.timestamp = Date()
            self.metadata = metadata
        }
    }

    /// Camera error types
    public enum CameraError: Error, LocalizedError {
        case notAvailable
        case permissionDenied
        case captureFailed(String)
        case processingFailed(String)
        case invalidImageData

        public var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Camera is not available on this device"
            case .permissionDenied:
                return "Camera permission was denied"
            case .captureFailed(let reason):
                return "Photo capture failed: \(reason)"
            case .processingFailed(let reason):
                return "Image processing failed: \(reason)"
            case .invalidImageData:
                return "Invalid image data"
            }
        }
    }

    // MARK: - Properties

    private let client: GeminiClient
    private let conversationManager: GeminiImageConversationManager
    private let logger: SwiftyBeaver.Type

    /// Current capture configuration
    public var captureConfig: CaptureConfig = .default

    // MARK: - Initialization

    public init(
        client: GeminiClient,
        conversationManager: GeminiImageConversationManager? = nil,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.client = client
        self.logger = logger
        self.conversationManager = conversationManager ?? GeminiImageConversationManager(
            client: client,
            logger: logger
        )
    }

    // MARK: - Camera Availability

    /// Check if camera is available
    public var isCameraAvailable: Bool {
        #if canImport(AVFoundation) && !os(macOS)
        return AVCaptureDevice.default(for: .video) != nil
        #else
        return false
        #endif
    }

    /// Request camera permission
    public func requestCameraPermission() async -> Bool {
        #if canImport(AVFoundation) && !os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Photo Processing

    /// Process image data from any source (camera, photo library, file)
    public func processImageData(
        _ data: Data,
        config: CaptureConfig? = nil
    ) throws -> CapturedPhoto {
        let cfg = config ?? captureConfig

        #if canImport(UIKit)
        guard let image = UIImage(data: data) else {
            throw CameraError.invalidImageData
        }

        // Resize if needed
        let processedImage: UIImage
        if let maxDim = cfg.maxDimension {
            processedImage = resizeImage(image, maxDimension: maxDim)
        } else {
            processedImage = image
        }

        // Convert to output format
        let outputData: Data
        let mimeType: String

        switch cfg.format {
        case .jpeg:
            guard let jpegData = processedImage.jpegData(compressionQuality: cfg.quality) else {
                throw CameraError.processingFailed("Failed to create JPEG data")
            }
            outputData = jpegData
            mimeType = "image/jpeg"
        case .png:
            guard let pngData = processedImage.pngData() else {
                throw CameraError.processingFailed("Failed to create PNG data")
            }
            outputData = pngData
            mimeType = "image/png"
        case .webp:
            // Fallback to JPEG for WebP on iOS
            guard let jpegData = processedImage.jpegData(compressionQuality: cfg.quality) else {
                throw CameraError.processingFailed("Failed to create image data")
            }
            outputData = jpegData
            mimeType = "image/jpeg"
        }

        return CapturedPhoto(
            data: outputData,
            mimeType: mimeType,
            width: Int(processedImage.size.width),
            height: Int(processedImage.size.height)
        )

        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else {
            throw CameraError.invalidImageData
        }

        // Get image representation
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw CameraError.processingFailed("Failed to create bitmap representation")
        }

        // Convert to output format
        let outputData: Data
        let mimeType: String

        switch cfg.format {
        case .jpeg:
            guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: cfg.quality]) else {
                throw CameraError.processingFailed("Failed to create JPEG data")
            }
            outputData = jpegData
            mimeType = "image/jpeg"
        case .png:
            guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw CameraError.processingFailed("Failed to create PNG data")
            }
            outputData = pngData
            mimeType = "image/png"
        case .webp:
            // Fallback to PNG for WebP on macOS
            guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw CameraError.processingFailed("Failed to create image data")
            }
            outputData = pngData
            mimeType = "image/png"
        }

        return CapturedPhoto(
            data: outputData,
            mimeType: mimeType,
            width: bitmap.pixelsWide,
            height: bitmap.pixelsHigh
        )

        #else
        // No image processing available
        return CapturedPhoto(
            data: data,
            mimeType: "image/jpeg"
        )
        #endif
    }

    #if canImport(UIKit)
    /// Resize UIImage to max dimension
    private func resizeImage(_ image: UIImage, maxDimension: Int) -> UIImage {
        let size = image.size
        let maxSize = CGFloat(maxDimension)

        guard size.width > maxSize || size.height > maxSize else {
            return image
        }

        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized ?? image
    }
    #endif

    // MARK: - Conversation Integration

    /// Start an editing conversation with a captured/selected photo
    public func startEditingSession(
        with photo: CapturedPhoto
    ) -> GeminiImageConversationManager.ConversationSession {
        return conversationManager.startSession(
            withImage: photo.data,
            imageMimeType: photo.mimeType
        )
    }

    /// Start an editing session with raw image data
    public func startEditingSession(
        withImageData data: Data,
        mimeType: String = "image/jpeg"
    ) -> GeminiImageConversationManager.ConversationSession {
        return conversationManager.startSession(
            withImage: data,
            imageMimeType: mimeType
        )
    }

    /// Send an editing instruction in a session
    public func sendEditInstruction(
        _ instruction: String,
        sessionId: String,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> GeminiImageConversationManager.ConversationResponse {
        return try await conversationManager.sendMessage(
            instruction,
            sessionId: sessionId,
            model: model
        )
    }

    /// End an editing session
    public func endEditingSession(_ sessionId: String) {
        conversationManager.endSession(sessionId)
    }

    /// Get current image from session
    public func getCurrentImage(sessionId: String) -> (data: Data, mimeType: String)? {
        return conversationManager.getCurrentImage(sessionId: sessionId)
    }

    /// Get conversation history
    public func getEditHistory(sessionId: String) -> [GeminiImageConversationManager.ConversationMessage] {
        return conversationManager.getHistory(sessionId: sessionId)
    }

    // MARK: - Quick Operations

    /// Capture photo, process, and start editing session
    public func processAndStartEditing(
        imageData: Data,
        config: CaptureConfig? = nil
    ) throws -> (photo: CapturedPhoto, sessionId: String) {
        let photo = try processImageData(imageData, config: config)
        let session = startEditingSession(with: photo)
        return (photo, session.sessionId)
    }

    /// Quick edit: process image, edit with instruction, return result
    public func quickEdit(
        imageData: Data,
        instruction: String,
        config: CaptureConfig? = nil,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> GeneratedImage {
        let photo = try processImageData(imageData, config: config)

        return try await conversationManager.quickEdit(
            imageData: photo.data,
            imageMimeType: photo.mimeType,
            instruction: instruction,
            model: model
        )
    }

    /// Multi-step editing with instructions
    public func multiStepEdit(
        imageData: Data,
        instructions: [String],
        config: CaptureConfig? = nil,
        model: ImageGenerationModel = .gemini25FlashImage
    ) async throws -> GeneratedImage {
        let photo = try processImageData(imageData, config: config)

        return try await conversationManager.multiTurnEdit(
            imageData: photo.data,
            imageMimeType: photo.mimeType,
            instructions: instructions,
            model: model
        )
    }

    // MARK: - Analyze Captured Photo

    /// Analyze a captured photo
    public func analyzePhoto(
        _ photo: CapturedPhoto,
        prompt: String = "Describe this image in detail.",
        model: GeminiClient.Model = .gemini25Flash
    ) async throws -> String {
        return try await client.analyzeImageContent(
            imageData: photo.data,
            imageMimeType: photo.mimeType,
            prompt: prompt,
            model: model
        )
    }

    /// Analyze image data
    public func analyzeImage(
        _ imageData: Data,
        mimeType: String = "image/jpeg",
        prompt: String = "Describe this image in detail.",
        model: GeminiClient.Model = .gemini25Flash
    ) async throws -> String {
        return try await client.analyzeImageContent(
            imageData: imageData,
            imageMimeType: mimeType,
            prompt: prompt,
            model: model
        )
    }
}

// MARK: - Photo Library Support

extension GeminiCameraManager {

    /// Process multiple images from photo library
    public func processImages(
        _ imagesData: [Data],
        config: CaptureConfig? = nil
    ) throws -> [CapturedPhoto] {
        return try imagesData.map { data in
            try processImageData(data, config: config)
        }
    }

    /// Batch analyze multiple photos
    public func batchAnalyze(
        photos: [CapturedPhoto],
        prompt: String = "Describe this image briefly.",
        model: GeminiClient.Model = .gemini25Flash
    ) async throws -> [String] {
        var results: [String] = []

        for photo in photos {
            let analysis = try await analyzePhoto(photo, prompt: prompt, model: model)
            results.append(analysis)
        }

        return results
    }
}
