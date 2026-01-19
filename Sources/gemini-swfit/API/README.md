# API Module

This module provides API key management and authentication utilities for the Gemini API.

## Architecture

```
API/
├── GeminiAPIKeyManager.swift  # API key rotation and quota management
└── README.md                  # This file
```

## Components

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
