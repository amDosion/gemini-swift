# Video Module

This module provides video processing and analysis capabilities using the Gemini API.

## Architecture

```
Video/
├── GeminiVideoManager.swift   # High-level coordinator
├── GeminiVideoUploader.swift  # Video file upload handling
└── README.md                  # This file
```

## Components

### GeminiVideoManager

High-level coordinator for video operations:
- `analyze()` - Analyze video content
- `transcribe()` - Extract transcription from video
- `summarize()` - Generate video summaries
- `extractKeyframes()` - Identify key moments
- `batchProcess()` - Process multiple videos

### GeminiVideoUploader

Handles video file uploads:
- Supports MP4, MOV, AVI, MKV, WebM formats
- Chunked upload for large files
- Progress tracking
- Session management

## Usage Examples

### Video Analysis

```swift
let client = GeminiClient(apiKey: "YOUR_API_KEY")
let videoManager = GeminiVideoManager(client: client)

let analysis = try await videoManager.analyze(
    videoFileURL: videoURL,
    prompt: "Describe what happens in this video"
)
```

### Video Transcription

```swift
let transcription = try await videoManager.transcribe(
    videoFileURL: videoURL,
    includeTimestamps: true
)
```

### Video Summarization

```swift
let summary = try await videoManager.summarize(
    videoFileURL: videoURL,
    maxLength: 500
)
```

## Supported Formats

| Format | MIME Type | Extensions |
|--------|-----------|------------|
| MP4 | video/mp4 | .mp4 |
| MOV | video/quicktime | .mov |
| AVI | video/x-msvideo | .avi |
| MKV | video/x-matroska | .mkv |
| WebM | video/webm | .webm |
