//
//  SimpleAudioTranscriptionTests.swift
//  gemini-swfitTests
//
//  Created by Claude on 2025-01-11.
//

import XCTest
@testable import gemini_swfit

final class SimpleAudioTranscriptionTests: BaseGeminiTestSuite {
    
    // MARK: - Properties
    
    /// Simple audio manager instance
    var audioManager: GeminiAudioConversationManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Initialize audio manager if we have a client
        if let client = client {
            audioManager = GeminiAudioConversationManager(client: client)
        }
        
        print("✅ [SETUP] Simple audio manager initialized")
    }
    
    override func tearDown() {
        audioManager = nil
        super.tearDown()
    }
    
    // MARK: - Simple Transcription Tests
    
    func testSimpleTranscription() async throws {
        try skipIfNoAPIKey()
        
        let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testSimpleTranscription")
        
        let transcription = try await measureAndLog(operationName: "Simple transcription") {
            try await audioManager!.transcribeAudio(
                testAudioURL,
                displayName: "Test Audio",
                language: "zh"
            )
        }
        
        print("📝 [RESULT] Transcription length: \(transcription.count) characters")
        print("   Content: '\(transcription.prefix(100))\(transcription.count > 100 ? "..." : "")'")
        
        XCTAssertFalse(transcription.isEmpty, "Transcription should not be empty")
        XCTAssertGreaterThan(transcription.count, 10, "Transcription should have meaningful content")
        XCTAssertTrue(transcription.contains("胃") || transcription.contains("疼"), "Transcription should contain relevant keywords")
        
        print("✅ [TEST] testSimpleTranscription passed")
    }
    
    func testTranscriptionWithCustomInstruction() async throws {
        try skipIfNoAPIKey()
        
        let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testTranscriptionWithCustomInstruction")
        
        let systemInstruction = "你是一个医疗记录专家。请准确转录医疗对话，并保持专业术语。"
        
        let transcription = try await measureAndLog(operationName: "Medical transcription") {
            try await audioManager!.transcribeAudio(
                testAudioURL,
                displayName: "Medical Consultation",
                language: "zh",
                systemInstruction: systemInstruction
            )
        }
        
        print("📝 [RESULT] Medical transcription length: \(transcription.count) characters")
        print("   Content: '\(transcription.prefix(100))\(transcription.count > 100 ? "..." : "")'")
        
        XCTAssertFalse(transcription.isEmpty, "Transcription should not be empty")
        
        print("✅ [TEST] testTranscriptionWithCustomInstruction passed")
    }
    
    func testTranscribeAndAnalyze() async throws {
        try skipIfNoAPIKey()
        
        let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testTranscribeAndAnalyze")
        
        let question = "这位病人有什么症状？医生建议了什么检查？"
        
        let analysis = try await measureAndLog(operationName: "Transcription and analysis") {
            try await audioManager!.transcribeAndAnalyze(
                testAudioURL,
                displayName: "Patient Recording",
                query: question,
                language: "zh"
            )
        }
        
        print("📝 [RESULT] Analysis length: \(analysis.count) characters")
        print("   Content: '\(analysis.prefix(200))\(analysis.count > 200 ? "..." : "")'")
        
        XCTAssertFalse(analysis.isEmpty, "Analysis should not be empty")
        XCTAssertGreaterThan(analysis.count, 20, "Analysis should have meaningful content")
        
        print("✅ [TEST] testTranscribeAndAnalyze passed")
    }
    
    func testBatchTranscription() async throws {
        try skipIfNoAPIKey()
        
        let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testBatchTranscription")
        
        // Create multiple entries of the same file for testing
        let audioFiles = Array(repeating: testAudioURL, count: 2)
        let displayNames = ["Recording 1", "Recording 2"]
        
        let results = try await measureAndLog(operationName: "Batch transcription") {
            try await audioManager!.transcribeMultipleAudios(
                audioFiles,
                displayNames: displayNames,
                language: "zh"
            )
        }
        
        XCTAssertEqual(results.count, 2, "Should have results for all audio files")
        
        for (index, (fileName, transcription)) in results.enumerated() {
            print("   Result \(index + 1): \(fileName) - \(transcription.count) characters")
            if !transcription.isEmpty {
                XCTAssertGreaterThan(transcription.count, 10, "Transcription should have meaningful content")
            }
        }
        
        print("✅ [TEST] testBatchTranscription passed")
    }
    
    func testAudioComparison() async throws {
        try skipIfNoAPIKey()
        
        let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testAudioComparison")
        
        // Compare audio with itself for testing
        let comparison = try await measureAndLog(operationName: "Audio comparison") {
            try await audioManager!.compareAudios(
                testAudioURL,
                testAudioURL,
                displayName1: "Version A",
                displayName2: "Version B",
                comparisonPrompt: "分析这两个录音的内容。",
                language: "zh"
            )
        }
        
        print("📝 [RESULT] Comparison length: \(comparison.count) characters")
        print("   Content: '\(comparison.prefix(200))\(comparison.count > 200 ? "..." : "")'")
        
        XCTAssertFalse(comparison.isEmpty, "Comparison should not be empty")
        XCTAssertGreaterThan(comparison.count, 20, "Comparison should have meaningful content")
        
        print("✅ [TEST] testAudioComparison passed")
    }
    
    func testSessionBasedConversation() async throws {
        try skipIfNoAPIKey()
        
        let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testSessionBasedConversation")
        
        let session = audioManager!.createSession()
        defer { audioManager!.endSession(session) }
        
        // Upload audio once
        let uploadedFiles = try await audioManager!.uploadAudios(
            to: session,
            audioFiles: [testAudioURL],
            displayNames: ["Consultation Recording"]
        )
        
        XCTAssertEqual(uploadedFiles.count, 1, "Should have uploaded one audio file")
        
        // Multiple queries
        let queries = [
            "What symptoms are mentioned?",
            "What tests are recommended?"
        ]
        
        var responses: [String] = []
        
        for query in queries {
            let audioQuery = GeminiAudioConversationManager.AudioQuery(
                text: query,
                audioFiles: [], // Use uploaded audio
                systemInstruction: "You are a medical assistant. Answer based on the transcribed audio."
            )
            
            let response = try await audioManager!.processQuery(
                audioQuery,
                in: session
            )
            
            let text = response.candidates.first?.content.parts.first?.text ?? ""
            responses.append(text)
            XCTAssertFalse(text.isEmpty, "Response should not be empty")
        }
        
        XCTAssertEqual(responses.count, 2, "Should have responses for all queries")
        
        print("✅ [TEST] testSessionBasedConversation passed")
    }
    
    func testErrorHandling() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testErrorHandling")
        
        // Test with non-existent file
        let invalidURL = URL(fileURLWithPath: "/non/existent/audio.mp3")
        
        do {
            _ = try await audioManager!.transcribeAudio(invalidURL)
            XCTFail("Should have thrown an error")
        } catch let error as GeminiAudioConversationManager.AudioError {
            if case .invalidAudioFile = error {
                print("✅ Correctly caught invalid audio file error")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
        
        print("✅ [TEST] testErrorHandling passed")
    }
}