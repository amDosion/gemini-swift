//
//  VideoTestsSuite.swift
//  gemini-swfitTests
//
//  Created by Claude on 2025-01-10.
//

import XCTest
import SwiftyBeaver
@testable import gemini_swfit

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
final class VideoTestsSuite: XCTestCase {
    
    private var client: GeminiClient!
    private var videoManager: GeminiVideoManager!
    private var uploader: GeminiVideoUploader!
    
    override func setUp() async throws {
        // Setup logging
        let logger = SwiftyBeaver.self
        let console = ConsoleDestination()
        logger.addDestination(console)
        
        // Get API key from environment
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            throw XCTSkip("GEMINI_API_KEY environment variable not set")
        }
        
        // Initialize clients
        client = GeminiClient(apiKey: apiKey)
        videoManager = GeminiVideoManager(client: client)
        uploader = GeminiVideoUploader(baseURL: client.baseURL.absoluteString)
    }
    
    override func tearDown() async throws {
        // Cleanup
    }
    
    // MARK: - Video Upload Tests
    
    func testVideoMetadataExtraction() async throws {
        // Get test video file from bundle
        let videoURL = try getTestVideoFile()
        
        // Extract metadata
        let metadata = try uploader.getVideoMetadata(videoURL)
        
        XCTAssertEqual(metadata.mimeType, "video/mp4")
        XCTAssertEqual(metadata.displayName, "oceans.mp4")
        XCTAssertGreaterThan(metadata.size, 0)
        print("Video size: \(metadata.size) bytes")
    }
    
    func testVideoFormatSupport() async throws {
        let supportedFormats = uploader.supportedFormats
        XCTAssertFalse(supportedFormats.isEmpty)
        
        // Test format detection
        XCTAssertTrue(uploader.isFormatSupported(URL(fileURLWithPath: "test.mp4")))
        XCTAssertTrue(uploader.isFormatSupported(URL(fileURLWithPath: "test.mov")))
        XCTAssertFalse(uploader.isFormatSupported(URL(fileURLWithPath: "test.xyz")))
    }
    
    func testVideoSessionManagement() async throws {
        let session = uploader.startSession(apiKey: "test_api_key")
        XCTAssertEqual(session.uploadedFiles.count, 0)
        
        // Test session retrieval
        let retrievedSession = uploader.getSession(sessionID: session.sessionID)
        XCTAssertNotNil(retrievedSession)
        XCTAssertEqual(retrievedSession?.sessionID, session.sessionID)
        
        // End session
        uploader.endSession(session)
        let endedSession = uploader.getSession(sessionID: session.sessionID)
        XCTAssertNil(endedSession)
    }
    
    func testVideoUploadWithRealFile() async throws {
        // Skip test if no API key (already handled in setUp)
        
        // Get test video file
        let videoURL = try getTestVideoFile()
        
        // Start upload session
        let session = uploader.startSession(apiKey: client.getNextApiKey())
        defer { uploader.endSession(session) }
        
        // Test upload
        let fileInfo = try await uploader.uploadVideo(
            at: videoURL,
            displayName: "Oceans Test Video",
            session: session
        )
        
        // Verify upload response
        XCTAssertFalse(fileInfo.name.isEmpty)
        XCTAssertNotNil(fileInfo.uri)
        XCTAssertEqual(fileInfo.mimeType, "video/mp4")
        XCTAssertEqual(fileInfo.displayName, "Oceans Test Video")
        
        print("Uploaded file URI: \(fileInfo.uri ?? "N/A")")
    }
    
    // MARK: - Video Analysis Tests
    
    func testVideoAnalysisWithUploadedFile() async throws {
        // Upload video file first
        let videoURL = try getTestVideoFile()
        let session = uploader.startSession(apiKey: client.getNextApiKey())
        defer { uploader.endSession(session) }
        
        let fileInfo = try await uploader.uploadVideo(
            at: videoURL,
            displayName: "Oceans Analysis Test",
            session: session
        )
        
        guard let uri = fileInfo.uri else {
            XCTFail("No URI returned from upload")
            return
        }
        
        // Test analysis
        let analysis = try await client.analyzeVideo(
            model: .gemini25Flash,
            videoFileURI: uri,
            mimeType: fileInfo.mimeType!,
            prompt: "Describe this ocean video. What marine life and scenes do you see?"
        )
        
        XCTAssertFalse(analysis.isEmpty)
        print("Analysis completed successfully")
    }
    
    func testVideoTranscriptionWithUploadedFile() async throws {
        // Upload video file first
        let videoURL = try getTestVideoFile()
        let session = uploader.startSession(apiKey: client.getNextApiKey())
        defer { uploader.endSession(session) }
        
        let fileInfo = try await uploader.uploadVideo(
            at: videoURL,
            displayName: "Oceans Transcription Test",
            session: session
        )
        
        guard let uri = fileInfo.uri else {
            XCTFail("No URI returned from upload")
            return
        }
        
        // Test transcription
        let transcription = try await client.transcribeVideo(
            model: .gemini25Flash,
            videoFileURI: uri,
            mimeType: fileInfo.mimeType!,
            language: "en"
        )
        
        XCTAssertFalse(transcription.isEmpty)
        print("Transcription completed successfully")
    }
    
    func testVideoSummaryWithUploadedFile() async throws {
        // Upload video file first
        let videoURL = try getTestVideoFile()
        let session = uploader.startSession(apiKey: client.getNextApiKey())
        defer { uploader.endSession(session) }
        
        let fileInfo = try await uploader.uploadVideo(
            at: videoURL,
            displayName: "Oceans Summary Test",
            session: session
        )
        
        guard let uri = fileInfo.uri else {
            XCTFail("No URI returned from upload")
            return
        }
        
        // Test summarization
        let summary = try await client.summarizeVideo(
            model: .gemini25Flash,
            videoFileURI: uri,
            mimeType: fileInfo.mimeType!,
            maxLength: 100
        )
        
        XCTAssertFalse(summary.isEmpty)
        print("Summary completed successfully")
    }
    
    func testVideoQuizGenerationWithUploadedFile() async throws {
        // Upload video file first
        let videoURL = try getTestVideoFile()
        let session = uploader.startSession(apiKey: client.getNextApiKey())
        defer { uploader.endSession(session) }
        
        let fileInfo = try await uploader.uploadVideo(
            at: videoURL,
            displayName: "Oceans Quiz Test",
            session: session
        )
        
        guard let uri = fileInfo.uri else {
            XCTFail("No URI returned from upload")
            return
        }
        
        // Test quiz generation
        let quiz = try await client.generateVideoQuiz(
            model: .gemini25Flash,
            videoFileURI: uri,
            mimeType: fileInfo.mimeType!,
            questionCount: 3
        )
        
        XCTAssertFalse(quiz.isEmpty)
        XCTAssertTrue(quiz.contains("Answer Key"))
        print("Quiz generation completed successfully")
    }
    
    func testVideoManagerWithRealFile() async throws {
        // Test video manager with real file
        let videoURL = try getTestVideoFile()
        
        // Test analysis
        let analysis = try await videoManager.analyze(
            videoFileURL: videoURL,
            prompt: "What do you see in this ocean video?"
        )
        
        XCTAssertFalse(analysis.isEmpty)
        print("Video manager analysis completed successfully")
    }
    
    // MARK: - YouTube Video Tests
    
    func testYouTubeVideoAnalysis() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // Test YouTube video analysis
        let analysis = try await client.analyzeYouTubeVideo(
            model: .gemini25Flash,
            videoURL: youtubeURL,
            prompt: "What is this video about?"
        )
        
        XCTAssertFalse(analysis.isEmpty)
        print("YouTube video analysis completed successfully")
    }
    
    func testYouTubeVideoSummarization() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // Test YouTube video summarization
        let summary = try await client.summarizeYouTubeVideo(
            model: .gemini25Flash,
            videoURL: youtubeURL,
            maxLength: 50
        )
        
        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(summary.count < 500) // Rough check for length
        print("YouTube video summarization completed successfully")
    }
    
    func testYouTubeVideoTranscription() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // Test YouTube video transcription
        let transcription = try await client.transcribeYouTubeVideo(
            model: .gemini25Flash,
            videoURL: youtubeURL,
            language: "en"
        )
        
        XCTAssertFalse(transcription.isEmpty)
        print("YouTube video transcription completed successfully")
    }
    
    func testYouTubeVideoQuizGeneration() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // Test YouTube video quiz generation
        let quiz = try await client.generateYouTubeVideoQuiz(
            model: .gemini25Flash,
            videoURL: youtubeURL,
            questionCount: 3
        )
        
        XCTAssertFalse(quiz.isEmpty)
        XCTAssertTrue(quiz.contains("Answer"))
        print("YouTube video quiz generation completed successfully")
    }
    
    func testYouTubeVideoKeyMoments() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // Test YouTube video key moments extraction
        let keyMoments = try await client.extractYouTubeVideoKeyMoments(
            model: .gemini25Flash,
            videoURL: youtubeURL,
            momentCount: 3
        )
        
        XCTAssertFalse(keyMoments.isEmpty)
        print("YouTube video key moments extraction completed successfully")
    }
    
    func testYouTubeVideoManagerMethods() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // Test YouTube video manager methods
        let summary = try await videoManager.summarizeYouTubeVideo(
            videoURL: youtubeURL,
            maxLength: 30
        )
        
        XCTAssertFalse(summary.isEmpty)
        print("YouTube video manager summarization completed successfully")
    }
    
    // MARK: - Video Manager Tests
    
    func testVideoManagerMethodsExist() async throws {
        // Test that all video manager methods exist and are callable
        let videoURL = URL(fileURLWithPath: "test.mp4")
        
        _ = videoManager.isFormatSupported(videoURL)
        let formats = videoManager.supportedFormats
        XCTAssertFalse(formats.isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func getTestVideoFile() throws -> URL {
        // Try to get from test bundle first
        let bundle = Bundle(for: type(of: self))
        
        // Check multiple possible resource locations
        let possiblePaths: [String?] = [
            bundle.path(forResource: "oceans", ofType: "mp4"),
            bundle.path(forResource: "oceans", ofType: "mp4", inDirectory: "Resources"),
            URL(fileURLWithPath: bundle.bundlePath).appendingPathComponent("Contents/Resources/oceans.mp4").path
        ]
        
        for path in possiblePaths {
            if let path = path, FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        // If not found in bundle, try the test resources directory
        let currentDir = FileManager.default.currentDirectoryPath
        let fallbackPaths = [
            "\(currentDir)/Tests/Resources/oceans.mp4",
            "\(currentDir)/Tests/Resources/oceans.mp4"
        ]
        
        for path in fallbackPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        throw XCTSkip("oceans.mp4 not found in test bundle or resources")
    }
}