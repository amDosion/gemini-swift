# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a production-ready Swift Package Manager (SPM) library providing comprehensive integration with Google's Gemini AI API. The library supports text generation, multi-turn conversations, multimodal processing (text+images), audio transcription, document upload, search integration, and structured output with JSON Schema generation.

## Development Environment

- **Language**: Swift 6.1+ with Swift 6 concurrency mode enabled
- **Package Manager**: Swift Package Manager
- **Platforms**: macOS 12+, iOS 15+, watchOS 8+, tvOS 15+
- **Dependencies**: SwiftyBeaver (logging framework)
- **IDE Support**: Generate Xcode project with `swift package generate-xcodeproj`

## Common Development Commands

### Build Commands
```bash
# Build the package
swift build

# Build for release
swift build -c release

# Run unit tests
swift test

# Run specific test class
swift test --filter gemini_swfitTests.GeminiClientTests

# Run test runner (interactive menu)
swift run GeminiTestRunner

# Generate Xcode project
swift package generate-xcodeproj

# Update dependencies
swift package update

# Resolve dependencies
swift package resolve

# Clean build artifacts
swift package clean
```

### Testing Commands
```bash
# Set API key for testing
export GEMINI_API_KEY=your_api_key_here

# Run audio-specific tests
./scripts/test_audio.sh

# Run test runner with specific test
swift run GeminiTestRunner
# Then select option 1-10 from the menu
```

## Architecture Overview

### Core Components

1. **GeminiClient** (`Sources/gemini-swfit/GeminiClient.swift`)
   - Main API client with full Gemini integration
   - Supports multiple API keys with automatic rotation
   - Thread-safe implementation with Swift 6 concurrency

2. **Modular Structure**
   - **Models/**: All API data models and request/response types
   - **API/**: API key management and authentication
   - **Audio/**: Audio processing, transcription, and analysis
   - **Document/**: Document upload and conversation management
   - **Schema/**: JSON Schema generation for structured output
   - **Extensions/**: Specialized extensions for audio and sessions
   - **Utils/**: Logging and utility functions

3. **Test Runner** (`Sources/GeminiTestRunner/`)
   - Interactive test runner with 10 different test scenarios
   - Covers all major features: text, images, audio, documents, search
   - Examples of proper API usage for each feature

### Key Features Architecture

- **Multi-model Support**: Gemini 2.5 Pro/Flash/Lite with dynamic model selection
- **Conversation Management**: Built-in history tracking with session management
- **Multimodal Processing**: Simultaneous text and image analysis
- **Audio Processing**: Full audio transcription with multiple format support
- **Search Integration**: Google Search with grounding metadata
- **Structured Output**: Dynamic JSON Schema generation and validation
- **Error Handling**: Comprehensive error types and retry mechanisms
- **Logging**: Integrated SwiftyBeaver logging with configurable levels

### File Organization Patterns

- Feature-based modular organization under `Sources/gemini-swfit/`
- Each major feature has its own directory with related functionality
- Extensions follow `GeminiClient+Feature.swift` naming pattern
- Test files mirror source structure in `Tests/gemini-swfitTests/`
- Example and test code in `Sources/GeminiTestRunner/`

## Testing Strategy

### Test Structure
- **Unit Tests**: Individual component testing in `Tests/gemini-swfitTests/`
- **Integration Tests**: Full API workflow testing via GeminiTestRunner
- **Resource-based Tests**: Audio files, images, and documents for realistic testing

### Running Tests
1. Set `GEMINI_API_KEY` environment variable
2. Use `swift test` for unit tests
3. Use `swift run GeminiTestRunner` for integration tests
4. Specific feature tests available via interactive menu

## Build System Details

- **Dynamic Library**: Configured for dynamic linking across platforms
- **Resource Bundling**: Test assets properly bundled for both test and executable targets
- **Swift 6 Mode**: Full concurrency support with strict data isolation
- **Multi-platform**: Unified codebase supporting all Apple platforms

## Development Guidelines

### Code Patterns
- Use async/await for all API operations
- Follow Swift 6 strict concurrency model
- Implement proper error handling with custom error types
- Use protocol-oriented design for extensibility
- Maintain comprehensive documentation for public APIs

### API Key Management
- Never commit API keys to the repository
- Use environment variable `GEMINI_API_KEY` for testing
- Library supports multiple API keys with automatic rotation
- API keys managed thread-safe with internal rotation logic

### Adding New Features
1. Create feature directory under `Sources/gemini-swfit/`
2. Add models to appropriate feature directory or `Models/`
3. Extend `GeminiClient` with new methods using extension pattern
4. Add comprehensive tests in `Tests/gemini-swfitTests/`
5. Add example to `GeminiTestRunner` for integration testing