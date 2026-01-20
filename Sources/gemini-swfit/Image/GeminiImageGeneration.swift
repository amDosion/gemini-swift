import Foundation
import SwiftyBeaver

// MARK: - Image Generation Configuration

/// Configuration for image generation
public struct ImageGenerationConfig: Codable, Sendable {
    /// Number of images to generate (1-4)
    public let numberOfImages: Int

    /// Output image format
    public let outputFormat: ImageFormat

    /// Aspect ratio for generated images
    public let aspectRatio: AspectRatio

    /// Enable safety filtering
    public let safetyFilterLevel: SafetyFilterLevel

    /// Enable person generation (requires additional approval)
    public let personGeneration: PersonGeneration

    /// Output resolution (for Gemini 3 Pro Image)
    public let outputResolution: OutputResolution?

    /// Add invisible watermark to generated images
    public let addWatermark: Bool

    public init(
        numberOfImages: Int = 1,
        outputFormat: ImageFormat = .png,
        aspectRatio: AspectRatio = .square,
        safetyFilterLevel: SafetyFilterLevel = .blockMediumAndAbove,
        personGeneration: PersonGeneration = .dontAllow,
        outputResolution: OutputResolution? = nil,
        addWatermark: Bool = true
    ) {
        self.numberOfImages = min(4, max(1, numberOfImages))
        self.outputFormat = outputFormat
        self.aspectRatio = aspectRatio
        self.safetyFilterLevel = safetyFilterLevel
        self.personGeneration = personGeneration
        self.outputResolution = outputResolution
        self.addWatermark = addWatermark
    }

    // MARK: - Presets

    public static let `default` = ImageGenerationConfig()

    public static let highQuality = ImageGenerationConfig(
        outputFormat: .png,
        aspectRatio: .square,
        outputResolution: .resolution2K
    )

    public static let ultraQuality = ImageGenerationConfig(
        outputFormat: .png,
        aspectRatio: .landscape16x9,
        outputResolution: .resolution4K
    )

    public static let batch = ImageGenerationConfig(
        numberOfImages: 4
    )
}

/// Image output format
public enum ImageFormat: String, Codable, Sendable {
    case png = "png"
    case jpeg = "jpeg"
    case webp = "webp"
}

/// Aspect ratio for generated images
public enum AspectRatio: String, Codable, Sendable {
    case square = "1:1"
    case portrait3x4 = "3:4"
    case portrait9x16 = "9:16"
    case landscape4x3 = "4:3"
    case landscape16x9 = "16:9"

    public var description: String {
        switch self {
        case .square: return "Square (1:1)"
        case .portrait3x4: return "Portrait (3:4)"
        case .portrait9x16: return "Portrait (9:16)"
        case .landscape4x3: return "Landscape (4:3)"
        case .landscape16x9: return "Landscape (16:9)"
        }
    }
}

/// Safety filter level
public enum SafetyFilterLevel: String, Codable, Sendable {
    case blockNone = "block_none"
    case blockOnlyHigh = "block_only_high"
    case blockMediumAndAbove = "block_medium_and_above"
    case blockLowAndAbove = "block_low_and_above"
}

/// Person generation setting
public enum PersonGeneration: String, Codable, Sendable {
    case dontAllow = "dont_allow"
    case allowAdult = "allow_adult"
    case allowAll = "allow_all"
}

/// Output resolution for Gemini 3 Pro Image
public enum OutputResolution: String, Codable, Sendable {
    case resolution1K = "1024"
    case resolution2K = "2048"
    case resolution4K = "4096"
}

// MARK: - Image Generation Response

/// Response from image generation
public struct ImageGenerationResponse: Sendable {
    /// Generated images
    public let images: [GeneratedImage]

    /// Thought signature for multi-turn editing
    public let thoughtSignature: String?

    /// Text response (if any)
    public let textResponse: String?

    /// Whether the request was filtered
    public let wasFiltered: Bool

    /// Filter reason if filtered
    public let filterReason: String?

    public init(
        images: [GeneratedImage],
        thoughtSignature: String? = nil,
        textResponse: String? = nil,
        wasFiltered: Bool = false,
        filterReason: String? = nil
    ) {
        self.images = images
        self.thoughtSignature = thoughtSignature
        self.textResponse = textResponse
        self.wasFiltered = wasFiltered
        self.filterReason = filterReason
    }
}

/// A single generated image
public struct GeneratedImage: Sendable {
    /// Image data
    public let data: Data

    /// MIME type
    public let mimeType: String

    /// Image index in batch
    public let index: Int

    /// Revision ID for editing
    public let revisionId: String?

    public init(
        data: Data,
        mimeType: String,
        index: Int = 0,
        revisionId: String? = nil
    ) {
        self.data = data
        self.mimeType = mimeType
        self.index = index
        self.revisionId = revisionId
    }

    /// Save image to file
    public func save(to url: URL) throws {
        try data.write(to: url)
    }

    /// Get image as base64 string
    public var base64String: String {
        return data.base64EncodedString()
    }
}

// MARK: - Image Edit Request

/// Request for editing an image
public struct ImageEditRequest: Sendable {
    /// The edit instruction
    public let prompt: String

    /// Source image to edit
    public let sourceImage: ImageInput

    /// Optional mask for targeted editing
    public let mask: ImageInput?

    /// Edit mode
    public let editMode: ImageEditMode

    public init(
        prompt: String,
        sourceImage: ImageInput,
        mask: ImageInput? = nil,
        editMode: ImageEditMode = .inpaint
    ) {
        self.prompt = prompt
        self.sourceImage = sourceImage
        self.mask = mask
        self.editMode = editMode
    }
}

/// Input image specification
public struct ImageInput: Sendable {
    /// Image data
    public let data: Data?

    /// Image URL (for remote images)
    public let url: URL?

    /// MIME type
    public let mimeType: String

    /// File URI (for uploaded files)
    public let fileUri: String?

    public init(data: Data, mimeType: String = "image/png") {
        self.data = data
        self.url = nil
        self.mimeType = mimeType
        self.fileUri = nil
    }

    public init(url: URL, mimeType: String = "image/png") {
        self.data = nil
        self.url = url
        self.mimeType = mimeType
        self.fileUri = nil
    }

    public init(fileUri: String, mimeType: String = "image/png") {
        self.data = nil
        self.url = nil
        self.mimeType = mimeType
        self.fileUri = fileUri
    }

    /// Create from file path
    public static func fromFile(_ path: String) throws -> ImageInput {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let mimeType = ImageInput.mimeType(for: url.pathExtension)
        return ImageInput(data: data, mimeType: mimeType)
    }

    /// Get MIME type from file extension
    public static func mimeType(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "gif": return "image/gif"
        case "heic": return "image/heic"
        default: return "image/png"
        }
    }
}

/// Image edit mode
public enum ImageEditMode: String, Codable, Sendable {
    case inpaint = "INPAINT"
    case outpaint = "OUTPAINT"
    case editImage = "EDIT_IMAGE"
    case controlledGeneration = "CONTROLLED_GENERATION"
}

// MARK: - Image Generation Models

/// Available image generation models
public enum ImageGenerationModel: String, Sendable {
    /// Gemini 2.5 Flash Image - fast, efficient
    case gemini25FlashImage = "gemini-2.5-flash-image"

    /// Gemini 3 Pro Image - high quality, supports 4K
    case gemini3ProImage = "gemini-3-pro-image-preview"

    /// Imagen 4 Ultra - highest quality
    case imagen4Ultra = "imagen-4-ultra"

    /// Imagen 4 Standard - balanced quality/speed
    case imagen4Standard = "imagen-4-standard"

    /// Legacy model (deprecated Oct 2025)
    @available(*, deprecated, message: "Use gemini25FlashImage instead")
    case gemini25FlashImagePreview = "gemini-2.5-flash-image-preview"

    public var displayName: String {
        switch self {
        case .gemini25FlashImage: return "Gemini 2.5 Flash Image"
        case .gemini3ProImage: return "Gemini 3 Pro Image"
        case .imagen4Ultra: return "Imagen 4 Ultra"
        case .imagen4Standard: return "Imagen 4 Standard"
        case .gemini25FlashImagePreview: return "Gemini 2.5 Flash Image (Legacy)"
        }
    }

    public var supportsMultiTurnEditing: Bool {
        switch self {
        case .gemini25FlashImage, .gemini3ProImage:
            return true
        default:
            return false
        }
    }

    public var supports4K: Bool {
        switch self {
        case .gemini3ProImage, .imagen4Ultra:
            return true
        default:
            return false
        }
    }

    public var supportsThinking: Bool {
        switch self {
        case .gemini3ProImage:
            return true
        default:
            return false
        }
    }
}

// MARK: - Thought Signature

/// Thought signature for preserving context in multi-turn editing
public struct ThoughtSignature: Codable, Sendable {
    /// The encrypted signature data
    public let signature: String

    /// Timestamp when the signature was created
    public let timestamp: Date

    /// Model that generated the signature
    public let model: String?

    public init(signature: String, timestamp: Date = Date(), model: String? = nil) {
        self.signature = signature
        self.timestamp = timestamp
        self.model = model
    }

    /// Check if signature is still valid (typically 24 hours)
    public var isValid: Bool {
        let maxAge: TimeInterval = 24 * 60 * 60  // 24 hours
        return Date().timeIntervalSince(timestamp) < maxAge
    }
}

// MARK: - Image Generation Request Payload

/// Internal request payload for image generation
internal struct ImageGenerationRequestPayload: Codable {
    let contents: [ImageContentPayload]
    let generationConfig: ImageGenerationConfigPayload?
    let safetySettings: [SafetySetting]?

    struct ImageContentPayload: Codable {
        let role: String?
        let parts: [ImagePartPayload]
    }

    struct ImagePartPayload: Codable {
        let text: String?
        let inlineData: InlineDataPayload?
        let fileData: FileDataPayload?
        let thoughtSignature: String?

        struct InlineDataPayload: Codable {
            let mimeType: String
            let data: String
        }

        struct FileDataPayload: Codable {
            let mimeType: String
            let fileUri: String
        }
    }

    struct ImageGenerationConfigPayload: Codable {
        let responseModalities: [String]?
        let responseMimeType: String?
        let imageGenerationConfig: ImageGenConfigPayload?

        struct ImageGenConfigPayload: Codable {
            let numberOfImages: Int?
            let aspectRatio: String?
            let outputResolution: String?
            let safetyFilterLevel: String?
            let personGeneration: String?
            let addWatermark: Bool?
        }
    }
}

// MARK: - Image Generation Response Payload

/// Internal response payload from image generation
internal struct ImageGenerationResponsePayload: Codable {
    let candidates: [CandidatePayload]?
    let promptFeedback: PromptFeedbackPayload?

    struct CandidatePayload: Codable {
        let content: ContentPayload?
        let finishReason: String?
        let safetyRatings: [SafetyRatingPayload]?

        struct ContentPayload: Codable {
            let parts: [PartPayload]?
            let role: String?
        }

        struct PartPayload: Codable {
            let text: String?
            let inlineData: InlineDataPayload?
            let thoughtSignature: String?

            struct InlineDataPayload: Codable {
                let mimeType: String
                let data: String
            }
        }

        struct SafetyRatingPayload: Codable {
            let category: String
            let probability: String
            let blocked: Bool?
        }
    }

    struct PromptFeedbackPayload: Codable {
        let blockReason: String?
        let safetyRatings: [CandidatePayload.SafetyRatingPayload]?
    }
}
