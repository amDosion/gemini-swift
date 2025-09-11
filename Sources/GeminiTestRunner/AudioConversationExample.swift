//
//  AudioConversationExample.swift
//  GeminiTestRunner
//
//  Created by Claude on 2025-01-11.
//

import Foundation
import gemini_swfit

/// Example demonstrating simple audio transcription using GeminiAudioConversationManager
public class AudioConversationExample {
    
    /// Simple audio transcription example
    public static func runSimpleTranscriptionExample() async {
        print("\n🎵 === Simple Audio Transcription Example ===")
        
        // Initialize client with your API key
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("❌ Please set GEMINI_API_KEY environment variable")
            return
        }
        
        let client = GeminiClient(apiKey: apiKey)
        let audioManager = GeminiAudioConversationManager(client: client)
        
        // Example audio file path
        let audioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ Audio file not found at: \(audioURL.path)")
            return
        }
        
        do {
            // Simple transcription
            print("\n📝 Transcribing audio...")
            let transcription = try await audioManager.transcribeAudio(
                audioURL,
                displayName: "Medical Consultation",
                language: "zh",
                systemInstruction: "你是一个医疗记录员，请准确转录医疗对话内容。"
            )
            
            print("\n✅ Transcription Result:")
            print(transcription)
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
    
    /// Transcription with analysis example
    public static func runTranscriptionWithAnalysisExample() async {
        print("\n🔍 === Transcription with Analysis Example ===")
        
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("❌ Please set GEMINI_API_KEY environment variable")
            return
        }
        
        let client = GeminiClient(apiKey: apiKey)
        let audioManager = GeminiAudioConversationManager(client: client)
        
        let audioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ Audio file not found at: \(audioURL.path)")
            return
        }
        
        do {
            // Transcribe and analyze
            print("\n📝 Transcribing and analyzing audio...")
            let analysis = try await audioManager.transcribeAndAnalyze(
                audioURL,
                displayName: "Patient Consultation",
                query: "What are the main medical concerns mentioned? What tests are recommended?",
                language: "zh",
                systemInstruction: "你是一个医疗分析专家，请转录并提供专业的医疗分析。"
            )
            
            print("\n✅ Analysis Result:")
            print(analysis)
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
    
    /// Batch transcription example
    public static func runBatchTranscriptionExample() async {
        print("\n📊 === Batch Transcription Example ===")
        
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("❌ Please set GEMINI_API_KEY environment variable")
            return
        }
        
        let client = GeminiClient(apiKey: apiKey)
        let audioManager = GeminiAudioConversationManager(client: client)
        
        // For this example, we'll use the same file multiple times
        let audioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ Audio file not found at: \(audioURL.path)")
            return
        }
        
        // Create multiple audio files (in real use, these would be different files)
        let audioFiles = Array(repeating: audioURL, count: 2)
        let displayNames = ["Patient Recording 1", "Patient Recording 2"]
        
        do {
            // Batch transcription with different instructions
            print("\n📝 Processing batch transcription...")
            let results = try await audioManager.transcribeMultipleAudios(
                audioFiles,
                displayNames: displayNames,
                language: "zh",
                systemInstruction: "请准确转录音频内容"
            )
            
            print("\n✅ Batch Transcription Results:")
            for (displayName, transcription) in results {
                print("\n📄 \(displayName):")
                print(transcription)
            }
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
    
    /// Session-based conversation example
    public static func runSessionBasedConversationExample() async {
        print("\n💬 === Session-based Audio Conversation Example ===")
        
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("❌ Please set GEMINI_API_KEY environment variable")
            return
        }
        
        let client = GeminiClient(apiKey: apiKey)
        let audioManager = GeminiAudioConversationManager(client: client)
        
        let audioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ Audio file not found at: \(audioURL.path)")
            return
        }
        
        do {
            // Create a session for multiple interactions
            let session = audioManager.createSession()
            defer { audioManager.endSession(session) }
            
            // Upload audio once
            print("\n📤 Uploading audio to session...")
            let uploadedFiles = try await audioManager.uploadAudios(
                to: session,
                audioFiles: [audioURL],
                displayNames: ["Medical Consultation"]
            )
            
            print("✅ Audio uploaded successfully: \(uploadedFiles.first?.name ?? "Unknown")")
            
            // Multiple queries without re-uploading
            let queries = [
                "What are the main symptoms mentioned?",
                "What medical tests are recommended?",
                "Summarize the patient's condition in medical terms."
            ]
            
            for (index, query) in queries.enumerated() {
                print("\n💬 Query \(index + 1): \(query)")
                
                let audioQuery = GeminiAudioConversationManager.AudioQuery(
                    text: query,
                    audioFiles: [], // Use uploaded audio
                    systemInstruction: "You are a medical assistant. Answer based on the transcribed audio."
                )
                
                let response = try await audioManager.processQuery(
                    audioQuery,
                    in: session
                )
                
                let answer = response.candidates.first?.content.parts.first?.text ?? "No response"
                print("📝 Answer: \(answer)")
            }
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
    
    /// Audio comparison example
    public static func runAudioComparisonExample() async {
        print("\n🔀 === Audio Comparison Example ===")
        
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("❌ Please set GEMINI_API_KEY environment variable")
            return
        }
        
        let client = GeminiClient(apiKey: apiKey)
        let audioManager = GeminiAudioConversationManager(client: client)
        
        // For this example, we'll use the same file
        let audioURL = URL(fileURLWithPath: "/Users/zhangsan/Desktop/ios-app/kangxinban/gemini-swfit/Tests/Resources/1753924165117.mp3")
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ Audio file not found at: \(audioURL.path)")
            return
        }
        
        do {
            // Compare audio with itself (for demonstration)
            print("\n🔀 Comparing audio recordings...")
            let comparison = try await audioManager.compareAudios(
                audioURL,
                audioURL,
                displayName1: "Recording A",
                displayName2: "Recording B",
                comparisonPrompt: "Analyze and compare the content of these recordings.",
                language: "zh"
            )
            
            print("\n✅ Comparison Result:")
            print(comparison)
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Run All Examples

/// Run all audio conversation examples
public func runAllAudioConversationExamples() async {
    print("\n🎵 Running all Audio Conversation Examples...")
    
    await AudioConversationExample.runSimpleTranscriptionExample()
    await AudioConversationExample.runTranscriptionWithAnalysisExample()
    await AudioConversationExample.runBatchTranscriptionExample()
    await AudioConversationExample.runSessionBasedConversationExample()
    await AudioConversationExample.runAudioComparisonExample()
    
    print("\n🎉 All Audio Conversation Examples completed!")
}