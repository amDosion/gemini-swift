//
//  GeminiDocumentConversationManager.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-10.
//

import Foundation

public class GeminiDocumentConversationManager {
    
    // MARK: - Errors
    public enum DocumentError: Error, LocalizedError {
        case sessionNotFound
        case documentUploadFailed(Error)
        case contentGenerationFailed(Error)
        case invalidFileExtension
        case unsupportedMimeType
        case invalidURL
        
        public var errorDescription: String? {
            switch self {
            case .sessionNotFound:
                return "Document session not found"
            case .documentUploadFailed(let error):
                return "Document upload failed: \(error.localizedDescription)"
            case .contentGenerationFailed(let error):
                return "Content generation failed: \(error.localizedDescription)"
            case .invalidFileExtension:
                return "Invalid file extension"
            case .unsupportedMimeType:
                return "Unsupported MIME type"
            case .invalidURL:
                return "Invalid URL"
            }
        }
    }
    
    // MARK: - Models
    public struct DocumentSession {
        public let id: String
        public let apiSession: GeminiClient.APISession
        public let uploadSession: GeminiDocumentUploader.DocumentSession
        public var uploadedDocuments: [GeminiDocumentUploader.UploadResponse.FileInfo]
        
        public init(
            id: String,
            apiSession: GeminiClient.APISession,
            uploadSession: GeminiDocumentUploader.DocumentSession,
            uploadedDocuments: [GeminiDocumentUploader.UploadResponse.FileInfo] = []
        ) {
            self.id = id
            self.apiSession = apiSession
            self.uploadSession = uploadSession
            self.uploadedDocuments = uploadedDocuments
        }
    }
    
    public struct DocumentQuery {
        public let text: String
        public let documents: [URL]
        public let displayNames: [String?]
        public let systemInstruction: String?
        public let generationConfig: GenerationConfig?
        public let safetySettings: [SafetySetting]?
        
        public init(
            text: String,
            documents: [URL],
            displayNames: [String?] = [],
            systemInstruction: String? = nil,
            generationConfig: GenerationConfig? = nil,
            safetySettings: [SafetySetting]? = nil
        ) {
            self.text = text
            self.documents = documents
            self.displayNames = displayNames
            self.systemInstruction = systemInstruction
            self.generationConfig = generationConfig
            self.safetySettings = safetySettings
        }
    }
    
    // MARK: - Properties
    private let client: GeminiClient
    private let uploader: GeminiDocumentUploader
    private var sessions: [String: DocumentSession] = [:]
    
    // MARK: - Initialization
    public init(client: GeminiClient) {
        self.client = client
        self.uploader = GeminiDocumentUploader()
    }
    
    // MARK: - Session Management
    
    /// Create a new document session
    public func createSession() -> DocumentSession {
        let apiSession = client.createSession()
        let uploadSession = uploader.startSession(apiKey: apiSession.apiKey)
        
        let session = DocumentSession(
            id: UUID().uuidString,
            apiSession: apiSession,
            uploadSession: uploadSession
        )
        
        sessions[session.id] = session
        return session
    }
    
    /// End a document session
    public func endSession(_ session: DocumentSession) {
        uploader.endSession(session.uploadSession)
        sessions.removeValue(forKey: session.id)
    }
    
    // MARK: - Document Processing
    
    /// Upload documents to a session
    public func uploadDocuments(
        to session: DocumentSession,
        documents: [URL],
        displayNames: [String?] = []
    ) async throws -> [GeminiDocumentUploader.UploadResponse.FileInfo] {
        let uploadedFiles = try await uploader.uploadFiles(
            at: documents,
            displayNames: displayNames,
            session: session.uploadSession
        )
        
        // Update session
        var updatedSession = session
        updatedSession.uploadedDocuments.append(contentsOf: uploadedFiles)
        sessions[session.id] = updatedSession
        
        return uploadedFiles
    }
    
    /// Process a query with documents
    public func processQuery(
        _ query: DocumentQuery,
        in session: DocumentSession? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let targetSession = session ?? createSession()
        defer {
            if session == nil {
                endSession(targetSession)
            }
        }
        
        // Upload documents if not already uploaded
        var uploadedFiles: [GeminiDocumentUploader.UploadResponse.FileInfo] = []
        
        if !query.documents.isEmpty {
            // Check if documents are already uploaded
            let existingURIs = Set(targetSession.uploadedDocuments.map { $0.uri })
            let newDocuments = query.documents.filter { docURL in
                !existingURIs.contains(docURL.absoluteString)
            }
            
            if !newDocuments.isEmpty {
                uploadedFiles = try await uploadDocuments(
                    to: targetSession,
                    documents: newDocuments,
                    displayNames: query.displayNames
                )
            }
        }
        
        // Combine existing and newly uploaded files
        let allFiles = targetSession.uploadedDocuments + uploadedFiles
        
        // Generate content with all documents
        do {
            return try await client.generateContent(
                model: .gemini25Flash,
                files: allFiles,
                text: query.text,
                session: targetSession.apiSession,
                systemInstruction: query.systemInstruction,
                generationConfig: query.generationConfig,
                safetySettings: query.safetySettings
            )
        } catch {
            throw DocumentError.contentGenerationFailed(error)
        }
    }
    
    /// Process a query with documents (convenience method)
    public func processQuery(
        text: String,
        documents: [URL],
        displayNames: [String?] = [],
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let query = DocumentQuery(
            text: text,
            documents: documents,
            displayNames: displayNames,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        return try await processQuery(query)
    }
    
    /// Download a PDF from URL and process it
    public func processPDFsFromURLs(
        _ urls: [String],
        displayNames: [String?] = [],
        query: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let session = createSession()
        defer { endSession(session) }
        
        var downloadedFiles: [URL] = []
        var actualDisplayNames: [String?] = []
        
        for (index, urlString) in urls.enumerated() {
            guard let url = URL(string: urlString) else {
                throw DocumentError.invalidURL
            }
            
            // Download PDF
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw DocumentError.documentUploadFailed(URLError(.badServerResponse))
            }
            
            // Save to temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = displayNames[index] ?? "document_\(index).pdf"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            downloadedFiles.append(fileURL)
            actualDisplayNames.append(displayNames[index])
        }
        
        // Process the downloaded documents
        return try await processQuery(
            text: query,
            documents: downloadedFiles,
            displayNames: actualDisplayNames,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }
    
    // MARK: - Convenience Methods
    
    /// Process two PDFs with comparison query (like the shell script example)
    public func comparePDFs(
        pdf1URL: URL,
        pdf2URL: URL,
        displayName1: String? = nil,
        displayName2: String? = nil,
        comparisonPrompt: String = "What is the difference between each of the main benchmarks between these two papers? Output these in a table."
    ) async throws -> GeminiGenerateContentResponse {
        return try await processQuery(
            text: comparisonPrompt,
            documents: [pdf1URL, pdf2URL],
            displayNames: [displayName1, displayName2]
        )
    }
    
    /// Process two PDFs from URLs with comparison query
    public func comparePDFsFromURLs(
        pdf1URL: String,
        pdf2URL: String,
        displayName1: String? = nil,
        displayName2: String? = nil,
        comparisonPrompt: String = "What is the difference between each of the main benchmarks between these two papers? Output these in a table."
    ) async throws -> GeminiGenerateContentResponse {
        return try await processPDFsFromURLs(
            [pdf1URL, pdf2URL],
            displayNames: [displayName1, displayName2],
            query: comparisonPrompt
        )
    }
}