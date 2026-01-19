# Utils Module

This module provides utility classes and helper functions used throughout the library.

## Architecture

```
Utils/
├── GeminiLogger.swift  # SwiftyBeaver logging integration
└── README.md           # This file
```

## Components

### GeminiLogger

Centralized logging using SwiftyBeaver:
- Console output with colors
- File logging (optional)
- Configurable log levels
- Thread-safe logging

## Usage Examples

### Basic Logging

```swift
import SwiftyBeaver

let logger = SwiftyBeaver.self

// Log at different levels
logger.verbose("Detailed debug info")
logger.debug("Debug message")
logger.info("Informational message")
logger.warning("Warning message")
logger.error("Error message")
```

### Logger Setup

The logger is automatically configured when creating a `GeminiClient`:

```swift
let client = GeminiClient(apiKey: "YOUR_API_KEY")
// Logger is already set up
```

### Custom Logger Configuration

```swift
let console = ConsoleDestination()
console.minLevel = .debug
console.format = "$DHH:mm:ss$d $L $M"

let file = FileDestination()
file.logFileURL = URL(fileURLWithPath: "/tmp/gemini.log")
file.minLevel = .warning

SwiftyBeaver.addDestination(console)
SwiftyBeaver.addDestination(file)
```

### Log Levels

| Level | Use Case |
|-------|----------|
| verbose | Detailed debugging (function entry/exit) |
| debug | Development debugging |
| info | Normal operation events |
| warning | Potential issues |
| error | Errors and failures |

### Structured Logging

```swift
logger.info("Request completed", context: [
    "model": "gemini-2.5-flash",
    "tokens": 1234,
    "duration": 0.5
])
```

## Log Output Format

Default console format:
```
10:30:45.123 INFO [GeminiClient.swift:142] Request completed
```

With context:
```
10:30:45.123 INFO [GeminiClient.swift:142] Request completed {model: gemini-2.5-flash, tokens: 1234}
```

## Configuration Options

```swift
let console = ConsoleDestination()

// Minimum log level
console.minLevel = .info

// Custom format
console.format = "$DHH:mm:ss.SSS$d $C$L$c $N.$F:$l - $M"

// Format tokens:
// $D....$d - Date/time
// $L - Log level
// $C...$c - Color (start/end)
// $N - File name
// $F - Function name
// $l - Line number
// $M - Message
```

## Best Practices

1. **Use appropriate levels** - Don't log everything as `error`
2. **Include context** - Add relevant data to log messages
3. **Avoid sensitive data** - Never log API keys or user data
4. **Configure for environment** - Use `debug` for development, `warning` for production
5. **Rotate log files** - Configure file rotation for long-running applications
