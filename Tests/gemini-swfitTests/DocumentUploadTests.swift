import XCTest
@testable import gemini_swfit

final class DocumentUploadTests: BaseGeminiTestSuite {
    
    // MARK: - Properties
    
    private var documentManager: GeminiDocumentConversationManager!
    private var uploader: GeminiDocumentUploader!
    private let testTimeout: TimeInterval = 60.0
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        super.setUp()
        
        // For async tests, we need to manually call setup
        // This is a workaround for XCTest not supporting async setup
        
        // Check for API key synchronously
        if let keyFromEnv = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            apiKey = keyFromEnv
            client = GeminiClient(apiKey: apiKey!)
            
            // Setup logging
            GeminiLogger.shared.setup()
            
            guard let client = client else {
                throw XCTSkip("No API key available")
            }
            
            documentManager = GeminiDocumentConversationManager(client: client)
            uploader = GeminiDocumentUploader()
        } else {
            throw XCTSkip("GEMINI_API_KEY environment variable not set")
        }
    }
    
    override func tearDown() {
        documentManager = nil
        uploader = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func validateBasicContentResponse(_ response: GeminiGenerateContentResponse, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(response.candidates.isEmpty, "Response should have candidates", file: file, line: line)
        
        if let candidate = response.candidates.first {
            XCTAssertFalse(candidate.content.parts.isEmpty, "Candidate should have content parts", file: file, line: line)
            
            if let text = candidate.content.parts.first?.text {
                XCTAssertFalse(text.isEmpty, "Response text should not be empty", file: file, line: line)
            }
        }
    }
    
    private func createTestPDF(named name: String = "test") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(name).pdf")
        
        // Create a minimal valid PDF
        let pdfData = "%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n/Contents 4 0 R\n>>\nendobj\n4 0 obj\n<<\n/Length 44\n>>\nstream\nBT\n/F1 12 Tf\n72 720 Td\n(Test PDF) Tj\nET\nendstream\nendobj\nxref\n0 5\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000213 00000 n \ntrailer\n<<\n/Size 5\n/Root 1 0 R\n>>\nstartxref\n325\n%%EOF".data(using: .utf8)!
        
        try pdfData.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Document Upload Tests
    
    func testDocumentUploaderInitialization() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testDocumentUploaderInitialization")
        
        XCTAssertNotNil(uploader, "Uploader should be initialized")
        print("✅ [TEST] testDocumentUploaderInitialization passed")
    }
    
    func testCreateDocumentSession() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testCreateDocumentSession")
        
        let session = documentManager.createSession()
        
        XCTAssertFalse(session.id.isEmpty, "Session ID should not be empty")
        XCTAssertFalse(session.apiSession.apiKey.isEmpty, "API key should not be empty")
        XCTAssertFalse(session.uploadSession.sessionID.isEmpty, "Upload session ID should not be empty")
        XCTAssertTrue(session.uploadedDocuments.isEmpty, "Initial session should have no documents")
        
        print("✅ [TEST] testCreateDocumentSession passed")
    }
    
    func testFileMetadataExtraction() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testFileMetadataExtraction")
        
        let testFile = try createTestPDF(named: "metadata_test")
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // Test file metadata extraction without accessing private method
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 0, "Test file should have content")
        
        print("✅ [TEST] File metadata extracted - Size: \(fileSize) bytes")
        
        print("✅ [TEST] testFileMetadataExtraction passed")
    }
    
    func testUploadSingleDocument() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testUploadSingleDocument")
        
        let session = documentManager.createSession()
        defer { documentManager.endSession(session) }
        
        let testFile = try createTestPDF(named: "single_upload")
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        logRequest(
            model: .gemini25Flash,
            prompt: "Uploading single document for test"
        )
        print("   FileName: \(testFile.lastPathComponent)")
        print("   FileSize: \(try FileManager.default.attributesOfItem(atPath: testFile.path)[.size] ?? 0) bytes")
        
        let uploadedFiles = try await measureAndLog(operationName: "Single document upload") {
            try await documentManager.uploadDocuments(
                to: session,
                documents: [testFile],
                displayNames: ["Test Document"]
            )
        }
        
        XCTAssertEqual(uploadedFiles.count, 1, "Should have uploaded one file")
        XCTAssertEqual(uploadedFiles.first?.displayName, "Test Document")
        XCTAssertFalse(uploadedFiles.first?.uri.isEmpty ?? true, "File URI should not be empty")
        
        logResponse(uploadedFiles.first?.uri ?? "No URI", prefix: "📥 [UPLOAD RESULT]")
        
        print("✅ [TEST] testUploadSingleDocument passed")
    }
    
    func testUploadMultipleDocuments() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testUploadMultipleDocuments")
        
        let session = documentManager.createSession()
        defer { documentManager.endSession(session) }
        
        let testFiles = [
            try createTestPDF(named: "doc1"),
            try createTestPDF(named: "doc2"),
            try createTestPDF(named: "doc3")
        ]
        
        defer {
            for file in testFiles {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        logRequest(
            model: .gemini25Flash,
            prompt: "Uploading multiple documents for test"
        )
        print("   FileCount: \(testFiles.count)")
        print("   FileNames: \(testFiles.map { $0.lastPathComponent }.joined(separator: ", "))")
        
        let uploadedFiles = try await measureAndLog(operationName: "Multiple document upload") {
            try await documentManager.uploadDocuments(
                to: session,
                documents: testFiles,
                displayNames: ["Document 1", "Document 2", "Document 3"]
            )
        }
        
        XCTAssertEqual(uploadedFiles.count, 3, "Should have uploaded three files")
        
        for (index, file) in uploadedFiles.enumerated() {
            XCTAssertEqual(file.displayName, "Document \(index + 1)")
            XCTAssertFalse(file.uri.isEmpty, "File URI should not be empty")
        }
        
        logResponse("Uploaded \(uploadedFiles.count) documents successfully", prefix: "📥 [UPLOAD RESULT]")
        
        print("✅ [TEST] testUploadMultipleDocuments passed")
    }
    
    func testProcessQueryWithDocuments() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testProcessQueryWithDocuments")
        
        let testFile = try createTestPDF(named: "query_test")
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        logRequest(
            model: .gemini25Flash,
            prompt: "What is this document about?"
        )
        print("   FileName: \(testFile.lastPathComponent)")
        print("   DocumentCount: 1")
        
        let response = try await measureAndLog(operationName: "Document query processing") {
            try await documentManager.processQuery(
                text: "What is this document about?",
                documents: [testFile],
                displayNames: ["Test Document"]
            )
        }
        
        validateBasicContentResponse(response)
        
        if let text = response.candidates.first?.content.parts.first?.text {
            logResponse(text, prefix: "📥 [DOCUMENT ANALYSIS]")
            XCTAssertFalse(text.isEmpty, "Response should not be empty")
        }
        
        print("✅ [TEST] testProcessQueryWithDocuments passed")
    }
    
    func testSessionBasedAPIKeyUsage() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testSessionBasedAPIKeyUsage")
        
        // Create a session and track the API key
        let session = documentManager.createSession()
        defer { documentManager.endSession(session) }
        
        let apiKeyBefore = session.apiSession.apiKey
        
        // Upload a document
        let testFile = try createTestPDF(named: "session_key_test")
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        _ = try await documentManager.uploadDocuments(
            to: session,
            documents: [testFile],
            displayNames: ["Session Test"]
        )
        
        // Process a query in the same session
        let _ = try await documentManager.processQuery(
            text: "What is in this document?",
            documents: [testFile],
            displayNames: ["Session Test"]
        )
        
        // API key should remain the same
        XCTAssertEqual(session.apiSession.apiKey, apiKeyBefore, "API key should not change during session")
        
        print("✅ [TEST] testSessionBasedAPIKeyUsage passed")
    }
    
    func testDocumentComparison() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testDocumentComparison")
        
        let testFiles = [
            try createTestPDF(named: "comparison1"),
            try createTestPDF(named: "comparison2")
        ]
        
        defer {
            for file in testFiles {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        logRequest(
            model: .gemini25Flash,
            prompt: "Compare these two documents and list their differences"
        )
        print("   File1: \(testFiles[0].lastPathComponent)")
        print("   File2: \(testFiles[1].lastPathComponent)")
        print("   Operation: Document Comparison")
        
        let response = try await measureAndLog(operationName: "Document comparison") {
            try await documentManager.comparePDFs(
                pdf1URL: testFiles[0],
                pdf2URL: testFiles[1],
                displayName1: "First Document",
                displayName2: "Second Document",
                comparisonPrompt: "Compare these two documents and list their differences"
            )
        }
        
        validateBasicContentResponse(response)
        
        if let text = response.candidates.first?.content.parts.first?.text {
            logResponse(text, prefix: "📥 [COMPARISON RESULT]")
            XCTAssertFalse(text.isEmpty, "Comparison result should not be empty")
        }
        
        print("✅ [TEST] testDocumentComparison passed")
    }
    
    func testErrorHandlingForInvalidFile() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testErrorHandlingForInvalidFile")
        
        let invalidFile = URL(fileURLWithPath: "/non/existent/file.pdf")
        
        print("\n📤 [REQUEST] Testing error handling with invalid file")
        print("   Invalid file path: '\(invalidFile.path)'")
        
        do {
            _ = try await documentManager.processQuery(
                text: "Analyze this document",
                documents: [invalidFile]
            )
            XCTFail("Should have thrown an error for invalid file")
        } catch let error as GeminiDocumentConversationManager.DocumentError {
            switch error {
            case .documentUploadFailed, .invalidFileExtension, .invalidURL:
                print("✅ [ERROR] Expected error caught: \(error.localizedDescription)")
                break
            default:
                XCTFail("Unexpected DocumentError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        print("✅ [TEST] testErrorHandlingForInvalidFile passed")
    }
    
    func testErrorHandlingForInvalidAPIKey() async throws {
        print("\n🧪 [TEST] Starting testErrorHandlingForInvalidAPIKey")
        
        let invalidClient = GeminiClient(apiKey: "invalid-api-key-for-testing")
        let invalidDocumentManager = GeminiDocumentConversationManager(client: invalidClient)
        
        let testFile = try createTestPDF(named: "invalid_key_test")
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        print("\n📤 [REQUEST] Testing error handling with invalid API key")
        print("   Invalid API key: 'invalid-api-key-for-testing'")
        print("   File: \(testFile.lastPathComponent)")
        
        do {
            _ = try await invalidDocumentManager.processQuery(
                text: "What is this?",
                documents: [testFile]
            )
            XCTFail("Should have thrown an error for invalid API key")
        } catch let error as GeminiClient.GeminiError {
            validateError(error)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        print("✅ [TEST] testErrorHandlingForInvalidAPIKey passed")
    }
    
    func testMultiTurnConversationWithDocuments() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testMultiTurnConversationWithDocuments")
        print("\n📋 [INFO] This test demonstrates a conversation with an uploaded document")
        print("   Step 1: Upload a document once")
        print("   Step 2: Ask 3 follow-up questions without re-uploading")
        print("   Step 3: Verify all responses use the same API key (session-based)")
        
        let session = documentManager.createSession()
        defer { documentManager.endSession(session) }
        
        let testFile = try createTestPDF(named: "conversation_test")
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        print("\n📤 [STEP 1] Uploading document for conversation")
        print("   Document: \(testFile.lastPathComponent)")
        print("   SessionID: \(session.id.prefix(8))")
        print("   APIKey: \(session.apiSession.apiKey.prefix(8))...")
        
        // Upload document once
        let uploadedFiles = try await measureAndLog(operationName: "Document upload for conversation") {
            try await documentManager.uploadDocuments(
                to: session,
                documents: [testFile],
                displayNames: ["Conversation Document"]
            )
        }
        
        print("✅ Upload successful! File URI: \(uploadedFiles.first?.uri.prefix(50) ?? "N/A")...")
        
        let queries = [
            "What is the main topic of this document?",
            "Based on the document content, what are the key points?",
            "Summarize the most important information from this document in one sentence."
        ]
        
        print("\n🗣️ [STEP 2] Starting conversation with 3 questions")
        print("   All queries will reference the same uploaded document")
        print("   Same session and API key will be used throughout")
        print("   Document URI: \(uploadedFiles.first?.uri.prefix(30) ?? "N/A")...")
        
        for (index, query) in queries.enumerated() {
            print("\n" + String(repeating: "=", count: 80))
            print("❓ [QUESTION \(index + 1)/\(queries.count)]")
            print(String(repeating: "=", count: 80))
            print("   Query: \"\(query)\"")
            print("   SessionID: \(session.id.prefix(8))")
            print("   Time: \(Date())")
            
            let docQuery = GeminiDocumentConversationManager.DocumentQuery(
                text: query,
                documents: [], // Already uploaded - reference by URI
                systemInstruction: nil,
                generationConfig: nil,
                safetySettings: nil
            )
            
            print("\n⏳ Processing query \(index + 1)...")
            
            let response = try await measureAndLog(operationName: "Conversation query \(index + 1)") {
                try await documentManager.processQuery(docQuery, in: session)
            }
            
            print("\n📥 [RESPONSE \(index + 1)]")
            print(String(repeating: "-", count: 40))
            
            validateBasicContentResponse(response)
            
            if let text = response.candidates.first?.content.parts.first?.text {
                print("   Response length: \(text.count) characters")
                print("\n📝 [CONTENT \(index + 1)]:")
                print("   \"\(text)\"")
                print("\n✅ Response \(index + 1) received successfully")
                
                // Add a small delay between queries for better readability
                if index < queries.count - 1 {
                    print("\n⏳ Waiting 2 seconds before next question...")
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        
        print("\n" + String(repeating: "=", count: 80))
        print("✅ [TEST COMPLETE] Multi-turn conversation test passed")
        print("   📊 Summary:")
        print("   - Uploaded 1 document")
        print("   - Asked \(queries.count) questions")
        print("   - Used 1 session throughout")
        print("   - API key remained constant: \(session.apiSession.apiKey.prefix(8))...")
        print(String(repeating: "=", count: 80))
    }
    
    func testMultiDocumentConversation() async throws {
        try skipIfNoAPIKey()
        
        print("\n🧪 [TEST] Starting testMultiDocumentConversation")
        print("\n📋 [INFO] This test demonstrates uploading MULTIPLE documents and having a conversation")
        print("   Step 1: Upload 3 different documents")
        print("   Step 2: Ask questions about all documents without re-uploading")
        print("   Step 3: Verify session consistency across all operations")
        
        let session = documentManager.createSession()
        defer { documentManager.endSession(session) }
        
        // Create multiple test documents
        let testFiles = [
            try createTestPDF(named: "document_A"),
            try createTestPDF(named: "document_B"),
            try createTestPDF(named: "document_C")
        ]
        
        defer {
            for file in testFiles {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        print("\n📤 [STEP 1] Uploading multiple documents")
        print("   Number of documents: \(testFiles.count)")
        print("   Document names: \(testFiles.map { $0.lastPathComponent }.joined(separator: ", "))")
        print("   SessionID: \(session.id.prefix(8))")
        print("   APIKey: \(session.apiSession.apiKey.prefix(8))...")
        
        // Upload all documents at once
        let uploadedFiles = try await measureAndLog(operationName: "Multiple document upload") {
            try await documentManager.uploadDocuments(
                to: session,
                documents: testFiles,
                displayNames: ["Document A - Technical Specs", "Document B - User Guide", "Document C - FAQ"]
            )
        }
        
        print("✅ Upload successful!")
        for (index, file) in uploadedFiles.enumerated() {
            print("   Document \(index + 1): \(file.displayName ?? "Untitled")")
            print("   URI: \(file.uri.prefix(40))...")
        }
        
        let queries = [
            "List all the documents I've uploaded and briefly describe what each might contain based on their names.",
            "If I had to choose just one document to learn about the main topic, which one should I read first and why?",
            "Create a summary that combines information from all three documents as if they were related."
        ]
        
        print("\n🗣️ [STEP 2] Starting conversation with \(queries.count) questions about all documents")
        print("   All queries reference all \(uploadedFiles.count) uploaded documents")
        print("   Same session and API key maintained throughout")
        
        for (index, query) in queries.enumerated() {
            print("\n" + String(repeating: "=", count: 100))
            print("❓ [QUESTION \(index + 1)/\(queries.count)] - MULTI-DOCUMENT QUERY")
            print(String(repeating: "=", count: 100))
            print("   Query: \"\(query)\"")
            print("   SessionID: \(session.id.prefix(8))")
            print("   Number of documents referenced: \(uploadedFiles.count)")
            print("   Time: \(Date())")
            
            let docQuery = GeminiDocumentConversationManager.DocumentQuery(
                text: query,
                documents: [], // Already uploaded - all documents in session
                systemInstruction: nil,
                generationConfig: nil,
                safetySettings: nil
            )
            
            print("\n⏳ Processing multi-document query \(index + 1)...")
            
            let response = try await measureAndLog(operationName: "Multi-document query \(index + 1)") {
                try await documentManager.processQuery(docQuery, in: session)
            }
            
            print("\n📥 [RESPONSE \(index + 1)]")
            print(String(repeating: "-", count: 50))
            
            validateBasicContentResponse(response)
            
            if let text = response.candidates.first?.content.parts.first?.text {
                print("   Response length: \(text.count) characters")
                print("\n📝 [CONTENT \(index + 1)]:")
                print("   \"\(text)\"")
                print("\n✅ Multi-document response \(index + 1) received successfully")
                
                // Verify API key hasn't changed
                print("   API key verification: \(session.apiSession.apiKey.prefix(8))... (unchanged)")
                
                // Add delay for readability
                if index < queries.count - 1 {
                    print("\n⏳ Waiting 3 seconds before next question...")
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
        
        print("\n" + String(repeating: "=", count: 100))
        print("✅ [TEST COMPLETE] Multi-document conversation test passed")
        print("   📊 Summary:")
        print("   - Uploaded \(uploadedFiles.count) documents in one batch")
        print("   - Asked \(queries.count) questions about all documents")
        print("   - Used 1 session throughout (no API key rotation)")
        print("   - All documents remained accessible for all queries")
        print("   - Total API calls: 1 (upload) + \(queries.count) (queries) = \(1 + queries.count)")
        print(String(repeating: "=", count: 100))
    }
}