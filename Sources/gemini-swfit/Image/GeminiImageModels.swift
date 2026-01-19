//
//  GeminiImageModels.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-19.
//

import Foundation

// MARK: - Image Generation Models

/// Supported models for image generation
public enum ImageGenerationModel: String, Sendable, CaseIterable {
    /// Gemini 2.5 Flash Image - Fast multimodal image generation
    case gemini25FlashImage = "gemini-2.5-flash-image"
    /// Gemini 2.5 Flash Image Preview
    case gemini25FlashImagePreview = "gemini-2.5-flash-image-preview"
    /// Gemini 3 Pro Image Preview - High quality image generation
    case gemini3ProImagePreview = "gemini-3-pro-image-preview"
    /// Imagen 3 - Google's state-of-the-art image generation
    case imagen3 = "imagen-3.0-generate-002"
    /// Imagen 3 Fast - Faster variant
    case imagen3Fast = "imagen-3.0-fast-generate-001"

    public var displayName: String {
        switch self {
        case .gemini25FlashImage: return "Gemini 2.5 Flash Image"
        case .gemini25FlashImagePreview: return "Gemini 2.5 Flash Image Preview"
        case .gemini3ProImagePreview: return "Gemini 3 Pro Image (Preview)"
        case .imagen3: return "Imagen 3"
        case .imagen3Fast: return "Imagen 3 Fast"
        }
    }

    /// Whether this model supports image editing
    public var supportsEditing: Bool {
        switch self {
        case .gemini25FlashImage, .gemini25FlashImagePreview, .gemini3ProImagePreview:
            return true
        case .imagen3, .imagen3Fast:
            return false
        }
    }

    /// Whether this model requires responseModalities configuration
    public var requiresResponseModalities: Bool {
        switch self {
        case .gemini25FlashImage, .gemini25FlashImagePreview, .gemini3ProImagePreview:
            return true
        case .imagen3, .imagen3Fast:
            return false
        }
    }
}

/// Supported models for image editing (Imagen)
public enum ImageEditingModel: String, Sendable, CaseIterable {
    /// Imagen 3 Capability model for editing
    case imagen3Capability = "imagen-3.0-capability-001"

    public var displayName: String {
        switch self {
        case .imagen3Capability: return "Imagen 3 Capability"
        }
    }
}

// MARK: - Response Modalities

/// Response modalities for image generation
public enum ResponseModality: String, Codable, Sendable {
    case text = "TEXT"
    case image = "IMAGE"
}

// MARK: - Aspect Ratio

/// Supported aspect ratios for image generation
public enum ImageAspectRatio: String, Codable, Sendable, CaseIterable {
    case square = "1:1"
    case portrait3x4 = "3:4"
    case portrait4x5 = "4:5"
    case portrait9x16 = "9:16"
    case landscape4x3 = "4:3"
    case landscape5x4 = "5:4"
    case landscape16x9 = "16:9"
    case landscape3x2 = "3:2"
    case landscape2x3 = "2:3"
    case ultrawide21x9 = "21:9"

    public var displayName: String {
        switch self {
        case .square: return "Square (1:1)"
        case .portrait3x4: return "Portrait (3:4)"
        case .portrait4x5: return "Portrait (4:5)"
        case .portrait9x16: return "Portrait (9:16)"
        case .landscape4x3: return "Landscape (4:3)"
        case .landscape5x4: return "Landscape (5:4)"
        case .landscape16x9: return "Landscape (16:9)"
        case .landscape3x2: return "Landscape (3:2)"
        case .landscape2x3: return "Landscape (2:3)"
        case .ultrawide21x9: return "Ultrawide (21:9)"
        }
    }
}

// MARK: - Image Resolution

/// Supported image resolutions
public enum ImageResolution: String, Codable, Sendable, CaseIterable {
    case resolution1K = "1K"
    case resolution2K = "2K"
    case resolution4K = "4K"

    public var displayName: String {
        switch self {
        case .resolution1K: return "1K"
        case .resolution2K: return "2K"
        case .resolution4K: return "4K"
        }
    }

    /// Approximate pixel count
    public var approximatePixels: Int {
        switch self {
        case .resolution1K: return 1_048_576  // 1024x1024
        case .resolution2K: return 4_194_304  // 2048x2048
        case .resolution4K: return 16_777_216 // 4096x4096
        }
    }
}

// MARK: - Safety Settings

/// Safety filter level for image generation
public enum ImageSafetyFilterLevel: String, Codable, Sendable {
    /// Block few potentially harmful content
    case blockLowAndAbove = "BLOCK_LOW_AND_ABOVE"
    /// Block some potentially harmful content
    case blockMediumAndAbove = "BLOCK_MEDIUM_AND_ABOVE"
    /// Block most potentially harmful content
    case blockOnlyHigh = "BLOCK_ONLY_HIGH"
    /// No content filtering
    case blockNone = "BLOCK_NONE"
}

/// Person generation filter level
public enum ImagePersonFilterLevel: String, Codable, Sendable {
    /// Don't allow generation of images containing people
    case dontAllow = "DONT_ALLOW"
    /// Allow generation of adult people only
    case allowAdult = "ALLOW_ADULT"
    /// Allow generation of all people including children
    case allowAll = "ALLOW_ALL"
}

// MARK: - Image Format

/// Output image format
public enum ImageOutputFormat: String, Codable, Sendable {
    case png = "image/png"
    case jpeg = "image/jpeg"
    case webp = "image/webp"
}

// MARK: - Image Generation Configuration

/// Configuration for image generation
public struct ImageGenerationConfig: Sendable {
    /// Number of images to generate (1-4)
    public let numberOfImages: Int
    /// Aspect ratio of generated images
    public let aspectRatio: ImageAspectRatio
    /// Output resolution
    public let resolution: ImageResolution?
    /// Output format
    public let outputFormat: ImageOutputFormat
    /// Negative prompt (what to avoid)
    public let negativePrompt: String?
    /// Safety filter level
    public let safetyFilterLevel: ImageSafetyFilterLevel
    /// Person generation filter level
    public let personFilterLevel: ImagePersonFilterLevel
    /// Add watermark to generated images
    public let addWatermark: Bool
    /// Include RAI filter reason in response
    public let includeRAIReason: Bool
    /// Language code for prompt interpretation
    public let language: String?

    public init(
        numberOfImages: Int = 1,
        aspectRatio: ImageAspectRatio = .square,
        resolution: ImageResolution? = nil,
        outputFormat: ImageOutputFormat = .png,
        negativePrompt: String? = nil,
        safetyFilterLevel: ImageSafetyFilterLevel = .blockMediumAndAbove,
        personFilterLevel: ImagePersonFilterLevel = .allowAdult,
        addWatermark: Bool = true,
        includeRAIReason: Bool = false,
        language: String? = nil
    ) {
        self.numberOfImages = min(max(numberOfImages, 1), 4)
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.outputFormat = outputFormat
        self.negativePrompt = negativePrompt
        self.safetyFilterLevel = safetyFilterLevel
        self.personFilterLevel = personFilterLevel
        self.addWatermark = addWatermark
        self.includeRAIReason = includeRAIReason
        self.language = language
    }

    /// Create a default configuration
    public static let `default` = ImageGenerationConfig()

    /// Create a high quality configuration
    public static let highQuality = ImageGenerationConfig(
        numberOfImages: 1,
        aspectRatio: .square,
        resolution: .resolution4K,
        outputFormat: .png,
        safetyFilterLevel: .blockMediumAndAbove,
        personFilterLevel: .allowAdult,
        addWatermark: true
    )

    /// Create a fast generation configuration
    public static let fast = ImageGenerationConfig(
        numberOfImages: 1,
        aspectRatio: .square,
        resolution: .resolution1K,
        outputFormat: .jpeg,
        safetyFilterLevel: .blockMediumAndAbove,
        personFilterLevel: .allowAdult,
        addWatermark: false
    )
}

// MARK: - Image Edit Mode

/// Editing mode for image manipulation
public enum ImageEditMode: String, Codable, Sendable {
    /// Insert new content in masked area
    case inpaintInsertion = "EDIT_MODE_INPAINT_INSERTION"
    /// Remove content from masked area
    case inpaintRemoval = "EDIT_MODE_INPAINT_REMOVAL"
    /// Expand image beyond boundaries
    case outpaint = "EDIT_MODE_OUTPAINT"
    /// General editing with prompt
    case default_ = "EDIT_MODE_DEFAULT"
}

/// Mask mode for image editing
public enum ImageMaskMode: String, Codable, Sendable {
    /// User provides the mask image
    case userProvided = "MASK_MODE_USER_PROVIDED"
    /// Auto-detect foreground
    case foreground = "MASK_MODE_FOREGROUND"
    /// Auto-detect background
    case background = "MASK_MODE_BACKGROUND"
    /// Semantic segmentation
    case semantic = "MASK_MODE_SEMANTIC"
}

// MARK: - Image Editing Configuration

/// Configuration for image editing
public struct ImageEditingConfig: Sendable {
    /// Edit mode (inpaint, outpaint, etc.)
    public let editMode: ImageEditMode
    /// Mask mode
    public let maskMode: ImageMaskMode
    /// Mask image data (base64 encoded)
    public let maskImageData: Data?
    /// Mask dilation percentage (0.0 - 1.0)
    public let maskDilation: Double
    /// Number of edit steps (higher = better quality, slower)
    public let editSteps: Int
    /// Number of output images
    public let numberOfImages: Int
    /// Blending mode for outpainting
    public let blendingMode: String?
    /// Blending factor for outpainting (0.0 - 1.0)
    public let blendingFactor: Double?
    /// Output aspect ratio for outpainting
    public let outputAspectRatio: ImageAspectRatio?

    public init(
        editMode: ImageEditMode,
        maskMode: ImageMaskMode = .userProvided,
        maskImageData: Data? = nil,
        maskDilation: Double = 0.03,
        editSteps: Int = 35,
        numberOfImages: Int = 1,
        blendingMode: String? = nil,
        blendingFactor: Double? = nil,
        outputAspectRatio: ImageAspectRatio? = nil
    ) {
        self.editMode = editMode
        self.maskMode = maskMode
        self.maskImageData = maskImageData
        self.maskDilation = min(max(maskDilation, 0.0), 1.0)
        self.editSteps = max(editSteps, 1)
        self.numberOfImages = min(max(numberOfImages, 1), 4)
        self.blendingMode = blendingMode
        self.blendingFactor = blendingFactor.map { min(max($0, 0.0), 1.0) }
        self.outputAspectRatio = outputAspectRatio
    }

    /// Create inpainting configuration
    public static func inpaint(
        maskData: Data,
        insertContent: Bool = true,
        numberOfImages: Int = 1
    ) -> ImageEditingConfig {
        return ImageEditingConfig(
            editMode: insertContent ? .inpaintInsertion : .inpaintRemoval,
            maskMode: .userProvided,
            maskImageData: maskData,
            numberOfImages: numberOfImages
        )
    }

    /// Create outpainting configuration
    public static func outpaint(
        outputAspectRatio: ImageAspectRatio,
        blendingFactor: Double = 0.01,
        numberOfImages: Int = 1
    ) -> ImageEditingConfig {
        return ImageEditingConfig(
            editMode: .outpaint,
            maskMode: .userProvided,
            maskDilation: 0.03,
            editSteps: 35,
            numberOfImages: numberOfImages,
            blendingMode: "alpha-blending",
            blendingFactor: blendingFactor,
            outputAspectRatio: outputAspectRatio
        )
    }

    /// Create foreground removal configuration
    public static func removeForeground(numberOfImages: Int = 1) -> ImageEditingConfig {
        return ImageEditingConfig(
            editMode: .inpaintRemoval,
            maskMode: .foreground,
            numberOfImages: numberOfImages
        )
    }

    /// Create background removal configuration
    public static func removeBackground(numberOfImages: Int = 1) -> ImageEditingConfig {
        return ImageEditingConfig(
            editMode: .inpaintRemoval,
            maskMode: .background,
            numberOfImages: numberOfImages
        )
    }
}

// MARK: - Generated Image

/// Represents a generated image
public struct GeneratedImage: Sendable {
    /// Raw image data
    public let data: Data
    /// MIME type of the image
    public let mimeType: String
    /// Generation seed (if available)
    public let seed: Int?
    /// RAI filter reason (if blocked)
    public let raiFilterReason: String?
    /// Whether the image was filtered
    public let wasFiltered: Bool

    public init(
        data: Data,
        mimeType: String,
        seed: Int? = nil,
        raiFilterReason: String? = nil,
        wasFiltered: Bool = false
    ) {
        self.data = data
        self.mimeType = mimeType
        self.seed = seed
        self.raiFilterReason = raiFilterReason
        self.wasFiltered = wasFiltered
    }

    /// Get base64 encoded string
    public var base64String: String {
        return data.base64EncodedString()
    }

    /// Get file extension based on MIME type
    public var fileExtension: String {
        switch mimeType {
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "image/webp": return "webp"
        default: return "png"
        }
    }
}

// MARK: - Image Generation Response

/// Response from image generation
public struct ImageGenerationResponse: Sendable {
    /// Generated images
    public let images: [GeneratedImage]
    /// Text response (if any)
    public let text: String?
    /// Prompt used for generation
    public let prompt: String
    /// Model used for generation
    public let model: String
    /// Safety ratings
    public let safetyRatings: [ImageSafetyRating]?

    public init(
        images: [GeneratedImage],
        text: String? = nil,
        prompt: String,
        model: String,
        safetyRatings: [ImageSafetyRating]? = nil
    ) {
        self.images = images
        self.text = text
        self.prompt = prompt
        self.model = model
        self.safetyRatings = safetyRatings
    }

    /// Check if response contains images
    public var hasImages: Bool {
        return !images.isEmpty
    }

    /// Get the first image
    public var firstImage: GeneratedImage? {
        return images.first
    }
}

/// Safety rating for generated images
public struct ImageSafetyRating: Sendable {
    public let category: String
    public let probability: String
    public let blocked: Bool

    public init(category: String, probability: String, blocked: Bool) {
        self.category = category
        self.probability = probability
        self.blocked = blocked
    }
}

// MARK: - Image Editing Response

/// Response from image editing
public struct ImageEditingResponse: Sendable {
    /// Edited images
    public let images: [GeneratedImage]
    /// Original image URI (if uploaded)
    public let originalImageURI: String?
    /// Edit mode used
    public let editMode: ImageEditMode
    /// Model used for editing
    public let model: String

    public init(
        images: [GeneratedImage],
        originalImageURI: String? = nil,
        editMode: ImageEditMode,
        model: String
    ) {
        self.images = images
        self.originalImageURI = originalImageURI
        self.editMode = editMode
        self.model = model
    }

    /// Get the first edited image
    public var firstImage: GeneratedImage? {
        return images.first
    }
}

// MARK: - Image Upload Info

/// Information about an uploaded image
public struct ImageUploadInfo: Sendable {
    /// Unique identifier
    public let id: String
    /// File URI for API requests
    public let uri: String
    /// Display name
    public let displayName: String?
    /// MIME type
    public let mimeType: String
    /// File size in bytes
    public let sizeBytes: Int64?
    /// Creation time
    public let createTime: Date?
    /// Expiration time
    public let expirationTime: Date?
    /// Processing state
    public let state: ImageProcessingState

    public init(
        id: String,
        uri: String,
        displayName: String? = nil,
        mimeType: String,
        sizeBytes: Int64? = nil,
        createTime: Date? = nil,
        expirationTime: Date? = nil,
        state: ImageProcessingState = .active
    ) {
        self.id = id
        self.uri = uri
        self.displayName = displayName
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.createTime = createTime
        self.expirationTime = expirationTime
        self.state = state
    }
}

/// Processing state for uploaded images
public enum ImageProcessingState: String, Sendable {
    case processing = "PROCESSING"
    case active = "ACTIVE"
    case failed = "FAILED"
}

// MARK: - Image Analysis Request

/// Request for image analysis
public struct ImageAnalysisRequest: Sendable {
    /// Image data
    public let imageData: Data
    /// MIME type
    public let mimeType: String
    /// Analysis prompt
    public let prompt: String
    /// Additional context
    public let context: String?

    public init(
        imageData: Data,
        mimeType: String = "image/jpeg",
        prompt: String,
        context: String? = nil
    ) {
        self.imageData = imageData
        self.mimeType = mimeType
        self.prompt = prompt
        self.context = context
    }
}

// MARK: - Error Types

/// Errors specific to image operations
public enum GeminiImageError: Error, LocalizedError {
    case invalidImageData
    case unsupportedImageFormat(String)
    case generationFailed(String)
    case editingFailed(String)
    case uploadFailed(String)
    case processingTimeout
    case safetyFilterBlocked(String)
    case invalidConfiguration(String)
    case modelNotSupported(String)
    case quotaExceeded
    case serverError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data provided"
        case .unsupportedImageFormat(let format):
            return "Unsupported image format: \(format)"
        case .generationFailed(let reason):
            return "Image generation failed: \(reason)"
        case .editingFailed(let reason):
            return "Image editing failed: \(reason)"
        case .uploadFailed(let reason):
            return "Image upload failed: \(reason)"
        case .processingTimeout:
            return "Image processing timed out"
        case .safetyFilterBlocked(let reason):
            return "Content blocked by safety filter: \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .modelNotSupported(let model):
            return "Model not supported for this operation: \(model)"
        case .quotaExceeded:
            return "API quota exceeded"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

// MARK: - API Request/Response Structures

/// Internal request structure for Gemini image generation
internal struct GeminiImageGenerationRequest: Codable {
    let contents: [ImageContent]
    let generationConfig: ImageGenerationAPIConfig

    struct ImageContent: Codable {
        let role: String?
        let parts: [ImagePart]
    }

    struct ImagePart: Codable {
        let text: String?
        let inlineData: InlineImageData?

        enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inline_data"
        }
    }

    struct InlineImageData: Codable {
        let mimeType: String
        let data: String

        enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case data
        }
    }

    struct ImageGenerationAPIConfig: Codable {
        let responseModalities: [String]
        let candidateCount: Int?

        enum CodingKeys: String, CodingKey {
            case responseModalities = "response_modalities"
            case candidateCount = "candidate_count"
        }
    }
}

/// Internal request structure for Imagen generation
internal struct ImagenGenerationRequest: Codable {
    let instances: [ImagenInstance]
    let parameters: ImagenParameters

    struct ImagenInstance: Codable {
        let prompt: String
    }

    struct ImagenParameters: Codable {
        let sampleCount: Int?
        let aspectRatio: String?
        let negativePrompt: String?
        let personGeneration: String?
        let safetyFilterLevel: String?
        let addWatermark: Bool?
        let includeRaiReason: Bool?
        let language: String?
        let outputOptions: OutputOptions?

        struct OutputOptions: Codable {
            let mimeType: String?
        }
    }
}

/// Internal request structure for Imagen editing
internal struct ImagenEditRequest: Codable {
    let instances: [ImagenEditInstance]
    let parameters: ImagenEditParameters

    struct ImagenEditInstance: Codable {
        let prompt: String
        let image: ImagenImage
        let mask: ImagenMask?
    }

    struct ImagenImage: Codable {
        let bytesBase64Encoded: String
    }

    struct ImagenMask: Codable {
        let image: ImagenImage?
        let maskMode: String?
        let dilation: Double?
    }

    struct ImagenEditParameters: Codable {
        let sampleCount: Int?
        let editMode: String?
        let editConfig: EditConfig?

        struct EditConfig: Codable {
            let editSteps: Int?
            let outpaintingConfig: OutpaintingConfig?
        }

        struct OutpaintingConfig: Codable {
            let blendingMode: String?
            let blendingFactor: Double?
            let targetAspectRatio: String?
        }
    }
}

/// Internal response structure for Gemini image generation
internal struct GeminiImageGenerationAPIResponse: Codable {
    let candidates: [GeminiImageCandidate]?
    let promptFeedback: PromptFeedback?

    struct GeminiImageCandidate: Codable {
        let content: GeminiImageContent
        let finishReason: String?
        let safetyRatings: [GeminiImageSafetyRating]?
    }

    struct GeminiImageContent: Codable {
        let parts: [GeminiImagePart]
        let role: String?
    }

    struct GeminiImagePart: Codable {
        let text: String?
        let inlineData: InlineImageData?

        struct InlineImageData: Codable {
            let mimeType: String
            let data: String

            enum CodingKeys: String, CodingKey {
                case mimeType = "mime_type"
                case data
            }
        }

        enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inline_data"
        }
    }

    struct GeminiImageSafetyRating: Codable {
        let category: String
        let probability: String
        let blocked: Bool?
    }

    struct PromptFeedback: Codable {
        let blockReason: String?
        let safetyRatings: [GeminiImageSafetyRating]?
    }
}

/// Internal response structure for Imagen
internal struct ImagenAPIResponse: Codable {
    let predictions: [ImagenPrediction]?

    struct ImagenPrediction: Codable {
        let bytesBase64Encoded: String?
        let mimeType: String?
        let raiFilteredReason: String?
    }
}
