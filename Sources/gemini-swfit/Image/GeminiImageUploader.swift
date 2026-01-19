//
//  GeminiImageUploader.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-19.
//

import Foundation
import SwiftyBeaver

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(ImageIO)
import ImageIO
#endif

/// Handles image file uploads to the Gemini API
public class GeminiImageUploader: GeminiBaseUploader {

    // MARK: - Types

    /// Supported image formats
    public enum ImageFormat: String, CaseIterable, Sendable {
        case jpeg = "image/jpeg"
        case png = "image/png"
        case gif = "image/gif"
        case webp = "image/webp"
        case heic = "image/heic"
        case heif = "image/heif"
        case bmp = "image/bmp"
        case tiff = "image/tiff"

        public var fileExtensions: [String] {
            switch self {
            case .jpeg: return ["jpg", "jpeg"]
            case .png: return ["png"]
            case .gif: return ["gif"]
            case .webp: return ["webp"]
            case .heic: return ["heic"]
            case .heif: return ["heif"]
            case .bmp: return ["bmp"]
            case .tiff: return ["tif", "tiff"]
            }
        }

        /// Initialize from file extension
        public init?(fileExtension: String) {
            let ext = fileExtension.lowercased()
            for format in ImageFormat.allCases {
                if format.fileExtensions.contains(ext) {
                    self = format
                    return
                }
            }
            return nil
        }

        /// Initialize from file URL
        public init?(url: URL) {
            self.init(fileExtension: url.pathExtension)
        }
    }

    /// Image metadata
    public struct ImageMetadata: FileMetadata, Sendable {
        public let url: URL
        public let mimeType: String
        public let format: ImageFormat
        public let size: Int64
        public let displayName: String
        public let width: Int?
        public let height: Int?

        public init(
            url: URL,
            mimeType: String,
            format: ImageFormat,
            size: Int64,
            displayName: String,
            width: Int? = nil,
            height: Int? = nil
        ) {
            self.url = url
            self.mimeType = mimeType
            self.format = format
            self.size = size
            self.displayName = displayName
            self.width = width
            self.height = height
        }
    }

    /// Image upload session
    public struct ImageUploadSession: Sendable {
        public let sessionID: String
        public let apiKey: String
        public var uploadedImages: [GeminiFileInfo]
        public let createdAt: Date

        public init(
            sessionID: String = UUID().uuidString,
            apiKey: String,
            uploadedImages: [GeminiFileInfo] = []
        ) {
            self.sessionID = sessionID
            self.apiKey = apiKey
            self.uploadedImages = uploadedImages
            self.createdAt = Date()
        }
    }

    // MARK: - Properties

    private var activeSessions: [String: ImageUploadSession] = [:]
    private let sessionQueue = DispatchQueue(label: "com.gemini.imageUploader.sessions", attributes: .concurrent)

    /// Supported image formats
    public var supportedFormats: [ImageFormat] {
        return ImageFormat.allCases
    }

    // MARK: - Initialization

    public override init(
        baseURL: String = "https://generativelanguage.googleapis.com",
        session: URLSession = .shared,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        super.init(baseURL: baseURL, session: session, logger: logger)
    }

    // MARK: - Session Management

    /// Start a new upload session
    public func startSession(apiKey: String) -> ImageUploadSession {
        let session = ImageUploadSession(apiKey: apiKey)
        sessionQueue.sync(flags: .barrier) {
            activeSessions[session.sessionID] = session
        }
        logger.info("Started image upload session: \(session.sessionID)")
        return session
    }

    /// End an upload session
    public func endSession(_ session: ImageUploadSession) {
        sessionQueue.sync(flags: .barrier) {
            activeSessions.removeValue(forKey: session.sessionID)
        }
        logger.info("Ended image upload session: \(session.sessionID)")
    }

    /// Get active session by ID
    public func getSession(_ sessionID: String) -> ImageUploadSession? {
        return sessionQueue.sync {
            activeSessions[sessionID]
        }
    }

    // MARK: - Format Validation

    /// Check if a file format is supported
    public func isFormatSupported(_ fileURL: URL) -> Bool {
        return ImageFormat(url: fileURL) != nil
    }

    /// Get MIME type for a file
    public func getMimeType(for fileURL: URL) -> String? {
        return ImageFormat(url: fileURL)?.rawValue
    }

    // MARK: - Metadata Extraction

    /// Extract metadata from an image file
    public func extractMetadata(from url: URL) throws -> ImageMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw GeminiUploadError.fileNotFound
        }

        guard let format = ImageFormat(url: url) else {
            throw GeminiUploadError.invalidFileFormat(url.pathExtension)
        }

        let (size, name) = try extractBasicMetadata(from: url)

        // Try to get image dimensions
        var width: Int?
        var height: Int?

        #if canImport(CoreGraphics)
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
            width = properties[kCGImagePropertyPixelWidth] as? Int
            height = properties[kCGImagePropertyPixelHeight] as? Int
        }
        #endif

        return ImageMetadata(
            url: url,
            mimeType: format.rawValue,
            format: format,
            size: size,
            displayName: name,
            width: width,
            height: height
        )
    }

    // MARK: - Upload Methods

    /// Upload an image file
    public func uploadImage(
        at fileURL: URL,
        displayName: String? = nil,
        session: ImageUploadSession
    ) async throws -> GeminiFileInfo {
        // Extract metadata
        let metadata = try extractMetadata(from: fileURL)

        // Upload file
        let fileInfo = try await uploadFile(
            at: fileURL,
            displayName: displayName ?? metadata.displayName,
            mimeType: metadata.mimeType,
            apiKey: session.apiKey,
            waitForProcessing: true
        )

        // Update session
        sessionQueue.sync(flags: .barrier) {
            if var updatedSession = activeSessions[session.sessionID] {
                updatedSession.uploadedImages.append(fileInfo)
                activeSessions[session.sessionID] = updatedSession
            }
        }

        logger.info("Image uploaded: \(fileInfo.uri)")
        return fileInfo
    }

    /// Upload image from Data
    public func uploadImage(
        data: Data,
        mimeType: String,
        displayName: String,
        session: ImageUploadSession
    ) async throws -> GeminiFileInfo {
        // Create temporary file
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileExtension = ImageFormat(rawValue: mimeType)?.fileExtensions.first ?? "jpg"
        let tempURL = tempDirectory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")

        do {
            try data.write(to: tempURL)
            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }

            return try await uploadImage(
                at: tempURL,
                displayName: displayName,
                session: session
            )
        } catch {
            throw GeminiUploadError.uploadFailed(error)
        }
    }

    /// Upload multiple images
    public func uploadImages(
        at fileURLs: [URL],
        displayNames: [String?]? = nil,
        session: ImageUploadSession
    ) async throws -> [GeminiFileInfo] {
        var results: [GeminiFileInfo] = []
        let names = displayNames ?? Array(repeating: nil, count: fileURLs.count)

        for (index, fileURL) in fileURLs.enumerated() {
            let displayName = names.indices.contains(index) ? names[index] : nil
            let fileInfo = try await uploadImage(
                at: fileURL,
                displayName: displayName,
                session: session
            )
            results.append(fileInfo)
        }

        return results
    }

    /// Upload image with progress tracking
    public func uploadImageWithProgress(
        at fileURL: URL,
        displayName: String? = nil,
        session: ImageUploadSession,
        onProgress: @escaping (Double) -> Void
    ) async throws -> GeminiFileInfo {
        let metadata = try extractMetadata(from: fileURL)

        // Use chunked upload for progress tracking
        let fileInfo = try await uploadFileInChunks(
            at: fileURL,
            displayName: displayName ?? metadata.displayName,
            mimeType: metadata.mimeType,
            apiKey: session.apiKey,
            config: .default,
            onProgress: onProgress
        )

        // Update session
        sessionQueue.sync(flags: .barrier) {
            if var updatedSession = activeSessions[session.sessionID] {
                updatedSession.uploadedImages.append(fileInfo)
                activeSessions[session.sessionID] = updatedSession
            }
        }

        return fileInfo
    }

    // MARK: - Image Validation

    /// Validate image data
    public func validateImageData(_ data: Data, mimeType: String) throws {
        guard !data.isEmpty else {
            throw GeminiImageError.invalidImageData
        }

        guard ImageFormat(rawValue: mimeType) != nil else {
            throw GeminiImageError.unsupportedImageFormat(mimeType)
        }

        // Check for valid image header bytes
        let headerBytes = data.prefix(16)
        guard isValidImageHeader(headerBytes, mimeType: mimeType) else {
            throw GeminiImageError.invalidImageData
        }
    }

    /// Check if data has valid image header
    private func isValidImageHeader(_ data: Data, mimeType: String) -> Bool {
        guard data.count >= 4 else { return false }

        let bytes = [UInt8](data.prefix(16))

        switch mimeType {
        case "image/jpeg":
            // JPEG magic bytes: FF D8 FF
            return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF

        case "image/png":
            // PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
            return bytes.count >= 8 &&
                   bytes[0] == 0x89 && bytes[1] == 0x50 &&
                   bytes[2] == 0x4E && bytes[3] == 0x47

        case "image/gif":
            // GIF magic bytes: 47 49 46 38
            return bytes.count >= 4 &&
                   bytes[0] == 0x47 && bytes[1] == 0x49 &&
                   bytes[2] == 0x46 && bytes[3] == 0x38

        case "image/webp":
            // WebP: RIFF....WEBP
            return bytes.count >= 12 &&
                   bytes[0] == 0x52 && bytes[1] == 0x49 &&
                   bytes[2] == 0x46 && bytes[3] == 0x46

        case "image/bmp":
            // BMP: 42 4D (BM)
            return bytes[0] == 0x42 && bytes[1] == 0x4D

        default:
            // For other formats, allow if data is not empty
            return true
        }
    }

    // MARK: - Cleanup

    /// Delete uploaded image
    public func deleteUploadedImage(fileURI: String, apiKey: String) async throws {
        try await deleteFile(fileURI: fileURI, apiKey: apiKey)
        logger.info("Deleted uploaded image: \(fileURI)")
    }

    /// Delete all images from a session
    public func deleteSessionImages(session: ImageUploadSession) async throws {
        for fileInfo in session.uploadedImages {
            try await deleteUploadedImage(fileURI: fileInfo.uri, apiKey: session.apiKey)
        }
        logger.info("Deleted all images from session: \(session.sessionID)")
    }
}

// MARK: - Convenience Extensions

extension GeminiImageUploader {
    /// Convert Data to ImageUploadInfo
    public func createUploadInfo(from fileInfo: GeminiFileInfo) -> ImageUploadInfo {
        return ImageUploadInfo(
            id: fileInfo.fileId ?? fileInfo.name,
            uri: fileInfo.uri,
            displayName: fileInfo.displayName,
            mimeType: fileInfo.mimeType ?? "image/jpeg",
            sizeBytes: fileInfo.sizeBytes.flatMap { Int64($0) },
            createTime: fileInfo.createTime.flatMap { ISO8601DateFormatter().date(from: $0) },
            expirationTime: fileInfo.expirationTime.flatMap { ISO8601DateFormatter().date(from: $0) },
            state: fileInfo.isActive ? .active : .processing
        )
    }
}
