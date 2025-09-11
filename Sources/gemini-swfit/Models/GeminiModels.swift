import Foundation

// MARK: - Request Models

public struct GeminiGenerateContentRequest: Codable {
    public let contents: [Content]
    public let systemInstruction: SystemInstruction?
    public let generationConfig: GenerationConfig?
    public let safetySettings: [SafetySetting]?
    public let tools: [Tool]?
    
    public init(
        contents: [Content],
        systemInstruction: SystemInstruction? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        tools: [Tool]? = nil
    ) {
        self.contents = contents
        self.systemInstruction = systemInstruction
        self.generationConfig = generationConfig
        self.safetySettings = safetySettings
        self.tools = tools
    }
}

public struct Content: Codable {
    public let role: Role?
    public let parts: [Part]
    
    public init(role: Role? = nil, parts: [Part]) {
        self.role = role
        self.parts = parts
    }
}

public enum Role: String, Codable {
    case user = "user"
    case model = "model"
}

public struct Part: Codable {
    public let text: String?
    public let inlineData: InlineData?
    public let fileData: FileData?
    public let functionCall: FunctionCall?
    public let functionResponse: FunctionResponse?
    public let fileDataYouTube: YouTubeVideoData?
    
    public init(
        text: String? = nil,
        inlineData: InlineData? = nil,
        fileData: FileData? = nil,
        functionCall: FunctionCall? = nil,
        functionResponse: FunctionResponse? = nil,
        fileDataYouTube: YouTubeVideoData? = nil
    ) {
        self.text = text
        self.inlineData = inlineData
        self.fileData = fileData
        self.functionCall = functionCall
        self.functionResponse = functionResponse
        self.fileDataYouTube = fileDataYouTube
    }
    
    /// Custom coding keys for JSON mapping
    private enum CodingKeys: String, CodingKey {
        case text, inlineData, fileData, functionCall, functionResponse
        case fileDataYouTube = "file_data"
    }
}

public struct InlineData: Codable {
    public let mimeType: String
    public let data: String
    
    public init(mimeType: String, data: String) {
        self.mimeType = mimeType
        self.data = data
    }
}

public struct FileData: Codable {
    public let mimeType: String
    public let fileUri: String
    
    public init(mimeType: String, fileUri: String) {
        self.mimeType = mimeType
        self.fileUri = fileUri
    }
}

/// YouTube video data for external video processing
public struct YouTubeVideoData: Codable {
    public let fileUri: String
    
    public init(fileUri: String) {
        self.fileUri = fileUri
    }
}

public struct FunctionCall: Codable {
    public let name: String
    public let args: [String: String]
    
    public init(name: String, args: [String: String]) {
        self.name = name
        self.args = args
    }
}

public struct FunctionResponse: Codable {
    public let name: String
    public let response: [String: String]
    
    public init(name: String, response: [String: String]) {
        self.name = name
        self.response = response
    }
}

public struct SystemInstruction: Codable {
    public let parts: [Part]
    
    public init(parts: [Part]) {
        self.parts = parts
    }
    
    public init(text: String) {
        self.parts = [Part(text: text)]
    }
}

public struct GenerationConfig: Codable {
    public let candidateCount: Int?
    public let stopSequences: [String]?
    public let maxOutputTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let responseMimeType: String?
    public let responseSchema: String?
    
    public init(
        candidateCount: Int? = 1,
        stopSequences: [String]? = nil,
        maxOutputTokens: Int? = 8192,
        temperature: Double? = 0.7,
        topP: Double? = 0.9,
        topK: Int? = 40,
        responseMimeType: String? = nil,
        responseSchema: [String: Any]? = nil
    ) {
        self.candidateCount = candidateCount
        self.stopSequences = stopSequences
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.responseMimeType = responseMimeType
        
        if let responseSchema = responseSchema {
            if let data = try? JSONSerialization.data(withJSONObject: responseSchema, options: []),
               let jsonString = String(data: data, encoding: .utf8) {
                self.responseSchema = jsonString
            } else {
                self.responseSchema = nil
            }
        } else {
            self.responseSchema = nil
        }
    }
}

public struct StructuredOutputConfig {
    public let responseMimeType: String
    public let responseSchema: [String: Any]
    
    public init(responseMimeType: String = "application/json", responseSchema: [String: Any]) {
        self.responseMimeType = responseMimeType
        self.responseSchema = responseSchema
    }
    
    public init<T: Codable>(responseMimeType: String = "application/json", for type: T.Type) throws {
        self.responseMimeType = responseMimeType
        self.responseSchema = try generateJSONSchema(for: type)
    }
    
    public init<T: Codable>(responseMimeType: String = "application/json", for type: T.Type, defaultInstance: T) {
        self.responseMimeType = responseMimeType
        self.responseSchema = generateJSONSchema(for: type, defaultInstance: defaultInstance)
    }
}

public struct SafetySetting: Codable {
    public let category: SafetyCategory
    public let threshold: SafetyThreshold
    
    public init(category: SafetyCategory, threshold: SafetyThreshold) {
        self.category = category
        self.threshold = threshold
    }
}

public enum SafetyCategory: String, Codable {
    case harassment = "HARM_CATEGORY_HARASSMENT"
    case hateSpeech = "HARM_CATEGORY_HATE_SPEECH"
    case sexuallyExplicit = "HARM_CATEGORY_SEXUALLY_EXPLICIT"
    case dangerousContent = "HARM_CATEGORY_DANGEROUS_CONTENT"
}

public enum SafetyThreshold: String, Codable {
    case blockNone = "BLOCK_NONE"
    case blockFew = "BLOCK_FEW"
    case blockSome = "BLOCK_SOME"
    case blockMost = "BLOCK_MOST"
}

// MARK: - Response Models

public struct GeminiGenerateContentResponse: Codable {
    public let candidates: [Candidate]
    public let promptFeedback: PromptFeedback?
    
    public init(candidates: [Candidate], promptFeedback: PromptFeedback? = nil) {
        self.candidates = candidates
        self.promptFeedback = promptFeedback
    }
}

public struct Candidate: Codable {
    public let content: Content
    public let finishReason: FinishReason?
    public let safetyRatings: [SafetyRating]?
    public let citationMetadata: CitationMetadata?
    public let groundingMetadata: GroundingMetadata?
    
    public init(
        content: Content,
        finishReason: FinishReason? = nil,
        safetyRatings: [SafetyRating]? = nil,
        citationMetadata: CitationMetadata? = nil,
        groundingMetadata: GroundingMetadata? = nil
    ) {
        self.content = content
        self.finishReason = finishReason
        self.safetyRatings = safetyRatings
        self.citationMetadata = citationMetadata
        self.groundingMetadata = groundingMetadata
    }
}

public enum FinishReason: String, Codable {
    case unspecified = "FINISH_REASON_UNSPECIFIED"
    case stop = "STOP"
    case maxTokens = "MAX_TOKENS"
    case safety = "SAFETY"
    case recitation = "RECITATION"
    case other = "OTHER"
}

public struct SafetyRating: Codable {
    public let category: SafetyCategory
    public let probability: HarmProbability
    public let blocked: Bool
    
    public init(category: SafetyCategory, probability: HarmProbability, blocked: Bool) {
        self.category = category
        self.probability = probability
        self.blocked = blocked
    }
}

public enum HarmProbability: String, Codable {
    case unspecified = "HARM_PROBABILITY_UNSPECIFIED"
    case negligible = "NEGLIGIBLE"
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

public struct CitationMetadata: Codable {
    public let citationSources: [CitationSource]
    
    public init(citationSources: [CitationSource]) {
        self.citationSources = citationSources
    }
}

public struct CitationSource: Codable {
    public let startIndex: Int?
    public let endIndex: Int?
    public let uri: String?
    public let license: String?
    
    public init(
        startIndex: Int? = nil,
        endIndex: Int? = nil,
        uri: String? = nil,
        license: String? = nil
    ) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.uri = uri
        self.license = license
    }
}

public struct PromptFeedback: Codable {
    public let safetyRatings: [SafetyRating]
    
    public init(safetyRatings: [SafetyRating]) {
        self.safetyRatings = safetyRatings
    }
}

// MARK: - Embedding Models

public struct GeminiEmbeddingRequest: Codable {
    public let model: String
    public let content: Content
    public let taskType: EmbeddingTaskType?
    public let title: String?
    
    public init(
        model: String,
        content: Content,
        taskType: EmbeddingTaskType? = nil,
        title: String? = nil
    ) {
        self.model = model
        self.content = content
        self.taskType = taskType
        self.title = title
    }
}

public struct GeminiEmbeddingResponse: Codable {
    public let embedding: [Float]
    
    public init(embedding: [Float]) {
        self.embedding = embedding
    }
}

public enum EmbeddingTaskType: String, Codable {
    case retrievalQuery = "RETRIEVAL_QUERY"
    case retrievalDocument = "RETRIEVAL_DOCUMENT"
    case semanticSimilarity = "SEMANTIC_SIMILARITY"
    case classification = "CLASSIFICATION"
    case clustering = "CLUSTERING"
    
    public var displayName: String {
        switch self {
        case .retrievalQuery: return "Retrieval Query"
        case .retrievalDocument: return "Retrieval Document"
        case .semanticSimilarity: return "Semantic Similarity"
        case .classification: return "Classification"
        case .clustering: return "Clustering"
        }
    }
}

// MARK: - Tool Models

public struct Tool: Codable {
    public let googleSearch: GoogleSearch?
    public let urlContext: UrlContext?
    
    public init(googleSearch: GoogleSearch? = nil, urlContext: UrlContext? = nil) {
        self.googleSearch = googleSearch
        self.urlContext = urlContext
    }
    
    public static func googleSearch() -> Tool {
        return Tool(googleSearch: GoogleSearch())
    }
    
    public static func urlContext() -> Tool {
        return Tool(urlContext: UrlContext())
    }
}

public struct GoogleSearch: Codable {
    public init() {}
}

public struct UrlContext: Codable {
    public init() {}
}

// MARK: - Grounding Metadata Models

public struct GroundingMetadata: Codable {
    public let webSearchQueries: [String]?
    public let searchEntryPoint: SearchEntryPoint?
    public let groundingChunks: [GroundingChunk]?
    public let groundingSupports: [GroundingSupport]?
    
    public init(
        webSearchQueries: [String]? = nil,
        searchEntryPoint: SearchEntryPoint? = nil,
        groundingChunks: [GroundingChunk]? = nil,
        groundingSupports: [GroundingSupport]? = nil
    ) {
        self.webSearchQueries = webSearchQueries
        self.searchEntryPoint = searchEntryPoint
        self.groundingChunks = groundingChunks
        self.groundingSupports = groundingSupports
    }
}

public struct SearchEntryPoint: Codable {
    public let renderedContent: String?
    
    public init(renderedContent: String? = nil) {
        self.renderedContent = renderedContent
    }
}

public struct GroundingChunk: Codable {
    public let web: WebChunk?
    
    public init(web: WebChunk? = nil) {
        self.web = web
    }
}

public struct WebChunk: Codable {
    public let uri: String?
    public let title: String?
    
    public init(uri: String? = nil, title: String? = nil) {
        self.uri = uri
        self.title = title
    }
}

public struct GroundingSupport: Codable {
    public let segment: Segment
    public let groundingChunkIndices: [Int]?
    
    public init(segment: Segment, groundingChunkIndices: [Int]? = nil) {
        self.segment = segment
        self.groundingChunkIndices = groundingChunkIndices
    }
}

public struct Segment: Codable {
    public let startIndex: Int?
    public let endIndex: Int?
    public let text: String?
    
    public init(startIndex: Int? = nil, endIndex: Int? = nil, text: String? = nil) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.text = text
    }
}