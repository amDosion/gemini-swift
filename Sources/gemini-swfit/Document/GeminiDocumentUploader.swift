//
//  GeminiDocumentUploader.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation

public class GeminiDocumentUploader {
    
    // MARK: - Errors
    public enum UploadError: Error, LocalizedError {
        case invalidURL
        case fileNotFound
        case metadataExtractionFailed
        case uploadInitiationFailed(Error)
        case uploadFailed(Error)
        case invalidUploadResponse
        case sessionExpired
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL provided"
            case .fileNotFound:
                return "File not found at specified path"
            case .metadataExtractionFailed:
                return "Failed to extract file metadata"
            case .uploadInitiationFailed(let error):
                return "Failed to initiate upload: \(error.localizedDescription)"
            case .uploadFailed(let error):
                return "Upload failed: \(error.localizedDescription)"
            case .invalidUploadResponse:
                return "Invalid upload response from server"
            case .sessionExpired:
                return "Upload session has expired"
            }
        }
    }
    
    // MARK: - Models
    public struct FileMetadata {
        public let url: URL
        public let mimeType: String
        public let size: Int64
        public let displayName: String
        
        public init(url: URL, mimeType: String, size: Int64, displayName: String) {
            self.url = url
            self.mimeType = mimeType
            self.size = size
            self.displayName = displayName
        }
    }
    
    public struct UploadResponse: Codable {
        public let file: FileInfo
        
        public struct FileInfo: Codable {
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
        }
    }
    
    public struct DocumentSession {
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
    private var activeSessions: [String: DocumentSession] = [:]
    
    // MARK: - Initialization
    public init(baseURL: String = "https://generativelanguage.googleapis.com") {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)
    }
    
    // MARK: - Public Methods
    
    /// Start a new document upload session
    public func startSession(apiKey: String) -> DocumentSession {
        let sessionID = UUID().uuidString
        let session = DocumentSession(sessionID: sessionID, apiKey: apiKey)
        activeSessions[sessionID] = session
        return session
    }
    
    /// Upload a file using resumable upload protocol
    public func uploadFile(
        at fileURL: URL,
        displayName: String? = nil,
        session: DocumentSession
    ) async throws -> UploadResponse.FileInfo {
        
        // Extract file metadata
        let metadata = try extractMetadata(from: fileURL, displayName: displayName)
        
        // Phase 1: Initiate resumable upload
        let uploadURL = try await initiateUpload(
            metadata: metadata,
            apiKey: session.apiKey
        )
        
        // Phase 2: Upload file data
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
    
    /// Upload multiple files in a session
    public func uploadFiles(
        at fileURLs: [URL],
        displayNames: [String?] = [],
        session: DocumentSession
    ) async throws -> [UploadResponse.FileInfo] {
        var results: [UploadResponse.FileInfo] = []
        
        for (index, fileURL) in fileURLs.enumerated() {
            let displayName = index < displayNames.count ? displayNames[index] : nil
            let fileInfo = try await uploadFile(
                at: fileURL,
                displayName: displayName,
                session: session
            )
            results.append(fileInfo)
        }
        
        return results
    }
    
    /// End a document session
    public func endSession(_ session: DocumentSession) {
        activeSessions.removeValue(forKey: session.sessionID)
    }
    
    // MARK: - Private Methods
    
    private func extractMetadata(from url: URL, displayName: String?) throws -> FileMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw UploadError.fileNotFound
        }
        
        let resources = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .nameKey
        ])
        
        guard let size = resources.fileSize else {
            throw UploadError.metadataExtractionFailed
        }
        
        let mimeType = url.pathExtension == "pdf" ? "application/pdf" : "application/octet-stream"
        let fileName = displayName ?? resources.name ?? url.lastPathComponent
        
        return FileMetadata(
            url: url,
            mimeType: mimeType,
            size: Int64(size),
            displayName: fileName
        )
    }
    
    private func initiateUpload(metadata: FileMetadata, apiKey: String) async throws -> URL {
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
        
        return uploadURL
    }
    
    private func uploadFileData(
        at fileURL: URL,
        metadata: FileMetadata,
        to uploadURL: URL
    ) async throws -> UploadResponse {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("\(metadata.size)", forHTTPHeaderField: "Content-Length")
        request.setValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
        request.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
        
        let fileData = try Data(contentsOf: fileURL)
        request.httpBody = fileData
        
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
        
        do {
            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
            return uploadResponse
        } catch {
            throw UploadError.invalidUploadResponse
        }
    }
}