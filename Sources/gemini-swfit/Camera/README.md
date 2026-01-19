# Camera Module

This module provides camera capture and photo editing capabilities integrated with the Gemini API.

## Architecture

```
Camera/
├── GeminiCameraManager.swift  # Camera capture and photo editing coordinator
└── README.md                  # This file
```

## Components

### GeminiCameraManager

High-level coordinator for camera and photo operations:
- Camera permission handling
- Photo capture processing
- Integration with image conversation editing
- Multi-step editing workflows
- Photo analysis

## Features

### Photo Processing
- Image format conversion (JPEG, PNG)
- Quality adjustment
- Resize to max dimensions
- Orientation correction

### Conversation-Based Editing
- Start editing sessions with captured photos
- Send natural language editing instructions
- Multi-turn editing with context preservation
- Get editing history

### Quick Operations
- Quick single-step edits
- Multi-step sequential edits
- Batch photo analysis

## Usage Examples

### Initialize Manager

```swift
let client = GeminiClient(apiKey: "YOUR_API_KEY")
let cameraManager = GeminiCameraManager(client: client)
```

### Process Photo and Start Editing

```swift
// From photo library or camera
let imageData: Data = ... // Get from UIImagePickerController, PHPickerViewController, etc.

// Process and start editing session
let (photo, sessionId) = try cameraManager.processAndStartEditing(
    imageData: imageData,
    config: .default
)

// Send editing instructions
let response = try await cameraManager.sendEditInstruction(
    "Make the colors more vibrant",
    sessionId: sessionId
)

// Get the edited image
if let editedImage = response.image {
    // Use the edited image
}

// Continue editing
let response2 = try await cameraManager.sendEditInstruction(
    "Now add a subtle vignette effect",
    sessionId: sessionId
)

// End session when done
cameraManager.endEditingSession(sessionId)
```

### Quick Edit (Single Instruction)

```swift
let editedImage = try await cameraManager.quickEdit(
    imageData: photoData,
    instruction: "Remove the background"
)
```

### Multi-Step Edit

```swift
let finalImage = try await cameraManager.multiStepEdit(
    imageData: photoData,
    instructions: [
        "Increase the brightness",
        "Add a warm color filter",
        "Sharpen the details"
    ]
)
```

### Analyze Photo

```swift
let description = try await cameraManager.analyzePhoto(
    photo,
    prompt: "What objects are in this image?"
)
```

## Capture Configuration

```swift
let config = GeminiCameraManager.CaptureConfig(
    quality: 0.8,           // JPEG quality (0.0-1.0)
    maxDimension: 2048,     // Max width or height
    format: .jpeg,          // Output format
    correctOrientation: true
)

// Predefined configs
let highQuality = CaptureConfig.highQuality   // 4096px, PNG
let lowBandwidth = CaptureConfig.lowBandwidth // 1024px, 50% quality
```

## Camera Permissions (iOS)

```swift
// Check availability
if cameraManager.isCameraAvailable {
    // Request permission
    let granted = await cameraManager.requestCameraPermission()
    if granted {
        // Camera ready to use
    }
}
```

## Integration with UIKit

```swift
// In your UIImagePickerControllerDelegate
func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
) {
    guard let image = info[.originalImage] as? UIImage,
          let imageData = image.jpegData(compressionQuality: 0.8) else {
        return
    }

    Task {
        let (photo, sessionId) = try cameraManager.processAndStartEditing(
            imageData: imageData
        )
        // Start editing...
    }
}
```

## Conversation History

```swift
// Get editing history for a session
let history = cameraManager.getEditHistory(sessionId: sessionId)

for message in history {
    switch message.role {
    case .user:
        print("User: \(message.text ?? "")")
    case .model:
        print("AI: \(message.text ?? "")")
        if message.imageData != nil {
            print("  (includes edited image)")
        }
    }
}
```

## Best Practices

1. **End sessions when done** - Free up resources
2. **Use appropriate quality** - Lower quality for previews, higher for final output
3. **Process images before editing** - Ensure consistent format and size
4. **Handle errors gracefully** - Camera permission, processing failures
5. **Keep instructions clear** - Better results with specific instructions
