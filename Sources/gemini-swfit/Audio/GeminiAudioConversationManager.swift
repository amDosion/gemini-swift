//
//  GeminiAudioConversationManager.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-11.
//

import Foundation

public class GeminiAudioConversationManager {
    
    // MARK: - Errors
    public enum AudioError: Error, LocalizedError {
        case sessionNotFound
        case audioUploadFailed(Error)
        case transcriptionFailed(Error)
        case invalidAudioFile
        case unsupportedAudioFormat
        case invalidURL
        
        public var errorDescription: String? {
            switch self {
            case .sessionNotFound:
                return "Audio session not found"
            case .audioUploadFailed(let error):
                return "Audio upload failed: \(error.localizedDescription)"
            case .transcriptionFailed(let error):
                return "Transcription failed: \(error.localizedDescription)"
            case .invalidAudioFile:
                return "Invalid audio file"
            case .unsupportedAudioFormat:
                return "Unsupported audio format"
            case .invalidURL:
                return "Invalid URL"
            }
        }
    }
    
    // MARK: - Models
    public struct AudioSession {
        public let id: String
        public let apiSession: GeminiClient.APISession
        public let uploadSession: GeminiAudioUploader.AudioSession
        public var uploadedAudios: [GeminiAudioUploader.UploadResponse.FileInfo]
        
        public init(
            id: String,
            apiSession: GeminiClient.APISession,
            uploadSession: GeminiAudioUploader.AudioSession,
            uploadedAudios: [GeminiAudioUploader.UploadResponse.FileInfo] = []
        ) {
            self.id = id
            self.apiSession = apiSession
            self.uploadSession = uploadSession
            self.uploadedAudios = uploadedAudios
        }
    }
    
    public struct AudioQuery {
        public let text: String
        public let audioFiles: [URL]
        public let displayNames: [String?]
        public let systemInstruction: String?
        public let generationConfig: GenerationConfig?
        public let safetySettings: [SafetySetting]?
        public let language: String?
        
        public init(
            text: String,
            audioFiles: [URL],
            displayNames: [String?] = [],
            systemInstruction: String? = nil,
            generationConfig: GenerationConfig? = nil,
            safetySettings: [SafetySetting]? = nil,
            language: String? = nil
        ) {
            self.text = text
            self.audioFiles = audioFiles
            self.displayNames = displayNames
            self.systemInstruction = systemInstruction
            self.generationConfig = generationConfig
            self.safetySettings = safetySettings
            self.language = language
        }
    }
    
    // MARK: - Properties
    private let client: GeminiClient
    private let uploader: GeminiAudioUploader
    private var sessions: [String: AudioSession] = [:]
    
    // MARK: - Initialization
    public init(client: GeminiClient) {
        self.client = client
        self.uploader = GeminiAudioUploader()
    }
    
    // MARK: - Session Management
    
    /// Create a new audio session
    public func createSession() -> AudioSession {
        let apiSession = client.createSession()
        let uploadSession = uploader.startSession(apiKey: apiSession.apiKey)
        
        let session = AudioSession(
            id: UUID().uuidString,
            apiSession: apiSession,
            uploadSession: uploadSession
        )
        
        sessions[session.id] = session
        return session
    }
    
    /// End an audio session
    public func endSession(_ session: AudioSession) {
        uploader.endSession(session.uploadSession)
        sessions.removeValue(forKey: session.id)
    }
    
    // MARK: - Audio Processing
    
    /// Upload audio files to a session
    public func uploadAudios(
        to session: AudioSession,
        audioFiles: [URL],
        displayNames: [String?] = []
    ) async throws -> [GeminiAudioUploader.UploadResponse.FileInfo] {
        var uploadedFiles: [GeminiAudioUploader.UploadResponse.FileInfo] = []
        
        for (index, audioFile) in audioFiles.enumerated() {
            let displayName = displayNames.indices.contains(index) ? displayNames[index] : nil
            let fileInfo = try await uploader.uploadAudio(
                at: audioFile,
                displayName: displayName,
                session: session.uploadSession
            )
            uploadedFiles.append(fileInfo)
        }
        
        // Update session
        var updatedSession = session
        updatedSession.uploadedAudios.append(contentsOf: uploadedFiles)
        sessions[session.id] = updatedSession
        
        return uploadedFiles
    }
    
    /// Process a query with audio files
    public func processQuery(
        _ query: AudioQuery,
        in session: AudioSession? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let targetSession = session ?? createSession()
        defer {
            if session == nil {
                endSession(targetSession)
            }
        }
        
        // Upload audio files if not already uploaded
        var uploadedFiles: [GeminiAudioUploader.UploadResponse.FileInfo] = []
        
        if !query.audioFiles.isEmpty {
            // Check if audio files are already uploaded
            let existingURIs = Set(targetSession.uploadedAudios.map { $0.uri })
            let newAudioFiles = query.audioFiles.filter { audioURL in
                !existingURIs.contains(audioURL.absoluteString)
            }
            
            if !newAudioFiles.isEmpty {
                uploadedFiles = try await uploadAudios(
                    to: targetSession,
                    audioFiles: newAudioFiles,
                    displayNames: query.displayNames
                )
            }
        }
        
        // Combine existing and newly uploaded files
        let allFiles = targetSession.uploadedAudios + uploadedFiles
        
        // Build request parts
        var parts: [Part] = [Part(text: query.text)]
        
        // Add all audio files
        for fileInfo in allFiles {
            if let mimeType = fileInfo.mimeType {
                parts.append(Part(fileData: FileData(
                    mimeType: mimeType,
                    fileUri: fileInfo.uri
                )))
            }
        }
        
        // Generate content with all audio files
        do {
            let request = GeminiGenerateContentRequest(
                contents: [Content(parts: parts)],
                systemInstruction: query.systemInstruction != nil ? 
                    SystemInstruction(parts: [Part(text: query.systemInstruction!)]) : nil,
                generationConfig: query.generationConfig,
                safetySettings: query.safetySettings
            )
            
            return try await client.generateContent(
                model: .gemini25Flash,
                request: request
            )
        } catch {
            throw AudioError.transcriptionFailed(error)
        }
    }
    
    /// Process a query with audio files (convenience method)
    public func processQuery(
        text: String,
        audioFiles: [URL],
        displayNames: [String?] = [],
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        language: String? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let query = AudioQuery(
            text: text,
            audioFiles: audioFiles,
            displayNames: displayNames,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings,
            language: language
        )
        
        return try await processQuery(query)
    }
    
    // MARK: - Convenience Methods
    
    /// Simple transcription - just transcribe audio without additional query
    public func transcribeAudio(
        _ audioFile: URL,
        displayName: String? = nil,
        language: String? = nil,
        systemInstruction: String? = nil
    ) async throws -> String {
        let response = try await processQuery(
            text: language != nil ? "Transcribe this audio to text. Language: \(language!)" : "Transcribe this audio to text.",
            audioFiles: [audioFile],
            displayNames: [displayName],
            systemInstruction: systemInstruction
        )
        
        return response.candidates.first?.content.parts.first?.text ?? ""
    }
    
    /// Transcribe multiple audio files
    public func transcribeMultipleAudios(
        _ audioFiles: [URL],
        displayNames: [String?] = [],
        language: String? = nil,
        systemInstruction: String? = nil
    ) async throws -> [(String, String)] {
        let session = createSession()
        defer { endSession(session) }
        
        var results: [(String, String)] = []
        
        for (index, audioFile) in audioFiles.enumerated() {
            let displayName = displayNames.indices.contains(index) ? displayNames[index] : 
                              audioFile.lastPathComponent
            
            do {
                let transcription = try await transcribeAudio(
                    audioFile,
                    displayName: displayName,
                    language: language,
                    systemInstruction: systemInstruction
                )
                results.append(((displayName ?? audioFile.lastPathComponent), transcription))
            } catch {
                results.append(((displayName ?? audioFile.lastPathComponent), "Error: \(error.localizedDescription)"))
            }
        }
        
        return results
    }
    
    /// Transcribe and ask questions about the audio
    public func transcribeAndAnalyze(
        _ audioFile: URL,
        displayName: String? = nil,
        query: String,
        language: String? = nil,
        systemInstruction: String? = nil
    ) async throws -> String {
        let response = try await processQuery(
            text: "First, transcribe this audio in \(language ?? "the original language"). Then, answer this question: \(query)",
            audioFiles: [audioFile],
            displayNames: [displayName],
            systemInstruction: systemInstruction
        )
        
        return response.candidates.first?.content.parts.first?.text ?? ""
    }
    
    /// Compare two audio files
    public func compareAudios(
        _ audio1: URL,
        _ audio2: URL,
        displayName1: String? = nil,
        displayName2: String? = nil,
        comparisonPrompt: String = "Compare these two audio recordings and highlight the key differences.",
        language: String? = nil
    ) async throws -> String {
        let response = try await processQuery(
            text: "Transcribe both audio recordings in \(language ?? "their original language") and \(comparisonPrompt)",
            audioFiles: [audio1, audio2],
            displayNames: [displayName1, displayName2]
        )
        
        return response.candidates.first?.content.parts.first?.text ?? ""
    }
}