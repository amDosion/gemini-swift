import XCTest
@testable import gemini_swfit

final class AudioTranscriptionTests: BaseGeminiTestSuite {
    
    // MARK: - Properties
    
    /// Test audio file URL
    let testAudioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
    
    /// Audio uploader instance
    var audioUploader: GeminiAudioUploader!
    
    /// Enhanced audio manager
    var audioManager: GeminiAudioManagerEnhanced!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Initialize audio components
        audioUploader = GeminiAudioUploader()
        
        if let apiKey = apiKey {
            audioManager = GeminiAudioManagerEnhanced(apiKeys: [apiKey])
        }
        
        print("✅ [SETUP] Audio components initialized")
    }
    
    override func tearDown() {
        audioUploader = nil
        audioManager = nil
        super.tearDown()
    }
    
    // MARK: - Basic Audio Transcription Tests
    
    func testAudioTranscriptionWithAPIKey() async throws {
        try skipIfNoAPIKey()
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testAudioTranscriptionWithAPIKey")
        
        // First upload the audio file
        logAudioUploadRequest(
            fileName: testAudioURL.lastPathComponent,
            fileSize: getFileSize(at: testAudioURL)
        )
        
        let session = audioUploader.startSession(apiKey: apiKey!)
        let uploadedFile = try await measureAndLog(operationName: "Audio upload") {
            try await audioUploader.uploadAudio(
                at: testAudioURL,
                displayName: "Transcription Test Audio",
                session: session
            )
        }
        
        logAudioUploadResponse(uploadedFile)
        
        // Then transcribe it
        logAudioTranscriptionRequest(
            model: .gemini25Flash,
            audioFileURI: uploadedFile.uri,
            language: "zh"
        )
        
        let transcription = try await measureAndLog(operationName: "Audio transcription") {
            try await client!.transcribeAudio(
                model: .gemini25Flash,
                audioFileURI: uploadedFile.uri,
                mimeType: uploadedFile.mimeType!,
                language: "zh"
            )
        }
        
        logAudioTranscriptionResponse(transcription)
        
        validateBasicResponse(transcription)
        XCTAssertGreaterThan(transcription.count, 10, "Transcription should have meaningful content")
        print("✅ [TEST] testAudioTranscriptionWithAPIKey passed")
    }
    
    func testAudioTranscriptionWithSystemInstruction() async throws {
        try skipIfNoAPIKey()
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testAudioTranscriptionWithSystemInstruction")
        
        let systemInstruction = "你是一个医疗记录员。请准确转录音频内容，并保持原始的医疗术语。"
        
        // Upload audio
        let session = audioUploader.startSession(apiKey: apiKey!)
        let uploadedFile = try await audioUploader.uploadAudio(
            at: testAudioURL,
            displayName: "Medical Transcription Test",
            session: session
        )
        
        logAudioTranscriptionRequest(
            model: .gemini25Flash,
            audioFileURI: uploadedFile.uri,
            language: "zh",
            systemInstruction: systemInstruction
        )
        
        let transcription = try await measureAndLog(operationName: "Medical transcription test") {
            try await client!.transcribeAudio(
                model: .gemini25Flash,
                audioFileURI: uploadedFile.uri,
                mimeType: uploadedFile.mimeType!,
                language: "zh",
                systemInstruction: systemInstruction
            )
        }
        
        logAudioTranscriptionResponse(transcription, prefix: "📥 [MEDICAL TRANSCRIPTION]")
        
        validateBasicResponse(transcription)
        // Check for medical terms
        let medicalTerms = ["胃", "胃炎", "B超", "检查", "腹部"]
        let containsMedicalTerm = medicalTerms.contains { term in
            transcription.contains(term)
        }
        XCTAssertTrue(containsMedicalTerm, "Transcription should contain medical terms")
        print("✅ [TEST] testAudioTranscriptionWithSystemInstruction passed")
    }
    
    func testAudioTranscriptionWithDifferentLanguages() async throws {
        try skipIfNoAPIKey()
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testAudioTranscriptionWithDifferentLanguages")
        
        // Upload audio once
        let session = audioUploader.startSession(apiKey: apiKey!)
        let uploadedFile = try await audioUploader.uploadAudio(
            at: testAudioURL,
            displayName: "Multi-language Test",
            session: session
        )
        
        // Test with Chinese language specification
        logAudioTranscriptionRequest(
            model: .gemini25Flash,
            audioFileURI: uploadedFile.uri,
            language: "zh"
        )
        
        let zhTranscription = try await client!.transcribeAudio(
            model: .gemini25Flash,
            audioFileURI: uploadedFile.uri,
            mimeType: uploadedFile.mimeType!,
            language: "zh"
        )
        
        logAudioTranscriptionResponse(zhTranscription, prefix: "📥 [CHINESE TRANSCRIPTION]")
        
        // Test without language specification (auto-detect)
        logAudioTranscriptionRequest(
            model: .gemini25Flash,
            audioFileURI: uploadedFile.uri,
            language: nil
        )
        
        let autoTranscription = try await client!.transcribeAudio(
            model: .gemini25Flash,
            audioFileURI: uploadedFile.uri,
            mimeType: uploadedFile.mimeType!
        )
        
        logAudioTranscriptionResponse(autoTranscription, prefix: "📥 [AUTO-DETECT TRANSCRIPTION]")
        
        validateBasicResponse(zhTranscription)
        validateBasicResponse(autoTranscription)
        
        // Both should detect Chinese content
        XCTAssertTrue(zhTranscription.contains("胃") || zhTranscription.contains("疼"), 
                      "Chinese transcription should contain relevant keywords")
        XCTAssertTrue(autoTranscription.contains("胃") || autoTranscription.contains("疼"), 
                      "Auto-detect transcription should contain relevant keywords")
        
        print("✅ [TEST] testAudioTranscriptionWithDifferentLanguages passed")
    }
    
    func testAudioTranscriptionWithGenerationConfig() async throws {
        try skipIfNoAPIKey()
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testAudioTranscriptionWithGenerationConfig")
        
        let config = GenerationConfig(
            maxOutputTokens: 100,
            temperature: 0.1
        )
        
        // Upload audio
        let session = audioUploader.startSession(apiKey: apiKey!)
        let uploadedFile = try await audioUploader.uploadAudio(
            at: testAudioURL,
            displayName: "Config Test",
            session: session
        )
        
        let request = GeminiGenerateContentRequest(
            contents: [
                Content(parts: [
                    Part(text: "请转录以下音频："),
                    Part(fileData: FileData(
                        mimeType: uploadedFile.mimeType!,
                        fileUri: uploadedFile.uri
                    ))
                ])
            ],
            generationConfig: config
        )
        
        print("\n📤 [REQUEST] Sending audio transcription with custom config")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        print("   Max Output Tokens: \(config.maxOutputTokens ?? 0)")
        print("   Temperature: \(config.temperature ?? 0.0)")
        print("   Audio file: \(uploadedFile.name)")
        
        let response = try await measureAndLog(operationName: "Configured transcription test") {
            try await client!.generateContent(model: .gemini25Flash, request: request)
        }
        
        print("📥 [RESPONSE] Number of candidates: \(response.candidates.count)")
        
        XCTAssertFalse(response.candidates.isEmpty, "Response should have candidates")
        
        if let candidate = response.candidates.first {
            XCTAssertFalse(candidate.content.parts.isEmpty, "Candidate should have content parts")
            let responseText = candidate.content.parts.first?.text ?? ""
            print("   Response text length: \(responseText.count) characters")
            print("   Content: '\(responseText.prefix(100))\(responseText.count > 100 ? "..." : "")'")
            XCTAssertLessThan(responseText.count, 200, "Response should be limited by maxOutputTokens")
        }
        
        print("✅ [TEST] testAudioTranscriptionWithGenerationConfig passed")
    }
    
    func testBatchAudioTranscription() async throws {
        try skipIfNoAPIKey()
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testBatchAudioTranscription")
        
        // Upload audio file once, then create multiple transcription requests
        let session = audioUploader.startSession(apiKey: apiKey!)
        let uploadedFile = try await measureAndLog(operationName: "Audio upload for batch test") {
            try await audioUploader.uploadAudio(
                at: testAudioURL,
                displayName: "Batch Test Audio",
                session: session
            )
        }
        
        print("✅ Audio uploaded successfully: \(uploadedFile.name)")
        
        // Test batch transcription with different system instructions
        let batchRequests = [
            ("Medical Transcription", "你是一个医疗记录员。请准确转录音频内容。"),
            ("Summary Transcription", "请转录音频并提供简要总结。"),
            ("Detailed Transcription", "请详细转录音频内容，包括所有细节。")
        ]
        
        logBatchTranscriptionRequest(
            audioFiles: [testAudioURL],
            displayNames: batchRequests.map { $0.0 },
            maxConcurrent: 2
        )
        
        var results: [(String, String)] = []
        var successfulCount = 0
        
        // Process requests with controlled concurrency
        for (index, (displayName, systemInstruction)) in batchRequests.enumerated() {
            print("\n📤 [REQUEST] Processing batch request \(index + 1)/\(batchRequests.count): \(displayName)")
            
            do {
                let transcription = try await measureAndLog(operationName: "Batch transcription \(index + 1)") {
                    try await client!.transcribeAudio(
                        model: .gemini25Flash,
                        audioFileURI: uploadedFile.uri,
                        mimeType: uploadedFile.mimeType!,
                        language: "zh",
                        systemInstruction: systemInstruction
                    )
                }
                
                results.append((displayName, transcription))
                successfulCount += 1
                
                print("✅ [SUCCESS] Batch request \(index + 1) completed: \(transcription.count) characters")
                
            } catch {
                print("❌ [ERROR] Batch request \(index + 1) failed: \(error)")
                results.append((displayName, ""))
                
                // For testing purposes, we'll allow some failures
                if error.localizedDescription.contains("quota") || 
                   error.localizedDescription.contains("rate") || 
                   error.localizedDescription.contains("429") {
                    print("⚠️ Rate limited - this is acceptable for batch testing")
                }
            }
            
            // Small delay between requests to avoid rate limiting
            if index < batchRequests.count - 1 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        logBatchTranscriptionResponse(results)
        
        // Verify we got some successful results
        XCTAssertGreaterThan(successfulCount, 0, "Should have at least one successful transcription")
        XCTAssertEqual(results.count, batchRequests.count, "Should have results for all requests")
        
        print("✅ [TEST] testBatchAudioTranscription passed with \(successfulCount)/\(batchRequests.count) successful")
    }
    
    func testAudioTranscriptionErrorHandling() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testAudioTranscriptionErrorHandling")
        
        // Test with invalid file URI
        let invalidFileURI = "https://invalid-uri.com/audio.mp3"
        
        print("\n📤 [REQUEST] Testing error handling with invalid file URI")
        print("   Invalid URI: '\(invalidFileURI)'")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        
        do {
            _ = try await client!.transcribeAudio(
                model: .gemini25Flash,
                audioFileURI: invalidFileURI,
                mimeType: "audio/mpeg",
                language: "zh"
            )
            XCTFail("Should have thrown an error")
        } catch let error as GeminiClient.GeminiError {
            validateError(error)
        } catch {
            print("❌ [ERROR] Unexpected error type: \(type(of: error)) - \(error)")
            XCTFail("Unexpected error type: \(error)")
        }
        
        print("✅ [TEST] testAudioTranscriptionErrorHandling passed")
    }
    
    func testAudioTranscriptionWithSafetySettings() async throws {
        try skipIfNoAPIKey()
        guard FileManager.default.fileExists(atPath: testAudioURL.path) else {
            throw XCTSkip("Test audio file not found")
        }
        
        print("\n🧪 [TEST] Starting testAudioTranscriptionWithSafetySettings")
        
        let safetySettings: [SafetySetting] = [
            SafetySetting(category: .dangerousContent, threshold: .blockNone)
        ]
        
        // Upload audio
        let session = audioUploader.startSession(apiKey: apiKey!)
        let uploadedFile = try await audioUploader.uploadAudio(
            at: testAudioURL,
            displayName: "Safety Settings Test",
            session: session
        )
        
        let request = GeminiGenerateContentRequest(
            contents: [
                Content(parts: [
                    Part(text: "转录并总结这段音频内容："),
                    Part(fileData: FileData(
                        mimeType: uploadedFile.mimeType!,
                        fileUri: uploadedFile.uri
                    ))
                ])
            ],
            safetySettings: safetySettings
        )
        
        print("\n📤 [REQUEST] Sending audio transcription with safety settings")
        print("   Model: \(GeminiClient.Model.gemini25Flash.displayName)")
        print("   Safety Settings: \(safetySettings.count) settings")
        print("   Category: \(safetySettings.first?.category.rawValue ?? "N/A")")
        print("   Threshold: \(safetySettings.first?.threshold.rawValue ?? "N/A")")
        
        let response = try await measureAndLog(operationName: "Safety settings transcription test") {
            try await client!.generateContent(model: .gemini25Flash, request: request)
        }
        
        print("📥 [RESPONSE] Number of candidates: \(response.candidates.count)")
        
        XCTAssertFalse(response.candidates.isEmpty, "Response should have candidates")
        
        if let candidate = response.candidates.first {
            let responseText = candidate.content.parts.first?.text ?? ""
            print("   Response length: \(responseText.count) characters")
            print("   Content preview: '\(responseText.prefix(100))\(responseText.count > 100 ? "..." : "")'")
        }
        
        print("✅ [TEST] testAudioTranscriptionWithSafetySettings passed")
    }
    
    // MARK: - Helper Methods
    
    /// Get file size in bytes
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resources.fileSize ?? 0)
        } catch {
            return 0
        }
    }
    
    /// Log audio upload request details
    private func logAudioUploadRequest(
        fileName: String,
        fileSize: Int64
    ) {
        print("\n📤 [REQUEST] Uploading audio file")
        print("   File name: \(fileName)")
        print("   File size: \(fileSize) bytes (\(Double(fileSize) / 1024) KB)")
    }
    
    /// Log audio upload response details
    private func logAudioUploadResponse(_ fileInfo: GeminiAudioUploader.UploadResponse.FileInfo) {
        print("📥 [UPLOAD RESPONSE] Upload successful")
        print("   File name: \(fileInfo.name)")
        print("   Display name: \(fileInfo.displayName ?? "N/A")")
        print("   MIME type: \(fileInfo.mimeType ?? "N/A")")
        print("   File URI: \(fileInfo.uri)")
        print("   Size: \(fileInfo.size ?? "N/A")")
    }
    
    /// Log audio transcription request details
    private func logAudioTranscriptionRequest(
        model: GeminiClient.Model,
        audioFileURI: String,
        language: String?,
        systemInstruction: String? = nil
    ) {
        print("\n📤 [REQUEST] Sending audio transcription request")
        print("   Model: \(model.displayName)")
        print("   Audio File URI: \(audioFileURI)")
        if let lang = language {
            print("   Language: \(lang)")
        }
        if let instruction = systemInstruction {
            print("   System Instruction: '\(instruction)'")
        }
    }
    
    /// Log audio transcription response details
    private func logAudioTranscriptionResponse(_ transcription: String, prefix: String = "📥 [TRANSCRIPTION]") {
        print("\(prefix) Response length: \(transcription.count) characters")
        print("   Content: '\(transcription.prefix(200))\(transcription.count > 200 ? "..." : "")'")
    }
    
    /// Log batch transcription request details
    private func logBatchTranscriptionRequest(
        audioFiles: [URL],
        displayNames: [String?],
        maxConcurrent: Int
    ) {
        print("\n📤 [REQUEST] Starting batch transcription")
        print("   Number of files: \(audioFiles.count)")
        print("   Max concurrent: \(maxConcurrent)")
        for (index, (file, name)) in zip(audioFiles, displayNames).enumerated() {
            print("   File \(index + 1): \(name ?? file.lastPathComponent)")
        }
    }
    
    /// Log batch transcription response details
    private func logBatchTranscriptionResponse(_ results: [(String, String)]) {
        print("📥 [BATCH RESPONSE] Transcription completed")
        print("   Number of results: \(results.count)")
        for (index, (fileName, transcription)) in results.enumerated() {
            print("   Result \(index + 1): \(fileName) - \(transcription.count) characters")
        }
    }
}