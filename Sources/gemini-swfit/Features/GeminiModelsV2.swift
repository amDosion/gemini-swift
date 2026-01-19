import Foundation

// MARK: - Extended Model Enum

/// Extended model enumeration with all latest Gemini models
public enum GeminiModel: String, CaseIterable, Sendable {
    // MARK: - Gemini 3 Models
    case gemini3FlashPreview = "gemini-3-flash-preview"

    // MARK: - Gemini 2.5 Stable Models
    case gemini25Pro = "gemini-2.5-pro"
    case gemini25Flash = "gemini-2.5-flash"
    case gemini25FlashLite = "gemini-2.5-flash-lite"

    // MARK: - Gemini 2.5 Preview Models
    case gemini25ProPreview = "gemini-2.5-pro-preview-06-05"
    case gemini25FlashPreview = "gemini-2.5-flash-preview-05-20"

    // MARK: - Native Audio Models
    case gemini25FlashNativeAudio = "gemini-2.5-flash-preview-native-audio-dialog"
    case gemini25FlashNativeAudioThinking = "gemini-2.5-flash-exp-native-audio-thinking-dialog"
    case gemini25FlashNativeAudioLatest = "gemini-2.5-flash-native-audio-preview-12-2025"

    // MARK: - Image Generation Models
    case gemini25FlashImagePreview = "gemini-2.5-flash-image-preview"

    // MARK: - Live API Models
    case geminiLive25FlashPreview = "gemini-live-2.5-flash-preview"

    // MARK: - Embedding Models
    case geminiEmbedding001 = "gemini-embedding-001"
    case textEmbedding004 = "text-embedding-004"

    // MARK: - Imagen Models
    case imagen4Ultra = "imagen-4-ultra"
    case imagen4Standard = "imagen-4-standard"

    // MARK: - Veo Video Models
    case veo31 = "veo-3.1"
    case veo31Fast = "veo-3.1-fast"

    // MARK: - Properties

    public var displayName: String {
        switch self {
        case .gemini3FlashPreview: return "Gemini 3 Flash Preview"
        case .gemini25Pro: return "Gemini 2.5 Pro"
        case .gemini25Flash: return "Gemini 2.5 Flash"
        case .gemini25FlashLite: return "Gemini 2.5 Flash Lite"
        case .gemini25ProPreview: return "Gemini 2.5 Pro Preview"
        case .gemini25FlashPreview: return "Gemini 2.5 Flash Preview"
        case .gemini25FlashNativeAudio: return "Gemini 2.5 Flash Native Audio"
        case .gemini25FlashNativeAudioThinking: return "Gemini 2.5 Flash Native Audio (Thinking)"
        case .gemini25FlashNativeAudioLatest: return "Gemini 2.5 Flash Native Audio (Latest)"
        case .gemini25FlashImagePreview: return "Gemini 2.5 Flash Image Preview"
        case .geminiLive25FlashPreview: return "Gemini Live 2.5 Flash Preview"
        case .geminiEmbedding001: return "Gemini Embedding 001"
        case .textEmbedding004: return "Text Embedding 004"
        case .imagen4Ultra: return "Imagen 4 Ultra"
        case .imagen4Standard: return "Imagen 4 Standard"
        case .veo31: return "Veo 3.1"
        case .veo31Fast: return "Veo 3.1 Fast"
        }
    }

    /// Whether this model supports thinking mode
    public var supportsThinking: Bool {
        switch self {
        case .gemini3FlashPreview, .gemini25Pro, .gemini25Flash,
             .gemini25ProPreview, .gemini25FlashPreview,
             .gemini25FlashNativeAudioThinking, .gemini25FlashNativeAudioLatest:
            return true
        default:
            return false
        }
    }

    /// Whether this model supports the Live API
    public var supportsLiveAPI: Bool {
        switch self {
        case .geminiLive25FlashPreview, .gemini25FlashNativeAudio,
             .gemini25FlashNativeAudioThinking, .gemini25FlashNativeAudioLatest:
            return true
        default:
            return false
        }
    }

    /// Whether this model supports code execution
    public var supportsCodeExecution: Bool {
        switch self {
        case .gemini3FlashPreview, .gemini25Pro, .gemini25Flash,
             .gemini25ProPreview, .gemini25FlashPreview:
            return true
        default:
            return false
        }
    }

    /// Whether this model supports image generation
    public var supportsImageGeneration: Bool {
        switch self {
        case .gemini25FlashImagePreview, .imagen4Ultra, .imagen4Standard:
            return true
        default:
            return false
        }
    }

    /// Whether this model supports video generation
    public var supportsVideoGeneration: Bool {
        switch self {
        case .veo31, .veo31Fast:
            return true
        default:
            return false
        }
    }

    /// Whether this is an embedding model
    public var isEmbeddingModel: Bool {
        switch self {
        case .geminiEmbedding001, .textEmbedding004:
            return true
        default:
            return false
        }
    }

    /// Model category
    public var category: ModelCategory {
        switch self {
        case .gemini3FlashPreview:
            return .gemini3
        case .gemini25Pro, .gemini25Flash, .gemini25FlashLite,
             .gemini25ProPreview, .gemini25FlashPreview:
            return .gemini25
        case .gemini25FlashNativeAudio, .gemini25FlashNativeAudioThinking,
             .gemini25FlashNativeAudioLatest, .geminiLive25FlashPreview:
            return .liveAudio
        case .gemini25FlashImagePreview:
            return .imageGeneration
        case .geminiEmbedding001, .textEmbedding004:
            return .embedding
        case .imagen4Ultra, .imagen4Standard:
            return .imagen
        case .veo31, .veo31Fast:
            return .veo
        }
    }

    /// Token limits for this model
    public var tokenLimits: (input: Int, output: Int) {
        switch self {
        case .gemini3FlashPreview:
            return (1_048_576, 65_536)
        case .gemini25Pro, .gemini25ProPreview:
            return (2_097_152, 65_536)
        case .gemini25Flash, .gemini25FlashPreview, .gemini25FlashLite:
            return (1_048_576, 65_536)
        case .gemini25FlashNativeAudio, .gemini25FlashNativeAudioThinking,
             .gemini25FlashNativeAudioLatest:
            return (1_048_576, 32_768)
        case .geminiLive25FlashPreview:
            return (1_048_576, 32_768)
        case .gemini25FlashImagePreview:
            return (1_048_576, 8_192)
        case .geminiEmbedding001:
            return (2_048, 0)
        case .textEmbedding004:
            return (2_048, 0)
        case .imagen4Ultra, .imagen4Standard:
            return (32_768, 0)
        case .veo31, .veo31Fast:
            return (32_768, 0)
        }
    }
}

/// Model categories
public enum ModelCategory: String, Sendable {
    case gemini3 = "Gemini 3"
    case gemini25 = "Gemini 2.5"
    case liveAudio = "Live Audio"
    case imageGeneration = "Image Generation"
    case embedding = "Embedding"
    case imagen = "Imagen"
    case veo = "Veo Video"
}

// MARK: - Model Capabilities

/// Detailed capabilities for a model
public struct ModelCapabilities: Sendable {
    public let model: GeminiModel
    public let supportsThinking: Bool
    public let supportsLiveAPI: Bool
    public let supportsCodeExecution: Bool
    public let supportsImageGeneration: Bool
    public let supportsVideoGeneration: Bool
    public let supportsGoogleSearch: Bool
    public let supportsUrlContext: Bool
    public let supportsGoogleMaps: Bool
    public let supportsFunctionCalling: Bool
    public let supportsMultiTool: Bool
    public let maxInputTokens: Int
    public let maxOutputTokens: Int

    public init(model: GeminiModel) {
        self.model = model
        self.supportsThinking = model.supportsThinking
        self.supportsLiveAPI = model.supportsLiveAPI
        self.supportsCodeExecution = model.supportsCodeExecution
        self.supportsImageGeneration = model.supportsImageGeneration
        self.supportsVideoGeneration = model.supportsVideoGeneration

        // Most generation models support these
        let isGenerationModel = !model.isEmbeddingModel &&
                               model.category != .imagen &&
                               model.category != .veo

        self.supportsGoogleSearch = isGenerationModel
        self.supportsUrlContext = isGenerationModel
        self.supportsGoogleMaps = isGenerationModel
        self.supportsFunctionCalling = isGenerationModel
        self.supportsMultiTool = isGenerationModel

        let limits = model.tokenLimits
        self.maxInputTokens = limits.input
        self.maxOutputTokens = limits.output
    }
}

// MARK: - Model Selection Helper

/// Helper for selecting the best model for a task
public struct ModelSelector {

    /// Get the best model for a text generation task
    public static func forTextGeneration(
        fast: Bool = true,
        thinking: Bool = false
    ) -> GeminiModel {
        if thinking {
            return fast ? .gemini25Flash : .gemini25Pro
        }
        return fast ? .gemini25FlashLite : .gemini25Flash
    }

    /// Get the best model for code-related tasks
    public static func forCoding(complex: Bool = false) -> GeminiModel {
        return complex ? .gemini25Pro : .gemini25Flash
    }

    /// Get the best model for live conversations
    public static func forLiveConversation(withThinking: Bool = false) -> GeminiModel {
        return withThinking ? .gemini25FlashNativeAudioThinking : .gemini25FlashNativeAudio
    }

    /// Get the best model for image analysis
    public static func forImageAnalysis() -> GeminiModel {
        return .gemini25Flash
    }

    /// Get the best model for image generation
    public static func forImageGeneration(quality: ImageQuality = .standard) -> GeminiModel {
        switch quality {
        case .ultra: return .imagen4Ultra
        case .standard: return .imagen4Standard
        case .preview: return .gemini25FlashImagePreview
        }
    }

    /// Get the best model for video generation
    public static func forVideoGeneration(fast: Bool = true) -> GeminiModel {
        return fast ? .veo31Fast : .veo31
    }

    /// Get the best embedding model
    public static func forEmbedding() -> GeminiModel {
        return .textEmbedding004
    }

    public enum ImageQuality {
        case ultra
        case standard
        case preview
    }
}

// MARK: - Model Info

/// Get detailed information about available models
public struct ModelInfo {

    /// Get all available models
    public static var allModels: [GeminiModel] {
        return GeminiModel.allCases
    }

    /// Get models by category
    public static func models(in category: ModelCategory) -> [GeminiModel] {
        return GeminiModel.allCases.filter { $0.category == category }
    }

    /// Get models that support a specific feature
    public static func models(supporting feature: ModelFeature) -> [GeminiModel] {
        return GeminiModel.allCases.filter { model in
            switch feature {
            case .thinking: return model.supportsThinking
            case .liveAPI: return model.supportsLiveAPI
            case .codeExecution: return model.supportsCodeExecution
            case .imageGeneration: return model.supportsImageGeneration
            case .videoGeneration: return model.supportsVideoGeneration
            }
        }
    }

    public enum ModelFeature {
        case thinking
        case liveAPI
        case codeExecution
        case imageGeneration
        case videoGeneration
    }
}
