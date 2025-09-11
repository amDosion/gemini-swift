//
//  GeminiAudioUploader.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import SwiftyBeaver

public class GeminiAudioUploader {
    
    // MARK: - Errors
    public enum UploadError: Error, LocalizedError {
        case invalidURL
        case fileNotFound
        case metadataExtractionFailed
        case uploadInitiationFailed(Error)
        case uploadFailed(Error)
        case invalidUploadResponse
        case sessionExpired
        case invalidAudioFormat
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL provided"
            case .fileNotFound:
                return "Audio file not found at specified path"
            case .metadataExtractionFailed:
                return "Failed to extract audio metadata"
            case .uploadInitiationFailed(let error):
                return "Failed to initiate upload: \(error.localizedDescription)"
            case .uploadFailed(let error):
                return "Upload failed: \(error.localizedDescription)"
            case .invalidUploadResponse:
                return "Invalid upload response from server"
            case .sessionExpired:
                return "Upload session has expired"
            case .invalidAudioFormat:
                return "Unsupported audio format"
            }
        }
    }
    
    // MARK: - Supported Audio Formats
    public enum AudioFormat: String, CaseIterable, Sendable, Equatable {
        case mp3 = "audio/mpeg"
        case wav = "audio/wav"
        case ogg = "audio/ogg"
        case flac = "audio/flac"
        case m4a = "audio/mp4"
        case aac = "audio/aac"
        
        public var fileExtension: String {
            switch self {
            case .mp3: return "mp3"
            case .wav: return "wav"
            case .ogg: return "ogg"
            case .flac: return "flac"
            case .m4a: return "m4a"
            case .aac: return "aac"
            }
        }
        
        public static func fromMimeType(_ mimeType: String) -> AudioFormat? {
            return Self.allCases.first { $0.rawValue == mimeType }
        }
        
        public static func fromFileExtension(_ ext: String) -> AudioFormat? {
            return Self.allCases.first { $0.fileExtension.lowercased() == ext.lowercased() }
        }
    }
    
    // MARK: - Models
    public struct AudioMetadata: Sendable {
        public let url: URL
        public let mimeType: String
        public let format: AudioFormat
        public let size: Int64
        public let displayName: String
        public let duration: TimeInterval?
        
        public init(url: URL, mimeType: String, format: AudioFormat, size: Int64, displayName: String, duration: TimeInterval? = nil) {
            self.url = url
            self.mimeType = mimeType
            self.format = format
            self.size = size
            self.displayName = displayName
            self.duration = duration
        }
    }
    
    public struct UploadResponse: Codable, Sendable {
        public let file: FileInfo
        
        public struct FileInfo: Codable, Sendable {
            public let name: String
            public let displayName: String?
            public let mimeType: String?
            public let size: String?
            public let createTime: String?
            public let updateTime: String?
            public let expirationTime: String?
            public let sha256: String?
            public let uri: String
            public let state: String?
            
            public init(
                name: String,
                displayName: String? = nil,
                mimeType: String? = nil,
                size: String? = nil,
                createTime: String? = nil,
                updateTime: String? = nil,
                expirationTime: String? = nil,
                sha256: String? = nil,
                uri: String,
                state: String? = nil
            ) {
                self.name = name
                self.displayName = displayName
                self.mimeType = mimeType
                self.size = size
                self.createTime = createTime
                self.updateTime = updateTime
                self.expirationTime = expirationTime
                self.sha256 = sha256
                self.uri = uri
                self.state = state
            }
        }
    }
    
    public struct AudioSession: Sendable {
        public let sessionID: String
        public let apiKey: String
        public var uploadedFiles: [UploadResponse.FileInfo]
        
        public init(sessionID: String, apiKey: String, uploadedFiles: [UploadResponse.FileInfo] = []) {
            self.sessionID = sessionID
            self.apiKey = apiKey
            self.uploadedFiles = uploadedFiles
        }
    }
    
    // MARK: - Properties
    private let baseURL: String
    private let session: URLSession
    private let logger: SwiftyBeaver.Type
    private var activeSessions: [String: AudioSession] = [:]
    
    // MARK: - Initialization
    public init(baseURL: String = "https://generativelanguage.googleapis.com", logger: SwiftyBeaver.Type = SwiftyBeaver.self) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Start a new audio upload session
    public func startSession(apiKey: String) -> AudioSession {
        let sessionID = UUID().uuidString
        let session = AudioSession(sessionID: sessionID, apiKey: apiKey)
        activeSessions[sessionID] = session
        return session
    }
    
    /// Upload an audio file using resumable upload protocol
    public func uploadAudio(
        at fileURL: URL,
        displayName: String? = nil,
        session: AudioSession
    ) async throws -> UploadResponse.FileInfo {
        
        // Extract audio metadata
        let metadata = try extractAudioMetadata(from: fileURL, displayName: displayName)
        
        // Phase 1: Initiate resumable upload
        let uploadURL = try await initiateUpload(
            metadata: metadata,
            apiKey: session.apiKey
        )
        
        // Phase 2: Upload audio data
        let response = try await uploadFileData(
            at: fileURL,
            metadata: metadata,
            to: uploadURL
        )
        
        // Update session
        var updatedSession = session
        updatedSession.uploadedFiles.append(response.file)
        activeSessions[session.sessionID] = updatedSession
        
        return response.file
    }
    
    /// Upload multiple audio files in a session
    public func uploadAudioFiles(
        at fileURLs: [URL],
        displayNames: [String?] = [],
        session: AudioSession
    ) async throws -> [UploadResponse.FileInfo] {
        var results: [UploadResponse.FileInfo] = []
        
        for (index, fileURL) in fileURLs.enumerated() {
            let displayName = index < displayNames.count ? displayNames[index] : nil
            let fileInfo = try await uploadAudio(
                at: fileURL,
                displayName: displayName,
                session: session
            )
            results.append(fileInfo)
        }
        
        return results
    }
    
    /// End an audio session
    public func endSession(_ session: AudioSession) {
        activeSessions.removeValue(forKey: session.sessionID)
    }
    
    // MARK: - Convenience Methods
    
    /// Get supported audio formats
    public var supportedFormats: [AudioFormat] {
        return AudioFormat.allCases
    }
    
    /// Check if a file format is supported
    public func isFormatSupported(_ fileURL: URL) -> Bool {
        let fileExtension = fileURL.pathExtension.lowercased()
        return AudioFormat.fromFileExtension(fileExtension) != nil
    }
    
    // MARK: - Private Methods
    
    internal func extractAudioMetadata(from url: URL, displayName: String?) throws -> AudioMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw UploadError.fileNotFound
        }
        
        // Check if audio format is supported
        guard let format = AudioFormat.fromFileExtension(url.pathExtension) else {
            throw UploadError.invalidAudioFormat
        }
        
        let resources = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .nameKey
        ])
        
        guard let size = resources.fileSize else {
            throw UploadError.metadataExtractionFailed
        }
        
        let fileName = displayName ?? resources.name ?? url.lastPathComponent
        
        // Try to extract duration if available (this is optional and may fail)
        let duration = try? extractAudioDuration(from: url)
        
        return AudioMetadata(
            url: url,
            mimeType: format.rawValue,
            format: format,
            size: Int64(size),
            displayName: fileName,
            duration: duration
        )
    }
    
    private func extractAudioDuration(from url: URL) throws -> TimeInterval? {
        // This is a basic implementation - in a real app, you might want to use AVAsset
        // For now, we'll return nil as duration is optional
        return nil
    }
    
    private func initiateUpload(metadata: AudioMetadata, apiKey: String) async throws -> URL {
        let initiateURL = URL(string: "\(baseURL)/upload/v1beta/files?key=\(apiKey)")!
        
        var request = URLRequest(url: initiateURL)
        request.httpMethod = "POST"
        request.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        request.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.setValue("\(metadata.size)", forHTTPHeaderField: "X-Goog-Upload-Header-Content-Length")
        request.setValue(metadata.mimeType, forHTTPHeaderField: "X-Goog-Upload-Header-Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = ["file": ["display_name": metadata.displayName]]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        logger.info("Initiating audio upload for \(metadata.displayName)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let uploadURLString = httpResponse.value(forHTTPHeaderField: "X-Goog-Upload-Url"),
              let uploadURL = URL(string: uploadURLString) else {
            throw UploadError.uploadInitiationFailed(
                NSError(domain: "GeminiAPI", code: 0, userInfo: [
                    "response": String(data: data, encoding: .utf8) ?? ""
                ])
            )
        }
        
        logger.info("Upload initiated successfully")
        return uploadURL
    }
    
    private func uploadFileData(
        at fileURL: URL,
        metadata: AudioMetadata,
        to uploadURL: URL
    ) async throws -> UploadResponse {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("\(metadata.size)", forHTTPHeaderField: "Content-Length")
        request.setValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
        request.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
        
        let fileData = try Data(contentsOf: fileURL)
        request.httpBody = fileData
        
        logger.info("Uploading audio data: \(metadata.size) bytes")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UploadError.uploadFailed(
                NSError(domain: "GeminiAPI", code: 0, userInfo: [
                    "statusCode": (response as? HTTPURLResponse)?.statusCode ?? 0,
                    "response": String(data: data, encoding: .utf8) ?? ""
                ])
            )
        }
        
        logger.info("Audio uploaded successfully")
        
        do {
            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
            return uploadResponse
        } catch {
            logger.error("Failed to decode upload response: \(error.localizedDescription)")
            throw UploadError.invalidUploadResponse
        }
    }
}