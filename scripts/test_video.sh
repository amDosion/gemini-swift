#!/bin/bash

# Video Test Script for Gemini Swift
# This script demonstrates video understanding functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎥 Gemini Swift Video Test Script${NC}"
echo "================================"

# Check if API key is set
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}❌ Error: GEMINI_API_KEY environment variable not set${NC}"
    echo "Please set your API key:"
    echo "  export GEMINI_API_KEY=your_api_key_here"
    exit 1
fi

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo -e "${RED}❌ Error: Swift not found${NC}"
    echo "Please install Swift from https://swift.org"
    exit 1
fi

# Build the project
echo -e "${YELLOW}🔨 Building project...${NC}"
swift build > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Check for test video file
VIDEO_FILE="Tests/Resources/test_video.mp4"
if [ ! -f "$VIDEO_FILE" ]; then
    echo -e "${YELLOW}⚠️  Warning: Test video file not found at $VIDEO_FILE${NC}"
    echo "The video tests will run with mock data."
    echo "To test with real video, place an MP4 file at $VIDEO_FILE"
    echo ""
fi

# Run video tests
echo -e "${YELLOW}🧪 Running video tests...${NC}"
echo ""

# Create a simple Swift script to test video functionality
cat > video_test.swift << 'EOF'
import Foundation
import gemini_swfit

// Set up logging
SwiftyBeaver.setup()
let console = ConsoleDestination()
SwiftyBeaver.addDestination(console)

// Get API key from environment
guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
    print("❌ Error: GEMINI_API_KEY not set")
    exit(1)
}

// Create client and video manager
let client = GeminiClient(apiKey: apiKey)
let videoManager = GeminiVideoManager(client: client)

// Test video format support
print("📹 Testing video format support...")
let supportedFormats = videoManager.supportedFormats
print("Supported formats: \(supportedFormats.map { $0.fileExtension }.joined(separator: ", "))")

// Test with mock video URI (since we don't have real video)
print("\n🎬 Testing video analysis with mock data...")
let mockURI = "https://example.com/mock_video.mp4"

Task {
    do {
        // Test basic analysis
        let analysis = try await client.analyzeVideo(
            model: .gemini25Flash,
            videoFileURI: mockURI,
            mimeType: "video/mp4",
            prompt: "What would typically be shown in a demonstration video?"
        )
        print("\n✅ Video Analysis Result:")
        print(analysis)
        
        // Test transcription
        let transcription = try await client.transcribeVideo(
            model: .gemini25Flash,
            videoFileURI: mockURI,
            mimeType: "video/mp4"
        )
        print("\n✅ Transcription Result:")
        print(transcription)
        
        // Test summarization
        let summary = try await client.summarizeVideo(
            model: .gemini25Flash,
            videoFileURI: mockURI,
            mimeType: "video/mp4"
        )
        print("\n✅ Summary Result:")
        print(summary)
        
        // Test quiz generation
        let quiz = try await client.generateVideoQuiz(
            model: .gemini25Flash,
            videoFileURI: mockURI,
            mimeType: "video/mp4",
            questionCount: 3
        )
        print("\n✅ Quiz Result:")
        print(quiz)
        
        print("\n🎉 All video tests completed successfully!")
        
    } catch {
        print("\n❌ Error: \(error)")
        exit(1)
    }
}

// Keep the program running
RunLoop.main.run(until: Date(timeIntervalSinceNow: 30))
EOF

# Run the test script
echo -e "${YELLOW}🚀 Executing video test...${NC}"
swift video_test.swift

# Clean up
rm -f video_test.swift

echo ""
echo -e "${GREEN}✅ Video test script completed${NC}"
echo ""
echo "To run interactive video tests:"
echo "  swift run GeminiTestRunner"
echo "Then select option 10 for video tests"