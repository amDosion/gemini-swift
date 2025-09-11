//
//  DocumentUploadExample.swift
//  GeminiTestRunner
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import gemini_swfit

/// Example demonstrating document upload and processing with Gemini API
public class DocumentUploadExample {
    
    private let client: GeminiClient
    private let documentManager: GeminiDocumentConversationManager
    
    public init(apiKeys: [String]) {
        self.client = GeminiClient(apiKeys: apiKeys)
        self.documentManager = GeminiDocumentConversationManager(client: client)
    }
    
    /// Example 1: Basic document upload and query
    public func basicDocumentUploadExample() async {
        print("=== Basic Document Upload Example ===")
        
        do {
            // Create a document session
            let session = documentManager.createSession()
            defer { documentManager.endSession(session) }
            
            // Example PDF paths (replace with actual paths)
            let pdfURLs = [
                URL(fileURLWithPath: "/path/to/document1.pdf"),
                URL(fileURLWithPath: "/path/to/document2.pdf")
            ]
            
            // Upload documents
            let uploadedFiles = try await documentManager.uploadDocuments(
                to: session,
                documents: pdfURLs,
                displayNames: ["Research Paper 1", "Research Paper 2"]
            )
            
            print("Uploaded \(uploadedFiles.count) documents")
            
            // Process a query
            let response = try await documentManager.processQuery(
                text: "What are the main findings in these papers?",
                documents: pdfURLs,
                displayNames: ["Research Paper 1", "Research Paper 2"]
            )
            
            if let text = response.candidates.first?.content.parts.first?.text {
                print("Response: \(text)")
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 2: Compare two PDFs (like the shell script)
    public func comparePDFsExample() async {
        print("=== Compare PDFs Example ===")
        
        do {
            // Download and compare two PDFs from URLs
            let response = try await documentManager.comparePDFsFromURLs(
                pdf1URL: "https://arxiv.org/pdf/2312.11805",
                pdf2URL: "https://arxiv.org/pdf/2403.05530",
                displayName1: "Gemini_paper",
                displayName2: "Gemini_1.5_paper",
                comparisonPrompt: "What is the difference between each of the main benchmarks between these two papers? Output these in a table."
            )
            
            if let text = response.candidates.first?.content.parts.first?.text {
                print("Comparison Result:")
                print(text)
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 3: Multi-document conversation
    public func multiDocumentConversationExample() async {
        print("=== Multi-document Conversation Example ===")
        
        do {
            // Create a persistent session for multiple queries
            let session = documentManager.createSession()
            
            // Upload documents once
            let documentURLs = [
                URL(fileURLWithPath: "/path/to/financial_report.pdf"),
                URL(fileURLWithPath: "/path/to/technical_spec.pdf")
            ]
            
            let _ = try await documentManager.uploadDocuments(
                to: session,
                documents: documentURLs,
                displayNames: ["Q4 Financial Report", "Technical Specifications"]
            )
            
            // Multiple queries about the same documents
            let queries = [
                "What is the revenue mentioned in the financial report?",
                "What are the key technical requirements?",
                "How do the technical requirements impact the financial projections?"
            ]
            
            for query in queries {
                let docQuery = GeminiDocumentConversationManager.DocumentQuery(
                    text: query,
                    documents: [], // Already uploaded in session
                    systemInstruction: nil,
                    generationConfig: nil,
                    safetySettings: nil
                )
                let response = try await documentManager.processQuery(
                    docQuery,
                    in: session
                )
                
                if let text = response.candidates.first?.content.parts.first?.text {
                    print("\nQ: \(query)")
                    print("A: \(text)")
                }
            }
            
            documentManager.endSession(session)
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 4: Using low-level upload API
    public func lowLevelUploadExample() async {
        print("=== Low-level Upload API Example ===")
        
        do {
            // Create components
            let uploader = GeminiDocumentUploader()
            let apiSession = client.createSession()
            
            // Start upload session
            let uploadSession = uploader.startSession(apiKey: apiSession.apiKey)
            
            // Upload a single file
            let fileURL = URL(fileURLWithPath: "/path/to/document.pdf")
            let fileInfo = try await uploader.uploadFile(
                at: fileURL,
                displayName: "My Document",
                session: uploadSession
            )
            
            print("Uploaded file: \(fileInfo.displayName ?? "Unknown")")
            print("File URI: \(fileInfo.uri)")
            
            // Generate content using the uploaded file
            let response = try await client.generateContent(
                model: .gemini25Flash,
                files: [fileInfo],
                text: "Summarize this document",
                session: apiSession
            )
            
            if let text = response.candidates.first?.content.parts.first?.text {
                print("Summary: \(text)")
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 5: Error handling
    public func errorHandlingExample() async {
        print("=== Error Handling Example ===")
        
        do {
            // Try to upload non-existent file
            _ = try await documentManager.processQuery(
                text: "Analyze this document",
                documents: [URL(fileURLWithPath: "/non/existent/file.pdf")]
            )
            
        } catch let error as GeminiDocumentConversationManager.DocumentError {
            switch error {
            case .documentUploadFailed(let underlyingError):
                print("Upload failed: \(underlyingError.localizedDescription)")
            case .invalidFileExtension:
                print("Please provide a valid PDF file")
            default:
                print("Document error: \(error.localizedDescription)")
            }
        } catch {
            print("General error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Static main method for test runner
    
    public static func main() async {
        // Check for API key environment variable
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("❌ 错误: 请设置 GEMINI_API_KEY 环境变量")
            print("   例如: export GEMINI_API_KEY=your_api_key_here")
            return
        }
        
        print("📄 文档上传功能测试")
        print("==================")
        print("\n请选择要运行的示例:")
        print("1. 基础文档上传示例")
        print("2. PDF 对比示例")
        print("3. 多文档对话示例")
        print("4. 低级别 API 示例")
        print("5. 错误处理示例")
        print("\n请输入选项 (1-5): ", terminator: "")
        
        let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let example = DocumentUploadExample(apiKeys: [apiKey])
        
        switch input {
        case "1":
            await example.basicDocumentUploadExample()
        case "2":
            await example.comparePDFsExample()
        case "3":
            await example.multiDocumentConversationExample()
        case "4":
            await example.lowLevelUploadExample()
        case "5":
            await example.errorHandlingExample()
        default:
            print("运行 PDF 对比示例...")
            await example.comparePDFsExample()
        }
    }
}