# Models Module

This module contains all data models for API requests and responses.

## Architecture

```
Models/
├── GeminiModels.swift  # All request/response models
└── README.md           # This file
```

## Request Models

### GeminiGenerateContentRequest

Main request structure for content generation:

```swift
struct GeminiGenerateContentRequest {
    let contents: [Content]
    let systemInstruction: SystemInstruction?
    let generationConfig: GenerationConfig?
    let safetySettings: [SafetySetting]?
    let tools: [Tool]?
}
```

### Content

Represents a message in a conversation:

```swift
struct Content {
    let role: Role?     // .user or .model
    let parts: [Part]   // Text, images, files, etc.
}
```

### Part

Individual content part:

```swift
struct Part {
    let text: String?
    let inlineData: InlineData?      // Base64 encoded media
    let fileData: FileData?          // Uploaded file reference
    let functionCall: FunctionCall?
    let functionResponse: FunctionResponse?
}
```

### GenerationConfig

Control generation parameters:

```swift
struct GenerationConfig {
    let candidateCount: Int?
    let stopSequences: [String]?
    let maxOutputTokens: Int?
    let temperature: Double?
    let topP: Double?
    let topK: Int?
    let responseMimeType: String?
    let responseSchema: String?
}
```

### SafetySetting

Configure safety filters:

```swift
struct SafetySetting {
    let category: SafetyCategory
    let threshold: SafetyThreshold
}

enum SafetyCategory {
    case harassment
    case hateSpeech
    case sexuallyExplicit
    case dangerousContent
}

enum SafetyThreshold {
    case blockNone
    case blockFew
    case blockSome
    case blockMost
}
```

## Response Models

### GeminiGenerateContentResponse

Main response structure:

```swift
struct GeminiGenerateContentResponse {
    let candidates: [Candidate]
    let promptFeedback: PromptFeedback?
}
```

### Candidate

A single response candidate:

```swift
struct Candidate {
    let content: Content
    let finishReason: FinishReason?
    let safetyRatings: [SafetyRating]?
    let citationMetadata: CitationMetadata?
    let groundingMetadata: GroundingMetadata?
}
```

### GroundingMetadata

Search grounding information:

```swift
struct GroundingMetadata {
    let webSearchQueries: [String]?
    let searchEntryPoint: SearchEntryPoint?
    let groundingChunks: [GroundingChunk]?
    let groundingSupports: [GroundingSupport]?
}
```

## Tool Models

### Tool

External tools for enhanced responses:

```swift
struct Tool {
    let googleSearch: GoogleSearch?
    let urlContext: UrlContext?

    static func googleSearch() -> Tool
    static func urlContext() -> Tool
}
```

## Embedding Models

### GeminiEmbeddingRequest/Response

For generating text embeddings:

```swift
struct GeminiEmbeddingRequest {
    let model: String
    let content: Content
    let taskType: EmbeddingTaskType?
    let title: String?
}

struct GeminiEmbeddingResponse {
    let embedding: [Float]
}
```

## Usage Examples

### Creating a Request

```swift
let request = GeminiGenerateContentRequest(
    contents: [
        Content(role: .user, parts: [Part(text: "Hello")])
    ],
    systemInstruction: SystemInstruction(text: "Be helpful"),
    generationConfig: GenerationConfig(
        maxOutputTokens: 1000,
        temperature: 0.7
    ),
    safetySettings: [
        SafetySetting(
            category: .harassment,
            threshold: .blockMediumAndAbove
        )
    ],
    tools: [Tool.googleSearch()]
)
```

### Parsing a Response

```swift
let response: GeminiGenerateContentResponse = try await client.generateContent(...)

if let candidate = response.candidates.first,
   let text = candidate.content.parts.first?.text {
    print(text)
}

// Check for grounding
if let grounding = candidate.groundingMetadata,
   let chunks = grounding.groundingChunks {
    for chunk in chunks {
        if let web = chunk.web {
            print("Source: \(web.title ?? "Unknown") - \(web.uri ?? "")")
        }
    }
}
```

## Codable Conformance

All models conform to `Codable` for easy JSON serialization:

```swift
let encoder = JSONEncoder()
let data = try encoder.encode(request)

let decoder = JSONDecoder()
let response = try decoder.decode(GeminiGenerateContentResponse.self, from: data)
```
