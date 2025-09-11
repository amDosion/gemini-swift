//
//  AudioExample.swift
//  GeminiTestRunner
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import gemini_swfit

/// Example demonstrating audio upload and recognition functionality
class AudioExample {
    let client: GeminiClient
    let apiKey: String
    
    init(client: GeminiClient, apiKey: String) {
        self.client = client
        self.apiKey = apiKey
    }
    
    /// Example: Upload audio and get transcription
    func runAudioTranscriptionExample() async {
        print("=== Audio Transcription Example ===")
        
        guard let audioURL = getSampleAudioURL() else {
            print("Sample audio file not found")
            return
        }
        
        do {
            // Method 1: Upload and transcribe in one call
            print("Method 1: Upload and transcribe in one call")
            let transcription = try await client.uploadAndTranscribeAudio(
                model: .gemini25Flash,
                audioFileURL: audioURL,
                language: "en",
                systemInstruction: "Please provide accurate transcription with proper punctuation"
            )
            print("Transcription: \(transcription)")
            
            // Method 2: Separate upload and transcription
            print("\nMethod 2: Separate upload and transcription")
            let uploader = GeminiAudioUploader()
            let session = uploader.startSession(apiKey: apiKey)
            
            let fileInfo = try await uploader.uploadAudio(at: audioURL, session: session)
            print("Audio uploaded successfully. URI: \(fileInfo.uri)")
            
            let transcription2 = try await client.transcribeAudio(
                model: .gemini25Flash,
                audioFileURI: fileInfo.uri,
                mimeType: fileInfo.mimeType ?? "audio/mpeg",
                language: "en"
            )
            print("Transcription 2: \(transcription2)")
            
            uploader.endSession(session)
            
        } catch {
            print("Audio transcription failed: \(error.localizedDescription)")
        }
    }
    
    /// Example: Analyze audio content
    func runAudioAnalysisExample() async {
        print("\n=== Audio Analysis Example ===")
        
        guard let audioURL = getSampleAudioURL() else {
            print("Sample audio file not found")
            return
        }
        
        do {
            // Upload and analyze audio
            let analysis = try await client.processAudio(
                model: .gemini25Flash,
                audioFileURL: audioURL,
                prompt: "Analyze this audio clip and provide: 1) A brief summary 2) The main topics discussed 3) Any notable features",
                systemInstruction: "You are an expert audio analyst. Provide detailed and accurate analysis."
            )
            
            print("Audio Analysis:\n\(analysis)")
            
        } catch {
            print("Audio analysis failed: \(error.localizedDescription)")
        }
    }
    
    /// Example: Batch upload multiple audio files
    func runBatchAudioUploadExample() async {
        print("\n=== Batch Audio Upload Example ===")
        
        let audioURLs = getMultipleSampleAudioURLs()
        guard !audioURLs.isEmpty else {
            print("No sample audio files found")
            return
        }
        
        let uploader = GeminiAudioUploader()
        let session = uploader.startSession(apiKey: apiKey)
        
        do {
            // Upload multiple audio files
            let fileInfos = try await uploader.uploadAudioFiles(at: audioURLs, session: session)
            
            print("Successfully uploaded \(fileInfos.count) audio files:")
            for fileInfo in fileInfos {
                print("- \(fileInfo.displayName ?? "Untitled"): \(fileInfo.uri)")
            }
            
            // Process each file
            for fileInfo in fileInfos {
                guard let mimeType = fileInfo.mimeType else { continue }
                
                let transcription = try await client.transcribeAudio(
                    model: .gemini25Flash,
                    audioFileURI: fileInfo.uri,
                    mimeType: mimeType
                )
                
                print("\nTranscription for \(fileInfo.displayName ?? "Untitled"):")
                print(transcription)
            }
            
        } catch {
            print("Batch audio upload failed: \(error.localizedDescription)")
        }
        
        uploader.endSession(session)
    }
    
    // MARK: - Helper Methods
    
    private func getSampleAudioURL() -> URL? {
        // Look for sample audio file in Resources
        let paths = [
            Bundle.main.path(forResource: "sample", ofType: "mp3"),
            Bundle.main.path(forResource: "sample", ofType: "wav"),
            Bundle.main.path(forResource: "audio", ofType: "m4a"),
            // Fallback to a test file path
            "/tmp/sample.mp3",
            "/Users/Shared/sample.mp3"
        ]
        
        for path in paths {
            if let path = path, FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        return nil
    }
    
    private func getMultipleSampleAudioURLs() -> [URL] {
        let patterns = [
            "/tmp/sample1.mp3",
            "/tmp/sample2.mp3",
            "/tmp/sample3.mp3",
            "/Users/Shared/audio1.mp3",
            "/Users/Shared/audio2.wav"
        ]
        
        return patterns.compactMap { path in
            FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
        }
    }
}

// Extension to run the example
extension GeminiTestRunner {
    func runAudioExamples(client: GeminiClient, apiKey: String) async {
        let audioExample = AudioExample(client: client, apiKey: apiKey)
        
        await audioExample.runAudioTranscriptionExample()
        await audioExample.runAudioAnalysisExample()
        await audioExample.runBatchAudioUploadExample()
    }
}