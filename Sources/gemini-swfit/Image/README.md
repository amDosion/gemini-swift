# Image Module

This module provides comprehensive image generation and editing capabilities using Google's Gemini and Imagen APIs.

## Architecture

The Image module follows a modular architecture with clear separation of concerns:

```
Image/
├── GeminiImageModels.swift    # All image-related types and configurations
├── GeminiImageUploader.swift  # Image file upload handling
├── GeminiImageGenerator.swift # Image generation (Gemini & Imagen)
├── GeminiImageEditor.swift    # Image editing (inpaint, outpaint, style)
├── GeminiImageManager.swift   # High-level coordinator
└── README.md                  # This file
```

Additionally, `GeminiClient+Image.swift` in the Extensions directory provides convenient access from the main client.

## Components

### GeminiImageModels

Contains all type definitions:
- `ImageGenerationModel` - Supported models (Gemini 2.5 Flash Image, Gemini 3 Pro Image, Imagen 3)
- `ImageEditingModel` - Models for editing operations
- `ImageGenerationConfig` - Configuration for generation
- `ImageEditingConfig` - Configuration for editing (inpaint/outpaint)
- `GeneratedImage` - Generated image data and metadata
- `ImageAspectRatio` - Supported aspect ratios
- `ImageResolution` - Output resolutions (1K, 2K, 4K)
- `GeminiImageError` - Error types

### GeminiImageUploader

Handles image file uploads:
- Validate image formats
- Extract metadata
- Upload to Gemini API
- Session management

### GeminiImageGenerator

Handles image generation:
- Gemini-based generation (responseModalities)
- Imagen-based generation
- Reference image support
- Multiple images
- High-resolution output

### GeminiImageEditor

Handles image editing:
- Natural language editing (Gemini)
- Inpainting (insert/remove content)
- Outpainting (expand boundaries)
- Style transfer
- Quality enhancement
- Colorization
- Upscaling

### GeminiImageManager

High-level coordinator that:
- Combines all components
- Manages API key rotation
- Provides session-based operations
- Handles batch operations

## Usage Examples

### Basic Image Generation

```swift
let client = GeminiClient(apiKey: "YOUR_API_KEY")

// Generate a single image
let image = try await client.generateImage(
    prompt: "A serene mountain landscape at sunset",
    model: .gemini25FlashImage,
    aspectRatio: .landscape16x9
)

// Save to file
try image.data.write(to: URL(fileURLWithPath: "output.png"))
```

### Multiple Images

```swift
let images = try await client.generateImages(
    prompt: "A futuristic cityscape",
    count: 4,
    model: .gemini25FlashImage,
    aspectRatio: .square
)
```

### High-Resolution Generation

```swift
let hrImage = try await client.generateHighResolutionImage(
    prompt: "Detailed portrait of a renaissance painting",
    resolution: .resolution4K,
    model: .gemini3ProImagePreview
)
```

### Image Editing

```swift
// Edit with natural language
let editedImage = try await client.editImage(
    instructions: "Make the sky more dramatic with storm clouds",
    imageData: originalImageData,
    imageMimeType: "image/jpeg"
)

// Style transfer
let stylizedImage = try await client.applyStyle(
    styleDescription: "Van Gogh's Starry Night painting style",
    imageData: originalImageData
)

// Background removal
let noBackground = try await client.removeBackground(imageData: originalImageData)
```

### Inpainting

```swift
// Insert content
let insertedImages = try await client.inpaintInsert(
    prompt: "Add a red sports car",
    imageData: originalImageData,
    maskData: maskImageData,
    numberOfImages: 2
)

// Remove content
let removedImages = try await client.inpaintRemove(
    prompt: "Remove the person",
    imageData: originalImageData,
    maskData: maskImageData
)
```

### Outpainting

```swift
let expandedImages = try await client.outpaint(
    prompt: "Continue the landscape with more mountains and trees",
    imageData: originalImageData,
    outputAspectRatio: .landscape16x9,
    numberOfImages: 2
)
```

### Using the Image Manager Directly

```swift
let client = GeminiClient(apiKey: "YOUR_API_KEY")
let imageManager = client.createImageManager()

// Custom configuration
let config = ImageGenerationConfig(
    numberOfImages: 2,
    aspectRatio: .portrait9x16,
    resolution: .resolution2K,
    outputFormat: .png,
    negativePrompt: "blurry, low quality",
    safetyFilterLevel: .blockMediumAndAbove,
    personFilterLevel: .allowAdult,
    addWatermark: true
)

let response = try await imageManager.generateImage(
    prompt: "Professional headshot portrait",
    model: .gemini3ProImagePreview,
    config: config
)
```

### Session-Based Operations

```swift
let client = GeminiClient(apiKey: "YOUR_API_KEY")
let session = client.startImageSession()
defer { client.endImageSession(session) }

// All operations use the same API key
let image1 = try await client.generateImage(
    prompt: "First image",
    session: session
)

let image2 = try await client.editImage(
    instructions: "Modify the image",
    imageData: image1.data,
    session: session
)
```

## Supported Models

### Image Generation Models

| Model | Description | Features |
|-------|-------------|----------|
| `gemini25FlashImage` | Gemini 2.5 Flash Image | Fast, multimodal, editing support |
| `gemini25FlashImagePreview` | Gemini 2.5 Flash Image Preview | Preview version |
| `gemini3ProImagePreview` | Gemini 3 Pro Image | High quality, 4K support |
| `imagen3` | Imagen 3 | State-of-the-art generation |
| `imagen3Fast` | Imagen 3 Fast | Faster variant |

### Image Editing Models

| Model | Description |
|-------|-------------|
| `imagen3Capability` | Imagen 3 Capability | Inpainting, outpainting |

## Configuration Options

### ImageGenerationConfig

```swift
ImageGenerationConfig(
    numberOfImages: 1,           // 1-4 images
    aspectRatio: .square,        // See ImageAspectRatio
    resolution: .resolution2K,   // 1K, 2K, 4K
    outputFormat: .png,          // PNG, JPEG, WebP
    negativePrompt: nil,         // What to avoid
    safetyFilterLevel: .blockMediumAndAbove,
    personFilterLevel: .allowAdult,
    addWatermark: true,
    includeRAIReason: false,
    language: nil
)
```

### ImageEditingConfig

```swift
// Inpainting
ImageEditingConfig.inpaint(
    maskData: maskData,
    insertContent: true,
    numberOfImages: 1
)

// Outpainting
ImageEditingConfig.outpaint(
    outputAspectRatio: .landscape16x9,
    blendingFactor: 0.01,
    numberOfImages: 1
)
```

## Aspect Ratios

| Ratio | Description |
|-------|-------------|
| `square` | 1:1 |
| `portrait3x4` | 3:4 |
| `portrait4x5` | 4:5 |
| `portrait9x16` | 9:16 (vertical) |
| `landscape4x3` | 4:3 |
| `landscape5x4` | 5:4 |
| `landscape16x9` | 16:9 (horizontal) |
| `landscape3x2` | 3:2 |
| `landscape2x3` | 2:3 |
| `ultrawide21x9` | 21:9 |

## Error Handling

```swift
do {
    let image = try await client.generateImage(prompt: "...")
} catch GeminiImageError.safetyFilterBlocked(let reason) {
    print("Content blocked: \(reason)")
} catch GeminiImageError.quotaExceeded {
    print("API quota exceeded")
} catch GeminiImageError.generationFailed(let reason) {
    print("Generation failed: \(reason)")
} catch {
    print("Error: \(error)")
}
```

## Thread Safety

All components are designed for concurrent use:
- API key rotation is thread-safe
- Session management uses concurrent queues
- All async methods are safe to call from any context

## Best Practices

1. **Use sessions for batch operations** - Maintains consistent API key usage
2. **Handle safety filter blocks** - Some prompts may be blocked
3. **Choose appropriate models** - Use Gemini for editing, Imagen for pure generation
4. **Set appropriate resolution** - Higher resolution costs more
5. **Use negative prompts** - Improve quality by specifying what to avoid
