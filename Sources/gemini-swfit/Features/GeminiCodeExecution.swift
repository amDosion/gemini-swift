import Foundation

// MARK: - Code Execution Tool

/// Code execution tool configuration
public struct CodeExecutionTool: Codable, Sendable {
    /// Empty struct - the tool is configured by its presence
    public init() {}
}

/// Extended Tool structure that includes code execution
public struct ExtendedTool: Codable, Sendable {
    public let googleSearch: GoogleSearch?
    public let urlContext: UrlContext?
    public let codeExecution: CodeExecutionTool?
    public let googleMaps: GoogleMapsTool?
    public let functionDeclarations: [FunctionDeclarationPayload]?

    public init(
        googleSearch: GoogleSearch? = nil,
        urlContext: UrlContext? = nil,
        codeExecution: CodeExecutionTool? = nil,
        googleMaps: GoogleMapsTool? = nil,
        functionDeclarations: [FunctionDeclarationPayload]? = nil
    ) {
        self.googleSearch = googleSearch
        self.urlContext = urlContext
        self.codeExecution = codeExecution
        self.googleMaps = googleMaps
        self.functionDeclarations = functionDeclarations
    }

    // MARK: - Factory Methods

    /// Create a code execution tool
    public static func codeExecution() -> ExtendedTool {
        return ExtendedTool(codeExecution: CodeExecutionTool())
    }

    /// Create a Google Maps tool
    public static func googleMaps() -> ExtendedTool {
        return ExtendedTool(googleMaps: GoogleMapsTool())
    }

    /// Create multiple tools at once
    public static func multiTool(
        googleSearch: Bool = false,
        urlContext: Bool = false,
        codeExecution: Bool = false,
        googleMaps: Bool = false
    ) -> ExtendedTool {
        return ExtendedTool(
            googleSearch: googleSearch ? GoogleSearch() : nil,
            urlContext: urlContext ? UrlContext() : nil,
            codeExecution: codeExecution ? CodeExecutionTool() : nil,
            googleMaps: googleMaps ? GoogleMapsTool() : nil
        )
    }
}

// MARK: - Google Maps Tool

/// Google Maps grounding tool
public struct GoogleMapsTool: Codable, Sendable {
    public init() {}
}

// MARK: - Code Execution Result

/// Result from code execution
public struct CodeExecutionResult: Codable, Sendable {
    /// The outcome of the execution
    public let outcome: ExecutionOutcome

    /// The output from the execution
    public let output: String?

    /// Generated files (if any)
    public let generatedFiles: [GeneratedFile]?

    public enum ExecutionOutcome: String, Codable, Sendable {
        case outcomeUnspecified = "OUTCOME_UNSPECIFIED"
        case outcomeOk = "OUTCOME_OK"
        case outcomeFailed = "OUTCOME_FAILED"
        case outcomeDeadlineExceeded = "OUTCOME_DEADLINE_EXCEEDED"
    }

    public struct GeneratedFile: Codable, Sendable {
        public let name: String
        public let mimeType: String
        public let data: String  // Base64 encoded

        public init(name: String, mimeType: String, data: String) {
            self.name = name
            self.mimeType = mimeType
            self.data = data
        }

        /// Decode the file data
        public var decodedData: Data? {
            return Data(base64Encoded: data)
        }
    }
}

/// Executable code part in response
public struct ExecutableCode: Codable, Sendable {
    public let language: String
    public let code: String

    public init(language: String, code: String) {
        self.language = language
        self.code = code
    }
}

// MARK: - Extended Part for Code Execution

/// Extended Part that includes code execution fields
public struct ExtendedPart: Codable, Sendable {
    public let text: String?
    public let inlineData: InlineData?
    public let fileData: FileData?
    public let functionCall: FunctionCall?
    public let functionResponse: FunctionResponse?
    public let executableCode: ExecutableCode?
    public let codeExecutionResult: CodeExecutionResult?

    public init(
        text: String? = nil,
        inlineData: InlineData? = nil,
        fileData: FileData? = nil,
        functionCall: FunctionCall? = nil,
        functionResponse: FunctionResponse? = nil,
        executableCode: ExecutableCode? = nil,
        codeExecutionResult: CodeExecutionResult? = nil
    ) {
        self.text = text
        self.inlineData = inlineData
        self.fileData = fileData
        self.functionCall = functionCall
        self.functionResponse = functionResponse
        self.executableCode = executableCode
        self.codeExecutionResult = codeExecutionResult
    }
}

// MARK: - Code Execution Response Parser

/// Parser for extracting code execution results from responses
public struct CodeExecutionParser {

    /// Extract all executed code from a response
    public static func extractExecutedCode(from response: GeminiGenerateContentResponse) -> [ExecutedCodeBlock] {
        var blocks: [ExecutedCodeBlock] = []

        for candidate in response.candidates {
            for (index, part) in candidate.content.parts.enumerated() {
                // Try to parse the part text for code blocks
                if let text = part.text {
                    let codeBlocks = extractCodeBlocks(from: text)
                    blocks.append(contentsOf: codeBlocks)
                }
            }
        }

        return blocks
    }

    /// Extract code blocks from text (markdown format)
    private static func extractCodeBlocks(from text: String) -> [ExecutedCodeBlock] {
        var blocks: [ExecutedCodeBlock] = []

        // Pattern for markdown code blocks with language
        let pattern = #"```(\w+)?\n([\s\S]*?)```"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return blocks
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            var language = "python"  // Default language
            var code = ""

            if match.numberOfRanges >= 2 {
                let langRange = match.range(at: 1)
                if langRange.location != NSNotFound {
                    language = nsText.substring(with: langRange)
                }
            }

            if match.numberOfRanges >= 3 {
                let codeRange = match.range(at: 2)
                if codeRange.location != NSNotFound {
                    code = nsText.substring(with: codeRange)
                }
            }

            if !code.isEmpty {
                blocks.append(ExecutedCodeBlock(
                    language: language,
                    code: code.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            }
        }

        return blocks
    }

    /// Check if response contains code execution
    public static func hasCodeExecution(in response: GeminiGenerateContentResponse) -> Bool {
        for candidate in response.candidates {
            for part in candidate.content.parts {
                if let text = part.text, text.contains("```") {
                    return true
                }
            }
        }
        return false
    }
}

/// Represents an executed code block
public struct ExecutedCodeBlock: Sendable {
    public let language: String
    public let code: String
    public let output: String?
    public let error: String?

    public init(
        language: String,
        code: String,
        output: String? = nil,
        error: String? = nil
    ) {
        self.language = language
        self.code = code
        self.output = output
        self.error = error
    }

    public var isSuccess: Bool {
        return error == nil
    }
}

// MARK: - Multi-Tool Request Builder

/// Builder for creating requests with multiple tools
public class MultiToolRequestBuilder {
    private var tools: [ExtendedTool] = []
    private var contents: [Content] = []
    private var systemInstruction: SystemInstruction?
    private var generationConfig: GenerationConfig?
    private var safetySettings: [SafetySetting]?

    public init() {}

    @discardableResult
    public func addGoogleSearch() -> Self {
        tools.append(ExtendedTool(googleSearch: GoogleSearch()))
        return self
    }

    @discardableResult
    public func addUrlContext() -> Self {
        tools.append(ExtendedTool(urlContext: UrlContext()))
        return self
    }

    @discardableResult
    public func addCodeExecution() -> Self {
        tools.append(ExtendedTool(codeExecution: CodeExecutionTool()))
        return self
    }

    @discardableResult
    public func addGoogleMaps() -> Self {
        tools.append(ExtendedTool(googleMaps: GoogleMapsTool()))
        return self
    }

    @discardableResult
    public func addFunction(_ declaration: FunctionDeclarationPayload) -> Self {
        tools.append(ExtendedTool(functionDeclarations: [declaration]))
        return self
    }

    @discardableResult
    public func addFunctions(_ declarations: [FunctionDeclarationPayload]) -> Self {
        tools.append(ExtendedTool(functionDeclarations: declarations))
        return self
    }

    @discardableResult
    public func prompt(_ text: String) -> Self {
        contents.append(Content(parts: [Part(text: text)]))
        return self
    }

    @discardableResult
    public func systemInstruction(_ instruction: String) -> Self {
        self.systemInstruction = SystemInstruction(text: instruction)
        return self
    }

    @discardableResult
    public func generationConfig(_ config: GenerationConfig) -> Self {
        self.generationConfig = config
        return self
    }

    @discardableResult
    public func safetySettings(_ settings: [SafetySetting]) -> Self {
        self.safetySettings = settings
        return self
    }

    /// Build the request
    public func build() -> MultiToolRequest {
        return MultiToolRequest(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings,
            tools: tools
        )
    }
}

/// Request with multiple tools
public struct MultiToolRequest: Codable, Sendable {
    public let contents: [Content]
    public let systemInstruction: SystemInstruction?
    public let generationConfig: GenerationConfig?
    public let safetySettings: [SafetySetting]?
    public let tools: [ExtendedTool]

    public init(
        contents: [Content],
        systemInstruction: SystemInstruction? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        tools: [ExtendedTool] = []
    ) {
        self.contents = contents
        self.systemInstruction = systemInstruction
        self.generationConfig = generationConfig
        self.safetySettings = safetySettings
        self.tools = tools
    }
}

// MARK: - Function Declaration Payload

/// Function declaration for the API
public struct FunctionDeclarationPayload: Codable, Sendable {
    public let name: String
    public let description: String
    public let parameters: ParametersSchema?
    public let behavior: FunctionBehavior?

    public enum FunctionBehavior: String, Codable, Sendable {
        case blocking = "BLOCKING"
        case nonBlocking = "NON_BLOCKING"
    }

    public struct ParametersSchema: Codable, Sendable {
        public let type: String
        public let properties: [String: PropertySchema]
        public let required: [String]?

        public init(
            type: String = "object",
            properties: [String: PropertySchema],
            required: [String]? = nil
        ) {
            self.type = type
            self.properties = properties
            self.required = required
        }
    }

    public struct PropertySchema: Codable, Sendable {
        public let type: String
        public let description: String?
        public let `enum`: [String]?

        public init(type: String, description: String? = nil, enumValues: [String]? = nil) {
            self.type = type
            self.description = description
            self.`enum` = enumValues
        }
    }

    public init(
        name: String,
        description: String,
        parameters: ParametersSchema? = nil,
        behavior: FunctionBehavior? = nil
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.behavior = behavior
    }

    /// Create a simple function with no parameters
    public static func simple(name: String, description: String) -> FunctionDeclarationPayload {
        return FunctionDeclarationPayload(name: name, description: description)
    }

    /// Create a function with string parameters
    public static func withStringParams(
        name: String,
        description: String,
        params: [(name: String, description: String, required: Bool)]
    ) -> FunctionDeclarationPayload {
        var properties: [String: PropertySchema] = [:]
        var requiredParams: [String] = []

        for param in params {
            properties[param.name] = PropertySchema(type: "string", description: param.description)
            if param.required {
                requiredParams.append(param.name)
            }
        }

        return FunctionDeclarationPayload(
            name: name,
            description: description,
            parameters: ParametersSchema(
                properties: properties,
                required: requiredParams.isEmpty ? nil : requiredParams
            )
        )
    }

    /// Create a non-blocking function (for async operations in Live API)
    public static func nonBlocking(name: String, description: String, parameters: ParametersSchema? = nil) -> FunctionDeclarationPayload {
        return FunctionDeclarationPayload(
            name: name,
            description: description,
            parameters: parameters,
            behavior: .nonBlocking
        )
    }
}
