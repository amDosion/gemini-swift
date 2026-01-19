# Extensions Module

This module contains extensions to `GeminiClient` that add specialized functionality.

## Architecture

```
Extensions/
├── GeminiClient+Audio.swift               # Audio processing methods
├── GeminiClient+Enhanced.swift            # Retry, caching, tracing
├── GeminiClient+FunctionCalling.swift     # Function calling support
├── GeminiClient+Image.swift               # Image generation & editing
├── GeminiClient+SessionManagement.swift   # API session management
├── GeminiClient+Streaming.swift           # Streaming responses
├── GeminiClient+TokenCounting.swift       # Token counting utilities
├── GeminiClient+Video.swift               # Video processing methods
└── README.md                              # This file
```

## Extensions

### GeminiClient+Audio

Audio processing without manual upload:
- `transcribeAudio()` - Transcribe audio files
- `analyzeAudio()` - Analyze audio with prompts

### GeminiClient+Enhanced

Enhanced request handling:
- `generateContentWithRetry()` - Automatic retries
- `generateContentCached()` - Response caching
- `generateContentTraced()` - Request tracing

### GeminiClient+FunctionCalling

Function calling support:
- Define callable functions
- Handle function calls in responses
- Execute and return results

### GeminiClient+Image

Image operations:
- `generateImage()` - Generate images from prompts
- `editImage()` - Edit images with instructions
- `inpaintInsert()` / `inpaintRemove()` - Inpainting
- `outpaint()` - Expand image boundaries
- `applyStyle()` - Style transfer
- `enhanceImageQuality()` - Quality enhancement

### GeminiClient+SessionManagement

Session-based operations:
- `createSession()` - Create pinned API session
- Session-aware request methods
- Consistent API key usage

### GeminiClient+Streaming

Streaming responses:
- `generateContentStream()` - Stream responses
- SSE parsing
- Chunk accumulation

### GeminiClient+TokenCounting

Token utilities:
- `countTokens()` - Count tokens in content
- Estimate costs
- Quota management

### GeminiClient+Video

Video processing:
- `analyzeVideo()` - Analyze video content
- `transcribeVideo()` - Extract transcription
- `summarizeVideo()` - Generate summaries

## Usage Pattern

All extensions are automatically available on `GeminiClient`:

```swift
let client = GeminiClient(apiKey: "YOUR_API_KEY")

// Audio
let transcription = try await client.transcribeAudio(
    model: .gemini25Flash,
    audioFileURL: audioURL
)

// Image
let image = try await client.generateImage(
    prompt: "A sunset over mountains"
)

// Streaming
for try await chunk in client.generateContentStream(
    model: .gemini25Flash,
    text: "Write a story..."
) {
    print(chunk.text)
}

// With retry
let response = try await client.generateContentWithRetry(
    model: .gemini25Flash,
    text: "Hello",
    retryConfig: .default
)
```

## Adding New Extensions

To add a new extension:

1. Create a new file: `GeminiClient+Feature.swift`
2. Extend `GeminiClient`:

```swift
extension GeminiClient {
    public func myNewFeature() async throws -> Result {
        // Implementation
    }
}
```

3. Add documentation to this README
4. Add tests in `Tests/gemini-swfitTests/`
