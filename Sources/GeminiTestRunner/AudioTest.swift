//
//  AudioTest.swift
//  GeminiTestRunner
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import gemini_swfit

/// Test audio functionality with specific test file
public class AudioTest {
    public let client: GeminiClient
    public let apiKey: String
    
    public init(client: GeminiClient, apiKey: String) {
        self.client = client
        self.apiKey = apiKey
    }
    
    /// Run comprehensive audio tests
    public func runAudioTests() async {
        print("=== Audio Functionality Test ===")
        
        // Audio file URL
        let audioFileURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        
        // Check file info
        do {
            let resources = try audioFileURL.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize {
                print("Audio file: \(audioFileURL.lastPathComponent)")
                print("File size: \(fileSize) bytes")
            }
        } catch {
            print("Error getting file info: \(error)")
            return
        }
        
        // Test 1: Basic Audio Upload
        await testBasicAudioUpload(audioFileURL: audioFileURL)
        
        // Test 2: Enhanced Audio Management
        await testEnhancedAudioManagement(audioFileURL: audioFileURL)
        
        print("\n=== Test Complete ===")
    }
    
    /// Test basic audio upload functionality
    private func testBasicAudioUpload(audioFileURL: URL) async {
        print("\n=== Test 1: Basic Audio Upload ===")
        
        do {
            let uploader = GeminiAudioUploader()
            let session = uploader.startSession(apiKey: apiKey)
            
            print("Uploading audio file...")
            let uploadedFile = try await uploader.uploadAudio(
                at: audioFileURL,
                displayName: "Test Audio",
                session: session
            )
            
            print("✅ Upload successful!")
            print("File URI: \(uploadedFile.uri)")
            print("File name: \(uploadedFile.name)")
            print("Display name: \(uploadedFile.displayName ?? "N/A")")
            print("MIME type: \(uploadedFile.mimeType ?? "N/A")")
            
            // Test transcription
            print("\n--- Testing Transcription ---")
            let transcription = try await client.transcribeAudio(
                model: .gemini25Flash,
                audioFileURI: uploadedFile.uri,
                mimeType: uploadedFile.mimeType ?? "audio/mpeg",
                language: "zh" // Chinese audio
            )
            
            print("✅ Transcription successful!")
            print("Transcription result:")
            print("\"\(transcription)\"")
            
        } catch {
            print("❌ Error: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    /// Test enhanced audio management with key rotation
    private func testEnhancedAudioManagement(audioFileURL: URL) async {
        print("\n=== Test 2: Enhanced Audio Management ===")
        
        do {
            // Create multiple API keys for testing
            let testApiKeys = [
                apiKey,
                apiKey, // Same key for testing
                apiKey
            ]
            
            // Initialize enhanced audio manager
            let audioManager = GeminiAudioManagerEnhanced(
                apiKeys: testApiKeys,
                strategy: .leastUsed
            )
            
            print("Testing with enhanced key management...")
            
            // Test batch transcription
            let results = try await audioManager.batchTranscribeWithKeyManagement(
                audioFileURLs: [audioFileURL],
                language: "zh",
                systemInstruction: "请准确转录音频内容",
                progressHandler: { progress, completed in
                    print("Progress: \(Int(progress * 100))% (\(completed)/1)")
                }
            )
            
            print("✅ Enhanced audio management test successful!")
            
            for (filename, transcription) in results {
                print("\nFile: \(filename)")
                print("Transcription: \(transcription)")
            }
            
            // Show usage analytics
            let analytics = audioManager.getUsageAnalytics()
            print("\n--- Usage Analytics ---")
            print("Total Requests: \(analytics.totalRequests)")
            print("Total Bytes Uploaded: \(analytics.totalBytesUploaded)")
            print("Key Health: \(analytics.keyHealth.healthPercentage)%")
            print("Average Error Rate: \(String(format: "%.2f", analytics.averageErrorsPerKey))")
            
            // Test key optimization
            let optimization = audioManager.optimizeKeyUsage()
            print("\n--- Key Optimization ---")
            print("Health Score: \(String(format: "%.1f", optimization.healthScore))%")
            print("Suggested Strategy: \(optimization.suggestedStrategy)")
            
            if !optimization.recommendations.isEmpty {
                print("Recommendations:")
                for recommendation in optimization.recommendations {
                    print("  - \(recommendation)")
                }
            }
            
        } catch {
            print("❌ Enhanced audio management error: \(error)")
        }
    }
}

// MARK: - Extension for GeminiTestRunner

extension GeminiTestRunner {
    public func runAudioTests(client: GeminiClient, apiKey: String) async {
        let test = AudioTest(client: client, apiKey: apiKey)
        await test.runAudioTests()
    }
}