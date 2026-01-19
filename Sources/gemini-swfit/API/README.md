# API Module

This module provides API key management, authentication utilities, and third-party provider support for the Gemini API.

## Architecture

```
API/
├── GeminiAPIKeyManager.swift  # API key rotation and quota management
├── GeminiAPIProvider.swift    # Third-party API provider support
└── README.md                  # This file
```

## Components

### GeminiAPIProvider

Support for third-party API providers:
- Google Gemini (official)
- OpenRouter
- Together AI
- Fireworks AI
- Custom/self-hosted endpoints

### GeminiAPIKeyManager

Advanced API key management:
- Multiple API key support
- Automatic key rotation
- Quota tracking per key
- Rate limit handling
- Key health monitoring

## Features

### Key Rotation

Automatically rotates through multiple API keys to:
- Distribute load across keys
- Handle rate limits gracefully
- Maximize available quota

### Quota Management

Track and manage API quotas:
- Monitor usage per key
- Switch to keys with available quota
- Alert on quota exhaustion

### Health Monitoring

Monitor key health:
- Track error rates per key
- Temporarily disable failing keys
- Automatic recovery

## Usage Examples

### Basic Key Management

```swift
let keyManager = GeminiAPIKeyManager(apiKeys: [
    "key1",
    "key2",
    "key3"
])

// Get next available key
let key = keyManager.getNextKey()

// Report usage
keyManager.reportUsage(key: key, tokens: 1000)

// Report error
keyManager.reportError(key: key, error: someError)
```

### Quota-Aware Key Selection

```swift
// Get key with most available quota
let key = keyManager.getKeyWithMostQuota()

// Check if quota is available
if keyManager.hasQuotaAvailable(key: key) {
    // Proceed with request
}
```

### Health-Based Selection

```swift
// Get healthiest key
let key = keyManager.getHealthiestKey()

// Get all healthy keys
let healthyKeys = keyManager.getHealthyKeys()
```

## Configuration

```swift
let config = APIKeyManagerConfig(
    rotationStrategy: .roundRobin,  // or .leastUsed, .random
    quotaPerKey: 1_000_000,         // tokens per day
    errorThreshold: 5,              // errors before disabling
    recoveryInterval: 300           // seconds before retry
)

let keyManager = GeminiAPIKeyManager(
    apiKeys: keys,
    config: config
)
```

## Thread Safety

All operations are thread-safe using concurrent dispatch queues with barriers for write operations.

## Third-Party Provider Support

### Using Google's Official API

```swift
let client = GeminiClient(apiKey: "YOUR_GOOGLE_API_KEY")
```

### Using OpenRouter

```swift
let client = GeminiClient.withOpenRouter(apiKey: "YOUR_OPENROUTER_KEY")

// Or manually
let provider = GeminiAPIProvider.openRouter(apiKey: "YOUR_KEY")
let client = GeminiClient(provider: provider)
```

### Using Together AI

```swift
let client = GeminiClient.withTogetherAI(apiKey: "YOUR_TOGETHER_KEY")
```

### Using Custom Third-Party URL

```swift
let client = GeminiClient(
    thirdPartyURL: "https://your-api-endpoint.com/v1/",
    apiKey: "YOUR_API_KEY",
    authScheme: .bearerToken  // or .queryParameter, .xApiKey
)
```

### Using Self-Hosted Endpoint

```swift
guard let provider = GeminiAPIProvider.selfHosted(
    baseURL: "http://localhost:8080/api/",
    apiKey: "optional-key"
) else { return }

let client = GeminiClient(provider: provider)
```

### Custom Provider with Full Configuration

```swift
let provider = GeminiAPIProvider(
    name: "My Custom Provider",
    baseURL: URL(string: "https://api.example.com/v1/")!,
    apiKeys: ["key1", "key2"],
    customHeaders: [
        "X-Custom-Header": "value"
    ],
    authScheme: .bearerToken,
    modelMapping: [
        "gemini-2.5-flash": "custom-model-name"
    ]
)

let client = GeminiClient(provider: provider)
```

### Managing Multiple Providers

```swift
let manager = GeminiProviderManager()

// Register providers
manager.register(GeminiAPIProvider.google(apiKey: "google-key"))
manager.register(GeminiAPIProvider.openRouter(apiKey: "openrouter-key"))

// Switch between providers
manager.setCurrentProvider("OpenRouter")

// Get provider
if let provider = manager.defaultProvider {
    let client = GeminiClient(provider: provider)
}
```

## Authentication Schemes

| Scheme | Header/Location | Example |
|--------|-----------------|---------|
| `queryParameter` | `?key=API_KEY` | Google Gemini |
| `bearerToken` | `Authorization: Bearer KEY` | OpenRouter, Together AI |
| `xApiKey` | `X-API-Key: KEY` | Some custom APIs |
| `customHeader` | Use `customHeaders` | Custom implementations |
