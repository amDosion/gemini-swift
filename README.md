# Gemini Swift Library

[![Swift](https://img.shields.io/badge/Swift-6.1+-FA7343.svg?style=flat-square)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue.svg?style=flat-square)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

A production-ready Swift Package Manager library providing comprehensive integration with Google's Gemini AI API. Built with Swift 6.1+ and supports all Apple platforms.

## Features

### 🤖 **AI Capabilities**
- **Text Generation**: Advanced text generation with configurable parameters
- **Multimodal Processing**: Analyze text, images, audio, video, and documents together
- **Conversation Management**: Built-in history tracking and session management
- **Search Integration**: Real-time Google Search with grounding metadata

### 🎵 **Media Processing**
- **Audio Transcription**: Convert speech to text with language support
- **Image Analysis**: Understand and describe image content
- **Video Understanding**: Analyze video content and scenes
- **Document Chat**: Upload and converse with PDFs and text files

### 🔧 **Advanced Features**
- **Structured Output**: Generate responses in specific JSON formats
- **JSON Schema Generation**: Automatic schema generation from Codable types
- **Multi-Key Rotation**: Intelligent API key management and quota handling
- **Enhanced Logging**: SwiftyBeaver integration with configurable levels

## Requirements

- **Swift**: 6.1+
- **Platforms**:
  - macOS 12.0+
  - iOS 15.0+
  - watchOS 8.0+
  - tvOS 15.0+
- **Xcode**: 14.0+ (for Xcode projects)

## Installation

### Swift Package Manager

Add the package to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/huifer/gemini-swift.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. Go to **File > Add Packages...**
2. Enter the package URL: `https://github.com/huifer/gemini-swift.git`
3. Select the version and add it to your target

## Quick Start

### 1. **API Key Setup**

Get your API key from [Google AI Studio](https://aistudio.google.com/apikey):

```swift
import gemini_swfit

// Set your API key
let client = GeminiClient(apiKey: "your-api-key-here")

// Or use multiple keys for rotation
let client = GeminiClient(apiKeys: [
    "key1", "key2", "key3"
])
```

### 2. **Basic Text Generation**

```swift
do {
    let response = try await client.generateText(
        model: .gemini25Flash,
        prompt: "What is artificial intelligence?",
        systemInstruction: "You are a helpful assistant"
    )
    print(response.text)
} catch {
    print("Error: \(error)")
}
```

### 3. **Image Analysis**

```swift
// Load an image
let imageURL = Bundle.main.url(forResource: "example", withExtension: "jpg")!
let imageData = try Data(contentsOf: imageURL)

do {
    let response = try await client.generateContent(
        model: .gemini25Pro,
        prompt: "Describe this image in detail",
        imageData: imageData,
        mimeType: "image/jpeg"
    )
    print(response.text)
} catch {
    print("Error: \(error)")
}
```

### 4. **Audio Transcription**

```swift
let audioURL = Bundle.main.url(forResource: "recording", withExtension: "mp3")!

do {
    // Using the enhanced audio manager
    let audioManager = GeminiAudioManager(client: client)
    let result = try await audioManager.transcribe(audioFileURL: audioURL)
    print("Transcription: \(result.transcription)")
    
    // Get audio analysis
    let analysis = try await audioManager.analyze(
        audioFileURL: audioURL,
        prompt: "What is being discussed in this audio?"
    )
    print("Analysis: \(analysis.text)")
} catch {
    print("Error: \(error)")
}
```

### 5. **Document Upload & Chat**

```swift
let documentURL = Bundle.main.url(forResource: "report", withExtension: "pdf")!

do {
    // Upload document
    let uploader = GeminiDocumentUploader(client: client)
    let file = try await uploader.upload(documentURL: documentURL)
    
    // Chat with the document
    let conversationManager = GeminiDocumentConversationManager(client: client)
    let response = try await conversationManager.sendMessage(
        "Summarize this document",
        toFile: file
    )
    print(response.text)
} catch {
    print("Error: \(error)")
}
```

### 6. **Structured Output**

```swift
// Define your Codable type
struct Recipe: Codable {
    let name: String
    let ingredients: [String]
    let cookingTime: Int
}

// Generate structured output
do {
    let recipes: [Recipe] = try await client.generateStructuredOutput(
        model: .gemini25Flash,
        prompt: "Give me 3 cookie recipes",
        schema: .from(type: Recipe.self)
    )
    
    for recipe in recipes {
        print("- \(recipe.name) (\(recipe.cookingTime) min)")
    }
} catch {
    print("Error: \(error)")
}
```

### 7. **Search with Grounding**

```swift
do {
    let response = try await client.generateContentWithSearch(
        model: .gemini25Pro,
        prompt: "What are the latest developments in quantum computing?"
    )
    
    print("Answer: \(response.text)")
    
    // Check grounding metadata
    if let grounding = response.groundingMetadata {
        print("Sources:")
        for chunk in grounding.groundingChunks {
            print("- \(chunk.web.title): \(chunk.web.uri)")
        }
    }
} catch {
    print("Error: \(error)")
}
```

## Supported Models

- **Gemini 2.5 Pro** (`gemini-2.5-pro`) - Most capable model
- **Gemini 2.5 Flash** (`gemini-2.5-flash`) - Balanced performance
- **Gemini 2.5 Flash Lite** (`gemini-2.5-flash-lite`) - Lightweight version
- **Gemini Live** (`gemini-live-2.5-flash-preview`) - Live conversation preview
- **Audio Models** - Native audio dialog and thinking models
- **Image Preview** (`gemini-2.5-flash-image-preview`) - Image-optimized
- **Embedding** (`gemini-embedding-001`) - Embedding model

## API Reference

### GeminiClient

The main client for all API operations.

```swift
// Initialize
let client = GeminiClient(apiKey: "your-api-key")

// Generate text
func generateText(
    model: Model,
    prompt: String,
    systemInstruction: String? = nil,
    temperature: Double? = nil,
    maxOutputTokens: Int? = nil,
    topP: Double? = nil,
    topK: Int? = nil
) async throws -> GenerateContentResponse

// Generate with images
func generateContent(
    model: Model,
    prompt: String,
    imageData: Data,
    mimeType: String
) async throws -> GenerateContentResponse

// Create conversation
func createConversation(
    model: Model,
    systemInstruction: String? = nil
) -> GeminiConversationManager

// And more...
```

### Configuration Options

```swift
// Configure client
client.logLevel = .debug
client.enableSearchTools = true
client.maxRetries = 3
client.timeout = 30.0

// Safety settings
client.safetySettings = [
    SafetySetting(category: .harassment, threshold: .blockNone),
    SafetySetting(category: .hateSpeech, threshold: .blockNone)
]
```

## Testing

The library includes a comprehensive test suite:

```bash
# Set your API key
export GEMINI_API_KEY=your_api_key_here

# Run all tests
swift test

# Run interactive test runner
swift run GeminiTestRunner

# Run specific test
swift test --filter gemini_swfitTests.AudioTests
```

### Test Runner

The interactive test runner includes 11 test scenarios:
1. Basic text generation
2. Image understanding
3. Conversation management
4. Search functionality
5. Document upload
6. Audio recognition
7. Video understanding
8. And more...

## Examples

See the `Sources/GeminiTestRunner/` directory for comprehensive examples of all features.

## Project Structure

```
Sources/gemini-swfit/
├── GeminiClient.swift              # Main client
├── Models/                         # API models
├── Audio/                          # Audio processing
├── Document/                       # Document handling
├── Video/                          # Video processing
├── Schema/                         # JSON Schema
├── API/                            # API management
├── Extensions/                     # Feature extensions
└── Utils/                          # Utilities
```

## Architecture

- **Swift 6 Concurrency**: Full async/await support with strict data isolation
- **Modular Design**: Clean separation of concerns with feature-based organization
- **Protocol-Oriented**: Extensible design with protocol-based interfaces
- **Thread-Safe**: All operations are thread-safe with proper synchronization
- **Resource Management**: Automatic cleanup and efficient memory usage

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Google Gemini AI API
- SwiftyBeaver logging framework
- Swift community

## Support

- [Documentation](docs/)
- [Issues](https://github.com/huifer/gemini-swift/issues)
- [Examples](Sources/GeminiTestRunner/)

---

**Note**: This library is not officially affiliated with Google. It's a community-driven Swift implementation of the Gemini API.