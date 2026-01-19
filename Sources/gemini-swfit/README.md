# Gemini Swift Library

A comprehensive Swift library for Google's Gemini AI API with support for text generation, image generation/editing, audio transcription, document analysis, and video processing.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Module Overview](#module-overview)
- [User Flows](#user-flows)
- [Thread Safety](#thread-safety)
- [Error Handling](#error-handling)
- [API Reference](#api-reference)

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/gemini-swift.git", from: "1.0.0")
]
```

## Quick Start

### Basic Text Generation

```swift
import gemini_swfit

// Initialize client (failable - returns nil if apiKeys is empty)
guard let client = GeminiClient(apiKey: "YOUR_API_KEY") else {
    print("Failed to initialize client")
    return
}

// Generate text
let response = try await client.generateContent(
    model: .gemini25Flash,
    prompt: "Explain quantum computing"
)
print(response.text ?? "No response")
```

### Image Generation

```swift
let imageManager = client.imageManager()

// Generate image
let image = try await imageManager.generateImage(
    prompt: "A sunset over mountains",
    model: .gemini25FlashImage
)

// Save to file
try image.data.write(to: URL(fileURLWithPath: "sunset.png"))
```

## Module Overview

| Module | Description | Key Classes |
|--------|-------------|-------------|
| **Core** | Base functionality, uploaders, caching | `GeminiClient`, `GeminiBaseUploader`, `GeminiCacheManager` |
| **Image** | Image generation and editing | `GeminiImageManager`, `GeminiImageGenerator`, `GeminiImageEditor` |
| **Audio** | Audio upload and transcription | `GeminiAudioUploader`, `GeminiAudioManager` |
| **Video** | Video upload and analysis | `GeminiVideoUploader`, `GeminiVideoManager` |
| **Document** | Document upload and conversation | `GeminiDocumentUploader`, `GeminiDocumentConversationManager` |
| **Camera** | Photo capture integration | `GeminiCameraManager` |
| **API** | API key management, third-party providers | `GeminiAPIKeyManager`, `GeminiAPIProvider` |
| **Schema** | JSON Schema generation | `JSONSchemaGenerator` |

## User Flows

### 1. Client Initialization

```swift
// Single API key (convenience initializer)
let client = GeminiClient(apiKey: "YOUR_API_KEY")

// Multiple API keys with rotation (failable)
guard let client = GeminiClient(apiKeys: ["KEY1", "KEY2", "KEY3"]) else {
    fatalError("API keys array was empty")
}

// With custom base URL
guard let client = GeminiClient(
    apiKeys: ["YOUR_KEY"],
    baseURL: URL(string: "https://custom-endpoint.com/v1/")
) else {
    return
}

// Third-party provider (OpenRouter, Together AI, etc.)
let client = GeminiClient.withOpenRouter(apiKey: "OPENROUTER_KEY")
```

### 2. Image Generation Flow

```swift
// Step 1: Get image manager
let imageManager = client.imageManager()

// Step 2: Configure generation
let config = ImageGenerationConfig(
    numberOfImages: 1,
    aspectRatio: .landscape16x9,
    safetyFilterLevel: .blockMediumAndAbove
)

// Step 3: Generate
let response = try await imageManager.generateImage(
    prompt: "A futuristic city",
    model: .gemini25FlashImage,
    config: config
)

// Step 4: Handle result
if let image = response.images.first {
    try image.data.write(to: outputURL)
}
```

### 3. Image Editing Flow

```swift
// Load existing image
let imageData = try Data(contentsOf: imageURL)

// Edit with conversation context
let conversationManager = GeminiImageConversationManager(client: client)
let sessionId = conversationManager.startSession(apiKey: client.getNextApiKey())

// Add image to session
try conversationManager.addImage(imageData, sessionId: sessionId)

// Send edit instructions
let response = try await conversationManager.sendMessage(
    "Make the sky more vibrant and add some clouds",
    sessionId: sessionId
)

// Get edited image
if let editedImage = response.image {
    try editedImage.data.write(to: outputURL)
}

// Cleanup
conversationManager.endSession(sessionId)
```

### 4. Audio Upload and Transcription Flow

```swift
// Step 1: Create uploader
let uploader = GeminiAudioUploader()

// Step 2: Start session
let session = uploader.startSession(apiKey: client.getNextApiKey())

// Step 3: Upload audio
let fileInfo = try await uploader.uploadAudio(
    at: audioURL,
    displayName: "meeting-recording.mp3",
    session: session
)

// Step 4: Transcribe using GeminiClient
let transcription = try await client.transcribeAudio(
    fileURI: fileInfo.uri,
    mimeType: "audio/mp3"
)

// Step 5: End session
uploader.endSession(session.sessionID)
```

### 5. Document Upload Flow

```swift
let uploader = GeminiDocumentUploader()
let session = uploader.startSession(apiKey: client.getNextApiKey())

// Upload PDF
let fileInfo = try await uploader.uploadFile(
    at: pdfURL,
    displayName: "report.pdf",
    session: session
)

// Ask questions about the document
let response = try await client.generateContent(
    model: .gemini25Flash,
    prompt: "Summarize this document",
    fileURI: fileInfo.uri
)

uploader.endSession(session.sessionID)
```

### 6. Video Analysis Flow

```swift
let videoManager = GeminiVideoManager(client: client)

// Analyze video content
let analysis = try await videoManager.analyze(
    videoFileURL: videoURL,
    prompt: "Describe what happens in this video",
    model: .gemini25Flash
)

// Or transcribe audio from video
let transcription = try await videoManager.transcribe(
    videoFileURL: videoURL,
    language: "en"
)
```

### 7. Camera Capture Flow (iOS/macOS)

```swift
let cameraManager = GeminiCameraManager(imageManager: client.imageManager())

// Capture from camera
#if os(iOS)
let photo = try await cameraManager.capturePhoto()
#endif

// Or load from file
let photo = try cameraManager.loadImage(from: imageURL)

// Edit captured photo
let editedImage = try await cameraManager.editCapturedPhoto(
    photo,
    instructions: "Add a vintage filter"
)
```

## Thread Safety

All session management in this library is thread-safe:

- **GeminiClient**: API key rotation uses `DispatchQueue` with barrier flags
- **Upload Sessions**: All uploaders (Audio, Document, Video, Image) use concurrent queues with barrier-synchronized writes
- **GeminiAPIKeyManager**: Uses internal actor for state management
- **GeminiCacheManager**: Implemented as Swift actor

### Session Pattern

All session structs are `Sendable` and immutable:

```swift
public struct AudioSession: Sendable {
    public let sessionID: String
    public let apiKey: String
    public let uploadedFiles: [FileInfo]  // Immutable
}
```

## Error Handling

### Client Initialization

```swift
// Failable initializer returns nil for empty keys
guard let client = GeminiClient(apiKeys: keys) else {
    // Handle error: keys array was empty
    return
}
```

### API Errors

```swift
do {
    let response = try await client.generateContent(...)
} catch let error as GeminiClient.GeminiError {
    switch error {
    case .apiError(let message, let code):
        print("API Error (\(code ?? 0)): \(message)")
    case .networkError(let underlyingError):
        print("Network Error: \(underlyingError)")
    case .decodingError(let underlyingError):
        print("Decoding Error: \(underlyingError)")
    case .invalidModel(let message):
        print("Invalid Model: \(message)")
    }
}
```

### Image Errors

```swift
do {
    let image = try await imageManager.generateImage(...)
} catch let error as GeminiImageError {
    switch error {
    case .generationFailed(let reason):
        print("Generation failed: \(reason)")
    case .quotaExceeded:
        print("API quota exceeded")
    case .invalidImageData:
        print("Invalid image data provided")
    case .modelNotSupported(let reason):
        print("Model not supported: \(reason)")
    default:
        print("Image error: \(error)")
    }
}
```

## API Reference

### GeminiClient

| Method | Description |
|--------|-------------|
| `init?(apiKeys:baseURL:logger:)` | Initialize with multiple API keys (failable) |
| `init(apiKey:baseURL:logger:)` | Initialize with single API key |
| `generateContent(model:prompt:...)` | Generate text content |
| `generateContentWithImage(...)` | Generate with image input |
| `imageManager()` | Get image manager instance |
| `getNextApiKey()` | Get next API key in rotation |

### GeminiImageManager

| Method | Description |
|--------|-------------|
| `generateImage(prompt:model:config:)` | Generate single image |
| `generateImages(prompts:...)` | Batch generate images |
| `editImage(instructions:imageData:...)` | Edit existing image |
| `batchGenerateImages(prompts:...)` | Concurrent batch generation |

### GeminiAudioUploader

| Method | Description |
|--------|-------------|
| `startSession(apiKey:)` | Start upload session |
| `uploadAudio(at:displayName:session:)` | Upload audio file |
| `getSession(_:)` | Get session by ID |
| `endSession(_:)` | End and cleanup session |

### GeminiVideoManager

| Method | Description |
|--------|-------------|
| `analyze(videoFileURL:prompt:...)` | Analyze video content |
| `transcribe(videoFileURL:language:...)` | Transcribe video audio |

## Directory Structure

```
Sources/gemini-swfit/
├── GeminiClient.swift          # Main client
├── API/                        # API key management, providers
├── Audio/                      # Audio upload/transcription
├── Camera/                     # Camera capture (iOS/macOS)
├── Core/                       # Base uploaders, cache, retry
├── Document/                   # Document upload/conversation
├── Extensions/                 # Client extensions
├── Image/                      # Image generation/editing
├── Models/                     # Data models
├── Schema/                     # JSON Schema generation
├── Utils/                      # Logging utilities
└── Video/                      # Video upload/analysis
```

## Requirements

- Swift 6.0+
- macOS 12+ / iOS 15+ / watchOS 8+ / tvOS 15+
- SwiftyBeaver (logging)

## License

MIT License
