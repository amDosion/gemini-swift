import Foundation
import SwiftyBeaver

// MARK: - Common Upload Error

/// Common upload error types shared across all uploaders
public enum GeminiUploadError: Error, LocalizedError {
    case invalidURL
    case fileNotFound
    case metadataExtractionFailed
    case uploadInitiationFailed(Error)
    case uploadFailed(Error)
    case invalidUploadResponse
    case sessionExpired
    case invalidFileFormat(String)
    case processingTimeout
    case processingFailed(String)

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
        case .invalidFileFormat(let format):
            return "Unsupported file format: \(format)"
        case .processingTimeout:
            return "File processing timed out"
        case .processingFailed(let reason):
            return "File processing failed: \(reason)"
        }
    }
}

// MARK: - Common File Info

/// Unified file info structure for all upload types
public struct GeminiFileInfo: Codable, Sendable {
    public let name: String
    public let displayName: String?
    public let mimeType: String?
    public let sizeBytes: String?
    public let createTime: String?
    public let updateTime: String?
    public let expirationTime: String?
    public let sha256Hash: String?
    public let uri: String
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
        uri: String,
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

    /// Get file ID from URI
    public var fileId: String? {
        return uri.components(separatedBy: "/").last
    }

    /// Check if file is active/ready
    public var isActive: Bool {
        return state?.uppercased() == "ACTIVE"
    }
}

/// Common upload response wrapper
public struct GeminiUploadResponse: Codable, Sendable {
    public let file: GeminiFileInfo
}

// MARK: - Base Upload Session

/// Base upload session with common properties
public struct GeminiUploadSession: Sendable {
    public let sessionID: String
    public let apiKey: String
    public let mediaType: MediaType
    public var uploadedFiles: [GeminiFileInfo]
    public let createdAt: Date

    public enum MediaType: String, Sendable {
        case audio
        case video
        case document
        case image
    }

    public init(
        sessionID: String = UUID().uuidString,
        apiKey: String,
        mediaType: MediaType,
        uploadedFiles: [GeminiFileInfo] = []
    ) {
        self.sessionID = sessionID
        self.apiKey = apiKey
        self.mediaType = mediaType
        self.uploadedFiles = uploadedFiles
        self.createdAt = Date()
    }
}

// MARK: - File Metadata Protocol

/// Protocol for file metadata
public protocol FileMetadata: Sendable {
    var url: URL { get }
    var mimeType: String { get }
    var size: Int64 { get }
    var displayName: String { get }
}

// MARK: - Base Uploader

/// Base uploader with common functionality for all media types
public class GeminiBaseUploader {
    // MARK: - Properties

    public let baseURL: String
    public let session: URLSession
    public let logger: SwiftyBeaver.Type

    // MARK: - Initialization

    public init(
        baseURL: String = "https://generativelanguage.googleapis.com",
        session: URLSession = .shared,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.baseURL = baseURL
        self.session = session
        self.logger = logger
    }

    // MARK: - Common Upload Methods

    /// Initiate a resumable upload
    public func initiateResumableUpload(
        displayName: String,
        mimeType: String,
        fileSize: Int64,
        apiKey: String
    ) async throws -> URL {
        let cleanBaseURL = baseURL.replacingOccurrences(of: "/v1beta/", with: "/")
        let uploadEndpoint = "\(cleanBaseURL)/upload/v1beta/files?key=\(apiKey)"

        guard let url = URL(string: uploadEndpoint) else {
            throw GeminiUploadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        request.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.setValue("\(fileSize)", forHTTPHeaderField: "X-Goog-Upload-Header-Content-Length")
        request.setValue(mimeType, forHTTPHeaderField: "X-Goog-Upload-Header-Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = ["file": ["display_name": displayName]]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        logger.info("Initiating resumable upload for: \(displayName)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let uploadURLString = httpResponse.value(forHTTPHeaderField: "X-Goog-Upload-Url"),
              let uploadURL = URL(string: uploadURLString) else {
            let errorDetails = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Upload initiation failed: \(errorDetails)")
            throw GeminiUploadError.uploadInitiationFailed(
                NSError(domain: "GeminiUploader", code: 0, userInfo: ["response": errorDetails])
            )
        }

        logger.info("Upload initiated successfully")
        return uploadURL
    }

    /// Upload file data to the upload URL
    public func uploadFileData(
        fileURL: URL,
        uploadURL: URL,
        fileSize: Int64
    ) async throws -> GeminiUploadResponse {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("\(fileSize)", forHTTPHeaderField: "Content-Length")
        request.setValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
        request.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")

        let fileData = try Data(contentsOf: fileURL)
        request.httpBody = fileData

        logger.info("Uploading file data: \(fileSize) bytes")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorDetails = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Upload failed with status \(statusCode): \(errorDetails)")
            throw GeminiUploadError.uploadFailed(
                NSError(domain: "GeminiUploader", code: statusCode, userInfo: ["response": errorDetails])
            )
        }

        logger.info("File uploaded successfully")

        do {
            return try JSONDecoder().decode(GeminiUploadResponse.self, from: data)
        } catch {
            logger.error("Failed to decode upload response: \(error.localizedDescription)")
            throw GeminiUploadError.invalidUploadResponse
        }
    }

    /// Wait for file processing to complete
    public func waitForProcessing(
        fileURI: String,
        apiKey: String,
        timeout: TimeInterval = 120,
        pollingInterval: TimeInterval = 2.0
    ) async throws -> GeminiFileInfo {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            guard let fileID = fileURI.components(separatedBy: "/").last else {
                throw GeminiUploadError.invalidURL
            }

            let checkURL = "\(baseURL)/v1beta/files/\(fileID)?key=\(apiKey)"
            guard let url = URL(string: checkURL) else {
                throw GeminiUploadError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let (data, _) = try await session.data(for: request)

            do {
                let fileInfo = try JSONDecoder().decode(GeminiFileInfo.self, from: data)

                switch fileInfo.state?.uppercased() {
                case "ACTIVE":
                    logger.info("File processing completed")
                    return fileInfo
                case "FAILED":
                    throw GeminiUploadError.processingFailed("File processing failed on server")
                default:
                    logger.debug("File state: \(fileInfo.state ?? "unknown"), waiting...")
                }
            } catch let error as GeminiUploadError {
                throw error
            } catch {
                // Try parsing as raw JSON for more details
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let state = json["state"] as? String {
                    if state == "ACTIVE" {
                        // Reconstruct file info from JSON
                        let fileInfo = GeminiFileInfo(
                            name: json["name"] as? String ?? "",
                            displayName: json["displayName"] as? String,
                            mimeType: json["mimeType"] as? String,
                            sizeBytes: json["sizeBytes"] as? String,
                            uri: fileURI,
                            state: state
                        )
                        return fileInfo
                    } else if state == "FAILED" {
                        throw GeminiUploadError.processingFailed("File processing failed on server")
                    }
                }
            }

            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }

        throw GeminiUploadError.processingTimeout
    }

    /// Upload a file with full workflow
    public func uploadFile(
        at fileURL: URL,
        displayName: String,
        mimeType: String,
        apiKey: String,
        waitForProcessing: Bool = true,
        processingTimeout: TimeInterval = 120
    ) async throws -> GeminiFileInfo {
        // Validate file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw GeminiUploadError.fileNotFound
        }

        // Get file size
        let resources = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = resources.fileSize else {
            throw GeminiUploadError.metadataExtractionFailed
        }

        // Initiate upload
        let uploadURL = try await initiateResumableUpload(
            displayName: displayName,
            mimeType: mimeType,
            fileSize: Int64(fileSize),
            apiKey: apiKey
        )

        // Upload file data
        let response = try await uploadFileData(
            fileURL: fileURL,
            uploadURL: uploadURL,
            fileSize: Int64(fileSize)
        )

        // Wait for processing if requested
        if waitForProcessing {
            return try await self.waitForProcessing(
                fileURI: response.file.uri,
                apiKey: apiKey,
                timeout: processingTimeout
            )
        }

        return response.file
    }

    // MARK: - Utility Methods

    /// Extract basic file metadata
    public func extractBasicMetadata(from url: URL) throws -> (size: Int64, name: String) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw GeminiUploadError.fileNotFound
        }

        let resources = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey])

        guard let size = resources.fileSize else {
            throw GeminiUploadError.metadataExtractionFailed
        }

        let name = resources.name ?? url.lastPathComponent

        return (Int64(size), name)
    }

    /// Delete a file from the API
    public func deleteFile(fileURI: String, apiKey: String) async throws {
        guard let fileID = fileURI.components(separatedBy: "/").last else {
            throw GeminiUploadError.invalidURL
        }

        let deleteURL = "\(baseURL)/v1beta/files/\(fileID)?key=\(apiKey)"
        guard let url = URL(string: deleteURL) else {
            throw GeminiUploadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw GeminiUploadError.uploadFailed(
                NSError(domain: "GeminiUploader", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: nil)
            )
        }

        logger.info("File deleted successfully: \(fileID)")
    }

    /// List uploaded files
    public func listFiles(apiKey: String, pageSize: Int = 100) async throws -> [GeminiFileInfo] {
        let listURL = "\(baseURL)/v1beta/files?key=\(apiKey)&pageSize=\(pageSize)"
        guard let url = URL(string: listURL) else {
            throw GeminiUploadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiUploadError.uploadFailed(
                NSError(domain: "GeminiUploader", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: nil)
            )
        }

        struct ListResponse: Codable {
            let files: [GeminiFileInfo]?
        }

        let listResponse = try JSONDecoder().decode(ListResponse.self, from: data)
        return listResponse.files ?? []
    }
}

// MARK: - Session Manager

/// Manages upload sessions across different media types
public actor GeminiUploadSessionManager {
    private var sessions: [String: GeminiUploadSession] = [:]

    public init() {}

    public func createSession(apiKey: String, mediaType: GeminiUploadSession.MediaType) -> GeminiUploadSession {
        let session = GeminiUploadSession(apiKey: apiKey, mediaType: mediaType)
        sessions[session.sessionID] = session
        return session
    }

    public func getSession(_ sessionID: String) -> GeminiUploadSession? {
        return sessions[sessionID]
    }

    public func updateSession(_ session: GeminiUploadSession) {
        sessions[session.sessionID] = session
    }

    public func endSession(_ sessionID: String) {
        sessions.removeValue(forKey: sessionID)
    }

    public func addUploadedFile(_ file: GeminiFileInfo, to sessionID: String) {
        if var session = sessions[sessionID] {
            session.uploadedFiles.append(file)
            sessions[sessionID] = session
        }
    }

    public var activeSessions: [GeminiUploadSession] {
        return Array(sessions.values)
    }

    public func clearExpiredSessions(olderThan maxAge: TimeInterval = 3600) {
        let now = Date()
        sessions = sessions.filter { _, session in
            now.timeIntervalSince(session.createdAt) < maxAge
        }
    }
}

// MARK: - Chunk Upload Support

/// Support for chunked uploads of large files
public struct ChunkUploadConfig: Sendable {
    public let chunkSize: Int
    public let maxRetries: Int
    public let retryDelay: TimeInterval

    public static let `default` = ChunkUploadConfig(
        chunkSize: 5 * 1024 * 1024,  // 5 MB
        maxRetries: 3,
        retryDelay: 1.0
    )

    public static let largeFile = ChunkUploadConfig(
        chunkSize: 10 * 1024 * 1024,  // 10 MB
        maxRetries: 5,
        retryDelay: 2.0
    )

    public init(chunkSize: Int, maxRetries: Int, retryDelay: TimeInterval) {
        self.chunkSize = max(256 * 1024, chunkSize)  // Minimum 256 KB
        self.maxRetries = max(1, maxRetries)
        self.retryDelay = max(0.1, retryDelay)
    }
}

extension GeminiBaseUploader {
    /// Upload a large file in chunks
    public func uploadFileInChunks(
        at fileURL: URL,
        displayName: String,
        mimeType: String,
        apiKey: String,
        config: ChunkUploadConfig = .default,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> GeminiFileInfo {
        let (fileSize, _) = try extractBasicMetadata(from: fileURL)

        // For small files, use regular upload
        if fileSize <= Int64(config.chunkSize) {
            return try await uploadFile(
                at: fileURL,
                displayName: displayName,
                mimeType: mimeType,
                apiKey: apiKey
            )
        }

        // Initiate resumable upload
        let uploadURL = try await initiateResumableUpload(
            displayName: displayName,
            mimeType: mimeType,
            fileSize: fileSize,
            apiKey: apiKey
        )

        // Read file data
        let fileData = try Data(contentsOf: fileURL)
        var offset: Int = 0
        let totalSize = fileData.count

        while offset < totalSize {
            let chunkEnd = min(offset + config.chunkSize, totalSize)
            let chunk = fileData[offset..<chunkEnd]
            let isLastChunk = chunkEnd >= totalSize

            var retries = 0
            var success = false

            while retries < config.maxRetries && !success {
                do {
                    var request = URLRequest(url: uploadURL)
                    request.httpMethod = "POST"
                    request.setValue("\(chunk.count)", forHTTPHeaderField: "Content-Length")
                    request.setValue("\(offset)", forHTTPHeaderField: "X-Goog-Upload-Offset")

                    if isLastChunk {
                        request.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
                    } else {
                        request.setValue("upload", forHTTPHeaderField: "X-Goog-Upload-Command")
                    }

                    request.httpBody = chunk

                    let (data, response) = try await session.data(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw GeminiUploadError.uploadFailed(
                            NSError(domain: "GeminiUploader",
                                    code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                                    userInfo: nil)
                        )
                    }

                    if isLastChunk {
                        let uploadResponse = try JSONDecoder().decode(GeminiUploadResponse.self, from: data)
                        return try await waitForProcessing(
                            fileURI: uploadResponse.file.uri,
                            apiKey: apiKey
                        )
                    }

                    success = true
                    offset = chunkEnd

                    // Report progress
                    let progress = Double(offset) / Double(totalSize)
                    onProgress?(progress)

                } catch {
                    retries += 1
                    if retries >= config.maxRetries {
                        throw error
                    }
                    try await Task.sleep(nanoseconds: UInt64(config.retryDelay * 1_000_000_000))
                }
            }
        }

        throw GeminiUploadError.uploadFailed(
            NSError(domain: "GeminiUploader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload did not complete"])
        )
    }
}
