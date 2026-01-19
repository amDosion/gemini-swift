# Core Module

This module provides foundational components used across all other modules.

## Architecture

```
Core/
├── GeminiBaseUploader.swift    # Base class for all file uploaders
├── GeminiCacheManager.swift    # Response caching
├── GeminiRequestTracing.swift  # Request tracing and debugging
├── GeminiRetryConfig.swift     # Retry logic configuration
└── README.md                   # This file
```

## Components

### GeminiBaseUploader

Base class for all media uploaders:
- Resumable upload support
- Chunked uploads for large files
- Session management
- File validation
- Processing status tracking

### GeminiCacheManager

Response caching for improved performance:
- Configurable TTL
- LRU eviction
- Cache key generation
- Multiple cache strategies

### GeminiRequestTracing

Request tracing for debugging and monitoring:
- Request ID generation
- Metadata injection
- Trace context propagation
- Logging integration

### GeminiRetryConfig

Configurable retry logic:
- Exponential backoff
- Max retry attempts
- Jitter support
- Status code handling

## Usage Examples

### Custom Uploader

```swift
class MyCustomUploader: GeminiBaseUploader {
    func uploadMyFile(at url: URL, session: GeminiUploadSession) async throws -> GeminiFileInfo {
        return try await uploadFile(
            at: url,
            displayName: url.lastPathComponent,
            mimeType: "application/octet-stream",
            apiKey: session.apiKey,
            waitForProcessing: true
        )
    }
}
```

### Caching

```swift
let cacheManager = GeminiCacheManager(
    config: GeminiCacheConfig(
        ttl: 3600,           // 1 hour
        maxEntries: 1000,
        strategy: .default
    )
)

// Cache a response
cacheManager.set(key: cacheKey, value: response)

// Retrieve from cache
if let cached = cacheManager.get(key: cacheKey) {
    return cached
}
```

### Retry Configuration

```swift
let retryConfig = GeminiRetryConfig(
    maxRetries: 3,
    initialDelay: 1.0,
    maxDelay: 30.0,
    multiplier: 2.0,
    jitter: 0.1
)

// Use with retry logic
try await withRetry(config: retryConfig) {
    try await makeRequest()
}
```

### Request Tracing

```swift
let tracing = GeminiRequestTracing()

// Start a trace
let traceId = tracing.startTrace(operation: "generateContent")

// Add metadata
tracing.addMetadata(traceId: traceId, key: "model", value: "gemini-2.5-flash")

// Complete trace
tracing.endTrace(traceId: traceId, status: .success)
```

## Common Types

### GeminiUploadSession

```swift
struct GeminiUploadSession {
    let sessionID: String
    let apiKey: String
    let mediaType: MediaType
    var uploadedFiles: [GeminiFileInfo]
    let createdAt: Date
}
```

### GeminiFileInfo

```swift
struct GeminiFileInfo {
    let name: String
    let displayName: String?
    let mimeType: String?
    let sizeBytes: String?
    let uri: String
    let state: String?
}
```

### GeminiUploadError

```swift
enum GeminiUploadError: Error {
    case invalidURL
    case fileNotFound
    case metadataExtractionFailed
    case uploadInitiationFailed(Error)
    case uploadFailed(Error)
    case invalidUploadResponse
    case sessionExpired
    case invalidFileFormat(String)
    case processingTimeout
    case processingFailed(String)
}
```

## Thread Safety

All core components are designed for concurrent access using appropriate synchronization mechanisms.
