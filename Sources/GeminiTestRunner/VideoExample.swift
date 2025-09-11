//
//  VideoExample.swift
//  GeminiTestRunner
//
//  Created by Claude on 2025-01-10.
//

import Foundation
import gemini_swfit

/// Example demonstrating video understanding capabilities
public class VideoExample {
    
    private let client: GeminiClient
    private let videoManager: GeminiVideoManager
    
    public init(apiKey: String) {
        self.client = GeminiClient(apiKey: apiKey)
        self.videoManager = GeminiVideoManager(client: client)
    }
    
    /// Run video understanding examples
    public func runExamples() async {
        print("🎥 Video Understanding Examples")
        print("=" * 50)
        
        // Note: Replace with actual video file path
        guard let videoURL = getTestVideoURL() else {
            print("❌ No test video file found. Please add a video file to test.")
            return
        }
        
        do {
            // Example 1: Basic video analysis
            print("\n1. Basic Video Analysis")
            print("-" * 30)
            let analysis = try await videoManager.analyze(
                videoFileURL: videoURL,
                prompt: "What is happening in this video? Describe the main scenes and actions."
            )
            print("Analysis: \(analysis)")
            
            // Example 2: Video transcription
            print("\n2. Video Transcription")
            print("-" * 30)
            let transcription = try await videoManager.transcribe(
                videoFileURL: videoURL
            )
            print("Transcription: \(transcription)")
            
            // Example 3: Video summary
            print("\n3. Video Summary")
            print("-" * 30)
            let summary = try await videoManager.summarize(
                videoFileURL: videoURL
            )
            print("Summary: \(summary)")
            
            // Example 4: Key moments extraction
            print("\n4. Key Moments Extraction")
            print("-" * 30)
            let keyMoments = try await videoManager.extractKeyMoments(
                videoFileURL: videoURL
            )
            print("Key Moments: \(keyMoments)")
            
            // Example 5: Quiz generation
            print("\n5. Quiz Generation")
            print("-" * 30)
            let quiz = try await videoManager.generateQuiz(
                videoFileURL: videoURL,
                questionCount: 3
            )
            print("Quiz: \(quiz)")
            
            // Example 6: Object detection
            print("\n6. Object and Scene Detection")
            print("-" * 30)
            let objects = try await videoManager.detectObjectsAndScenes(
                videoFileURL: videoURL
            )
            print("Objects and Scenes: \(objects)")
            
            // Example 7: Educational analysis
            print("\n7. Educational Content Analysis")
            print("-" * 30)
            let educational = try await videoManager.analyzeEducationalContent(
                videoFileURL: videoURL
            )
            print("Educational Analysis: \(educational)")
            
            // Example 8: YouTube video analysis
            print("\n8. YouTube Video Analysis")
            print("-" * 30)
            let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
            let youtubeAnalysis = try await videoManager.analyzeYouTubeVideo(
                videoURL: youtubeURL,
                prompt: "Summarize this YouTube video in 3 sentences."
            )
            print("YouTube Analysis: \(youtubeAnalysis)")
            
            // Example 9: YouTube video summary
            print("\n9. YouTube Video Summary")
            print("-" * 30)
            let youtubeSummary = try await videoManager.summarizeYouTubeVideo(
                videoURL: youtubeURL,
                maxLength: 100
            )
            print("YouTube Summary: \(youtubeSummary)")
            
            // Example 10: YouTube video quiz
            print("\n10. YouTube Video Quiz")
            print("-" * 30)
            let youtubeQuiz = try await videoManager.generateYouTubeVideoQuiz(
                videoURL: youtubeURL,
                questionCount: 3
            )
            print("YouTube Quiz: \(youtubeQuiz)\n")
            
            // Example 11: Multi-turn conversation with YouTube video
            print("11. Multi-turn YouTube Video Conversation")
            print("-" * 30)
            let conversationManager = GeminiConversationManager(
                client: self.client,
                systemInstruction: "你是一个专业的视频内容分析师"
            )
            
            print("Starting conversation about YouTube video...")
            let response1 = try await conversationManager.startYouTubeVideoConversation(
                videoURL: youtubeURL,
                firstMessage: "这个视频是关于什么的？请简要概述。"
            )
            print("First response: \(response1)\n")
            
            let response2 = try await conversationManager.continueYouTubeVideoConversation(
                "视频中提到了哪些关键点或重要概念？"
            )
            print("Follow-up 1: \(response2)\n")
            
            let response3 = try await conversationManager.continueYouTubeVideoConversation(
                "这些内容有什么实际应用价值？"
            )
            print("Follow-up 2: \(response3)\n")
            
            print("Total messages in conversation: \(conversationManager.messageCount)")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    /// Get test video URL
    private func getTestVideoURL() -> URL? {
        // Try file system paths (since bundle might not work in test runner)
        let possiblePaths = [
            "Sources/GeminiTestRunner/Resources/oceans.mp4",
            "Tests/Resources/oceans.mp4",
            "oceans.mp4",
            "test.mp4",
            "sample.mp4",
            "video.mp4"
        ]
        
        for path in possiblePaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        
        return nil
    }
}

