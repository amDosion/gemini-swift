# Audio Module

This module provides audio processing and transcription capabilities using the Gemini API.

## Architecture

```
Audio/
├── GeminiAudioManager.swift              # High-level coordinator
├── GeminiAudioUploader.swift             # Audio file upload handling
├── GeminiAudioUploaderEnhanced.swift     # Enhanced upload with retries
├── GeminiAudioConversationManager.swift  # Multi-turn audio conversations
└── README.md                             # This file
```

## Components

### GeminiAudioManager

High-level coordinator that combines upload and processing:
- `transcribe()` - Transcribe audio to text
- `analyze()` - Analyze audio with custom prompts
- `batchTranscribe()` - Process multiple audio files
- `summarize()` - Generate audio summaries
- `extractInsights()` - Extract key insights from audio

### GeminiAudioUploader

Handles audio file uploads:
- Supports MP3, WAV, FLAC, OGG, AAC, M4A formats
- Session management for multiple uploads
- Metadata extraction
- Format validation

### GeminiAudioConversationManager

Manages multi-turn conversations with audio context:
- Session-based conversations
- Context preservation
- Query building

## Usage Examples

### Basic Transcription

```swift
let client = GeminiClient(apiKey: "YOUR_API_KEY")
let audioManager = GeminiAudioManager(client: client)

let transcription = try await audioManager.transcribe(
    audioFileURL: audioURL,
    model: .gemini25Flash,
    language: "en"
)
```

### Audio Analysis

```swift
let analysis = try await audioManager.analyze(
    audioFileURL: audioURL,
    prompt: "Identify the speakers and summarize the main topics discussed"
)
```

### Batch Processing

```swift
let results = try await audioManager.batchTranscribe(
    audioFileURLs: [audio1URL, audio2URL, audio3URL],
    model: .gemini25Flash
)

for (filename, transcription) in results {
    print("\(filename): \(transcription)")
}
```

## Supported Formats

| Format | MIME Type | Extensions |
|--------|-----------|------------|
| MP3 | audio/mpeg | .mp3 |
| WAV | audio/wav | .wav |
| FLAC | audio/flac | .flac |
| OGG | audio/ogg | .ogg |
| AAC | audio/aac | .aac |
| M4A | audio/m4a | .m4a |
