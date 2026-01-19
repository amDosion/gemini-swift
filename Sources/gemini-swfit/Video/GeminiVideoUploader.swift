//
//  GeminiVideoUploader.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import SwiftyBeaver

public class GeminiVideoUploader {
    
    // MARK: - Errors
    public enum UploadError: Error, LocalizedError {
        case invalidURL
        case fileNotFound
        case metadataExtractionFailed
        case uploadInitiationFailed(Error)
        case uploadFailed(Error)
        case invalidUploadResponse
        case sessionExpired
        case invalidVideoFormat
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL provided"
            case .fileNotFound:
                return "Video file not found at specified path"
            case .metadataExtractionFailed:
                return "Failed to extract video metadata"
            case .uploadInitiationFailed(let error):
                return "Failed to initiate upload: \(error.localizedDescription)"
            case .uploadFailed(let error):
                return "Upload failed: \(error.localizedDescription)"
            case .invalidUploadResponse:
                return "Invalid upload response from server"
            case .sessionExpired:
                return "Upload session has expired"
            case .invalidVideoFormat:
                return "Unsupported video format"
            }
        }
    }
    
    // MARK: - Supported Video Formats
    public enum VideoFormat: String, CaseIterable, Sendable, Equatable {
        case mp4 = "video/mp4"
        case mov = "video/quicktime"
        case avi = "video/x-msvideo"
        case mkv = "video/x-matroska"
        case webm = "video/webm"
        case mpeg = "video/mpeg"
        case wmv = "video/x-ms-wmv"
        
        public var fileExtension: String {
            switch self {
            case .mp4: return "mp4"
            case .mov: return "mov"
            case .avi: return "avi"
            case .mkv: return "mkv"
            case .webm: return "webm"
            case .mpeg: return "mpeg"
            case .wmv: return "wmv"
            }
        }
        
        public static func fromMimeType(_ mimeType: String) -> VideoFormat? {
            return Self.allCases.first { $0.rawValue == mimeType }
        }
        
        public static func fromFileExtension(_ ext: String) -> VideoFormat? {
            return Self.allCases.first { $0.fileExtension.lowercased() == ext.lowercased() }
        }
    }
    
    // MARK: - Models
    public struct VideoMetadata: Sendable {
        public let url: URL
        public let mimeType: String
        public let format: VideoFormat
        public let size: Int64
        public let displayName: String
        public let duration: TimeInterval?
        public let resolution: (width: Int, height: Int)?
        
        public init(
            url: URL,
            mimeType: String,
            format: VideoFormat,
            size: Int64,
            displayName: String,
            duration: TimeInterval? = nil,
            resolution: (width: Int, height: Int)? = nil
        ) {
            self.url = url
            self.mimeType = mimeType
            self.format = format
            self.size = size
            self.displayName = displayName
            self.duration = duration
            self.resolution = resolution
        }
    }
    
    public struct UploadResponse: Codable, Sendable {
        public let file: FileInfo
        
        public struct FileInfo: Codable, Sendable {
            public let name: String
            public let displayName: String?
            public let mimeType: String?
            public let sizeBytes: String?
            public let createTime: String?
            public let updateTime: String?
            public let expirationTime: String?
            public let sha256Hash: String?
            public let uri: String?
            public let state: String?
            
            public init(
                name: String,
                displayName: String? = nil,
                mimeType: String? = nil,
                sizeBytes: String? = nil,
                createTime: String? = nil,
                updateTime: String? = nil,
                expirationTime: String? = nil,
                sha256Hash: String? = nil,
                uri: String? = nil,
                state: String? = nil
            ) {
                self.name = name
                self.displayName = displayName
                self.mimeType = mimeType
                self.sizeBytes = sizeBytes
                self.createTime = createTime
                self.updateTime = updateTime
                self.expirationTime = expirationTime
                self.sha256Hash = sha256Hash
                self.uri = uri
                self.state = state
            }
        }
    }
    
    public struct VideoSession: Sendable {
        public let sessionID: String
        public let apiKey: String
        public let uploadedFiles: [UploadResponse.FileInfo]

        public init(sessionID: String, apiKey: String, uploadedFiles: [UploadResponse.FileInfo] = []) {
            self.sessionID = sessionID
            self.apiKey = apiKey
            self.uploadedFiles = uploadedFiles
        }

        /// Create a new session with an additional uploaded file
        func adding(file: UploadResponse.FileInfo) -> VideoSession {
            return VideoSession(
                sessionID: sessionID,
                apiKey: apiKey,
                uploadedFiles: uploadedFiles + [file]
            )
        }
    }

    // MARK: - Properties
    private let baseURL: String
    private let logger: SwiftyBeaver.Type
    private let sessionManager: URLSession
    private var activeSessions: [String: VideoSession] = [:]
    private let sessionQueue = DispatchQueue(label: "com.gemini.videoUploader.sessions", attributes: .concurrent)

    // MARK: - Initialization
    public init(baseURL: String, logger: SwiftyBeaver.Type = SwiftyBeaver.self) {
        self.baseURL = baseURL
        self.logger = logger
        self.sessionManager = URLSession.shared
    }

    // MARK: - Session Management

    /// Start a new video upload session
    public func startSession(apiKey: String) -> VideoSession {
        let sessionID = UUID().uuidString
        let newSession = VideoSession(sessionID: sessionID, apiKey: apiKey)
        sessionQueue.sync(flags: .barrier) {
            activeSessions[sessionID] = newSession
        }
        logger.info("Started new video upload session: \(sessionID)")
        return newSession
    }

    /// End a video upload session
    public func endSession(_ session: VideoSession) {
        sessionQueue.sync(flags: .barrier) {
            activeSessions.removeValue(forKey: session.sessionID)
        }
        logger.info("Ended video upload session: \(session.sessionID)")
    }

    /// Get active session
    public func getSession(sessionID: String) -> VideoSession? {
        return sessionQueue.sync {
            activeSessions[sessionID]
        }
    }
    
    // MARK: - Upload Methods
    
    /// Upload a single video file
    public func uploadVideo(
        at fileURL: URL,
        displayName: String? = nil,
        session: VideoSession
    ) async throws -> UploadResponse.FileInfo {
        
        // Extract metadata
        let metadata = try extractMetadata(from: fileURL, displayName: displayName)
        
        // Check format support
        guard isFormatSupported(fileURL) else {
            throw UploadError.invalidVideoFormat
        }
        
        // Start upload session
        let uploadURL = try await initiateUpload(
            metadata: metadata,
            session: session
        )
        
        // Upload file data
        let fileInfo = try await uploadFile(
            at: fileURL,
            uploadURL: uploadURL,
            metadata: metadata
        )
        
        // Wait for file to be processed
        guard let fileURI = fileInfo.uri else {
            throw UploadError.invalidUploadResponse
        }
        
        logger.info("Waiting for video processing to complete...")
        let isActive = try await waitForFileProcessing(
            fileURI: fileURI,
            apiKey: session.apiKey,
            timeout: 120
        )
        
        guard isActive else {
            throw UploadError.uploadFailed(NSError(domain: "GeminiVideoUploader", code: -2, userInfo: [NSLocalizedDescriptionKey: "Video processing timed out"]))
        }
        
        logger.info("Video processing completed")
        return fileInfo
    }
    
    /// Upload multiple video files
    public func uploadVideoFiles(
        at fileURLs: [URL],
        displayNames: [String?] = [],
        session: VideoSession
    ) async throws -> [UploadResponse.FileInfo] {
        
        var fileInfos: [UploadResponse.FileInfo] = []
        
        for (index, fileURL) in fileURLs.enumerated() {
            let displayName = index < displayNames.count ? displayNames[index] : nil
            
            do {
                let fileInfo = try await uploadVideo(
                    at: fileURL,
                    displayName: displayName,
                    session: session
                )
                fileInfos.append(fileInfo)
                
                logger.info("Successfully uploaded video: \(fileURL.lastPathComponent)")
                
            } catch {
                logger.error("Failed to upload video \(fileURL.lastPathComponent): \(error)")
                throw error
            }
        }
        
        return fileInfos
    }
    
    // MARK: - Private Methods
    
    /// Extract metadata from video file
    private func extractMetadata(from url: URL, displayName: String?) throws -> VideoMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw UploadError.fileNotFound
        }
        
        let resources = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentTypeKey,
            .nameKey
        ])
        
        guard let fileSize = resources.fileSize else {
            throw UploadError.metadataExtractionFailed
        }
        
        let fileExtension = url.pathExtension.lowercased()
        guard let format = VideoFormat.fromFileExtension(fileExtension) else {
            throw UploadError.invalidVideoFormat
        }
        
        let mimeType = format.rawValue
        let finalDisplayName = displayName ?? resources.name ?? url.lastPathComponent
        
        return VideoMetadata(
            url: url,
            mimeType: mimeType,
            format: format,
            size: Int64(fileSize),
            displayName: finalDisplayName
        )
    }
    
    /// Initiate resumable upload
    private func initiateUpload(
        metadata: VideoMetadata,
        session: VideoSession
    ) async throws -> String {
        
        // Remove /v1beta/ from baseURL if present, then add upload path
        let cleanBaseURL = baseURL.replacingOccurrences(of: "/v1beta/", with: "/")
        let uploadEndpoint = "\(cleanBaseURL)upload/v1beta/files?key=\(session.apiKey)"
        
        var request = URLRequest(url: URL(string: uploadEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        request.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.setValue(String(metadata.size), forHTTPHeaderField: "X-Goog-Upload-Header-Content-Length")
        request.setValue(metadata.mimeType, forHTTPHeaderField: "X-Goog-Upload-Header-Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "file": [
                "display_name": metadata.displayName
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            let (data, response) = try await sessionManager.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UploadError.uploadInitiationFailed(URLError(.badServerResponse))
            }
            
            guard let uploadURL = httpResponse.value(forHTTPHeaderField: "X-Goog-Upload-Url") else {
                if httpResponse.statusCode >= 400 {
                    let errorDetails = String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.error("Upload initiation failed: \(errorDetails)")
                }
                throw UploadError.invalidUploadResponse
            }
            
            return uploadURL
            
        } catch {
            throw UploadError.uploadInitiationFailed(error)
        }
    }
    
    /// Wait for file to be processed and become ACTIVE
    private func waitForFileProcessing(
        fileURI: String,
        apiKey: String,
        timeout: TimeInterval = 60
    ) async throws -> Bool {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Extract file ID from URI
            guard let fileID = fileURI.components(separatedBy: "/").last else {
                throw UploadError.invalidURL
            }
            
            let checkURL = "https://generativelanguage.googleapis.com/v1beta/files/\(fileID)?key=\(apiKey)"
            guard let url = URL(string: checkURL) else {
                throw UploadError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, _) = try await sessionManager.data(for: request)
            
            // Parse the file state from the response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let state = json["state"] as? String {
                if state == "ACTIVE" {
                    return true
                } else if state == "FAILED" {
                    throw UploadError.uploadFailed(NSError(domain: "GeminiVideoUploader", code: -1, userInfo: [NSLocalizedDescriptionKey: "File processing failed"]))
                } else {
                    logger.debug("File state: \(state), waiting...")
                }
            }
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
        }
        
        return false
    }
    
    /// Upload file data using resumable upload
    private func uploadFile(
        at fileURL: URL,
        uploadURL: String,
        metadata: VideoMetadata
    ) async throws -> UploadResponse.FileInfo {
        
        guard let url = URL(string: uploadURL) else {
            throw UploadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(String(metadata.size), forHTTPHeaderField: "Content-Length")
        request.setValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
        request.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            request.httpBody = fileData
            
            let (data, _) = try await sessionManager.data(for: request)
            
            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
            return uploadResponse.file
            
        } catch {
            throw UploadError.uploadFailed(error)
        }
    }
    
    // MARK: - Utility Methods
    
    /// Check if video format is supported
    public func isFormatSupported(_ fileURL: URL) -> Bool {
        let fileExtension = fileURL.pathExtension.lowercased()
        return VideoFormat.fromFileExtension(fileExtension) != nil
    }
    
    /// Get supported video formats
    public var supportedFormats: [VideoFormat] {
        return VideoFormat.allCases
    }
    
    /// Extract metadata without uploading
    public func getVideoMetadata(_ fileURL: URL, displayName: String? = nil) throws -> VideoMetadata {
        return try extractMetadata(from: fileURL, displayName: displayName)
    }
}