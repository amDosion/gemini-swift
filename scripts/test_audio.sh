#!/bin/bash

# Test script for audio recognition functionality
echo "🎵 Testing Gemini Swift Audio Recognition"
echo "======================================="

# Check if API key is set
if [ -z "$GEMINI_API_KEY" ]; then
    echo "❌ Error: GEMINI_API_KEY environment variable not set"
    echo "Please run: export GEMINI_API_KEY=your_api_key_here"
    exit 1
fi

# Build the project
echo "📦 Building project..."
swift build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful"

# Create a dummy audio file for testing (if none exists)
if [ ! -f "/tmp/sample.mp3" ]; then
    echo "📝 Creating dummy audio file for testing..."
    # Create a minimal valid MP3 file (silent)
    printf "\x00\x00\x00\x20\x66\x74\x79\x70\x6d\x70\x34\x32\x00\x00\x00\x00\x6d\x70\x34\x32\x69\x73\x6f\x6d\x00\x00\x00\x08\x66\x72\x65\x65\x00\x00\x00\x08\x6d\x64\x61\x74\x00\x00\x00\x00" > /tmp/sample.mp3
    echo "✅ Created /tmp/sample.mp3"
fi

# Run the test runner
echo ""
echo "🧪 Running audio recognition tests..."
echo "Select option 7 when prompted"
echo ""

# Run the test runner
swift run GeminiTestRunner

echo ""
echo "🎉 Audio recognition testing complete!"