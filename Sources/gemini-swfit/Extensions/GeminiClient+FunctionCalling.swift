import Foundation

// MARK: - Function Declaration Types

/// Declares a function that can be called by the model
public struct FunctionDeclaration: Codable, Sendable {
    public let name: String
    public let description: String
    public let parameters: FunctionParameters?

    public init(
        name: String,
        description: String,
        parameters: FunctionParameters? = nil
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Parameters for a function declaration
public struct FunctionParameters: Codable, Sendable {
    public let type: String
    public let properties: [String: ParameterProperty]
    public let required: [String]?

    public init(
        type: String = "object",
        properties: [String: ParameterProperty],
        required: [String]? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// A single parameter property
public struct ParameterProperty: Codable, Sendable {
    public let type: String
    public let description: String?
    public let `enum`: [String]?
    public let items: ParameterItems?

    public init(
        type: String,
        description: String? = nil,
        enumValues: [String]? = nil,
        items: ParameterItems? = nil
    ) {
        self.type = type
        self.description = description
        self.enum = enumValues
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case type, description, `enum`, items
    }
}

/// Items definition for array parameters
public struct ParameterItems: Codable, Sendable {
    public let type: String

    public init(type: String) {
        self.type = type
    }
}

// MARK: - Function Calling Tool

/// Tool configuration for function calling
public struct FunctionCallingTool: Codable, Sendable {
    public let functionDeclarations: [FunctionDeclaration]

    public init(functions: [FunctionDeclaration]) {
        self.functionDeclarations = functions
    }
}

// MARK: - Function Call Result

/// Result of a function call from the model
public struct FunctionCallResult: Sendable {
    public let name: String
    public let arguments: [String: Any]

    public init(name: String, arguments: [String: Any]) {
        self.name = name
        self.arguments = arguments
    }

    /// Get argument as a specific type
    public func argument<T>(_ key: String) -> T? {
        return arguments[key] as? T
    }

    /// Get argument as String
    public func stringArgument(_ key: String) -> String? {
        return arguments[key] as? String
    }

    /// Get argument as Int
    public func intArgument(_ key: String) -> Int? {
        if let intValue = arguments[key] as? Int {
            return intValue
        }
        if let doubleValue = arguments[key] as? Double {
            return Int(doubleValue)
        }
        return nil
    }

    /// Get argument as Double
    public func doubleArgument(_ key: String) -> Double? {
        if let doubleValue = arguments[key] as? Double {
            return doubleValue
        }
        if let intValue = arguments[key] as? Int {
            return Double(intValue)
        }
        return nil
    }

    /// Get argument as Bool
    public func boolArgument(_ key: String) -> Bool? {
        return arguments[key] as? Bool
    }

    /// Get argument as Array
    public func arrayArgument<T>(_ key: String) -> [T]? {
        return arguments[key] as? [T]
    }
}

// MARK: - Function Calling Response

/// Response containing potential function calls
public struct FunctionCallingResponse: Sendable {
    public let textResponse: String?
    public let functionCalls: [FunctionCallResult]
    public let rawResponse: GeminiGenerateContentResponse

    public var hasFunctionCalls: Bool {
        return !functionCalls.isEmpty
    }

    public var firstFunctionCall: FunctionCallResult? {
        return functionCalls.first
    }
}

// MARK: - Function Handler Protocol

/// Protocol for implementing function handlers
public protocol FunctionHandler: Sendable {
    var name: String { get }
    var declaration: FunctionDeclaration { get }
    func handle(arguments: [String: Any]) async throws -> [String: Any]
}

// MARK: - Function Registry

/// Registry for managing function handlers
public actor FunctionRegistry {
    private var handlers: [String: any FunctionHandler] = [:]

    public init() {}

    public func register(_ handler: any FunctionHandler) {
        handlers[handler.name] = handler
    }

    public func unregister(_ name: String) {
        handlers.removeValue(forKey: name)
    }

    public func handler(for name: String) -> (any FunctionHandler)? {
        return handlers[name]
    }

    public var declarations: [FunctionDeclaration] {
        return handlers.values.map { $0.declaration }
    }

    public func execute(_ call: FunctionCallResult) async throws -> [String: Any] {
        guard let handler = handlers[call.name] else {
            throw FunctionCallingError.unknownFunction(call.name)
        }
        return try await handler.handle(arguments: call.arguments)
    }
}

// MARK: - Function Calling Errors

public enum FunctionCallingError: Error, LocalizedError {
    case unknownFunction(String)
    case invalidArguments(String)
    case executionFailed(String, Error)
    case noFunctionCall

    public var errorDescription: String? {
        switch self {
        case .unknownFunction(let name):
            return "Unknown function: \(name)"
        case .invalidArguments(let details):
            return "Invalid arguments: \(details)"
        case .executionFailed(let name, let error):
            return "Function '\(name)' failed: \(error.localizedDescription)"
        case .noFunctionCall:
            return "No function call in response"
        }
    }
}

// MARK: - GeminiClient Function Calling Extension

extension GeminiClient {

    /// Generate content with function calling support
    /// - Parameters:
    ///   - model: The model to use
    ///   - text: The prompt text
    ///   - functions: Array of function declarations
    ///   - systemInstruction: Optional system instruction
    ///   - generationConfig: Optional generation configuration
    ///   - safetySettings: Optional safety settings
    /// - Returns: FunctionCallingResponse with potential function calls
    public func generateContentWithFunctions(
        model: Model,
        text: String,
        functions: [FunctionDeclaration],
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> FunctionCallingResponse {
        let response = try await generateContentWithFunctionsRaw(
            model: model,
            text: text,
            functions: functions,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )

        return parseFunctionCallingResponse(response)
    }

    /// Generate content with function calling using a registry
    public func generateContentWithFunctions(
        model: Model,
        text: String,
        registry: FunctionRegistry,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> FunctionCallingResponse {
        let declarations = await registry.declarations

        return try await generateContentWithFunctions(
            model: model,
            text: text,
            functions: declarations,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }

    /// Execute a complete function calling loop
    /// - Parameters:
    ///   - model: The model to use
    ///   - text: The initial prompt
    ///   - registry: Function registry with handlers
    ///   - maxIterations: Maximum number of function call iterations
    ///   - systemInstruction: Optional system instruction
    ///   - generationConfig: Optional generation configuration
    /// - Returns: Final text response after all function calls are resolved
    public func executeFunctionCallingLoop(
        model: Model,
        text: String,
        registry: FunctionRegistry,
        maxIterations: Int = 5,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil
    ) async throws -> String {
        var history: [Content] = []
        var currentPrompt = text
        var iterations = 0

        while iterations < maxIterations {
            // Add user message to history
            history.append(Content(role: .user, parts: [Part(text: currentPrompt)]))

            // Get response with function declarations
            let declarations = await registry.declarations
            let response = try await generateContentWithFunctionsRaw(
                model: model,
                contents: history,
                functions: declarations,
                systemInstruction: systemInstruction,
                generationConfig: generationConfig
            )

            let parsed = parseFunctionCallingResponse(response)

            // Add model response to history
            if let candidate = response.candidates.first {
                history.append(candidate.content)
            }

            // If no function calls, return the text response
            if !parsed.hasFunctionCalls {
                return parsed.textResponse ?? ""
            }

            // Execute function calls and add results to history
            for call in parsed.functionCalls {
                do {
                    let result = try await registry.execute(call)

                    // Add function response to history
                    let functionResponse = FunctionResponse(
                        name: call.name,
                        response: result.mapValues { "\($0)" }
                    )
                    history.append(Content(
                        role: .user,
                        parts: [Part(functionResponse: functionResponse)]
                    ))
                } catch {
                    logger.error("Function execution failed: \(error.localizedDescription)")
                    throw FunctionCallingError.executionFailed(call.name, error)
                }
            }

            // Continue loop with empty prompt (model should respond to function results)
            currentPrompt = ""
            iterations += 1
        }

        throw GeminiError.apiError("Max function calling iterations reached", nil)
    }

    /// Send a function response back to the model
    public func sendFunctionResponse(
        model: Model,
        functionName: String,
        response: [String: String],
        history: [Content],
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil
    ) async throws -> GeminiGenerateContentResponse {
        var contents = history

        let functionResponse = FunctionResponse(name: functionName, response: response)
        contents.append(Content(
            role: .user,
            parts: [Part(functionResponse: functionResponse)]
        ))

        let request = GeminiGenerateContentRequest(
            contents: contents,
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig
        )

        return try await performRequest(model: model, request: request)
    }

    // MARK: - Private Helpers

    private func generateContentWithFunctionsRaw(
        model: Model,
        text: String,
        functions: [FunctionDeclaration],
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let contents = [Content(parts: [Part(text: text)])]
        return try await generateContentWithFunctionsRaw(
            model: model,
            contents: contents,
            functions: functions,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }

    private func generateContentWithFunctionsRaw(
        model: Model,
        contents: [Content],
        functions: [FunctionDeclaration],
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        let currentApiKey = getNextApiKey()

        var components = URLComponents(
            url: baseURL.appendingPathComponent("models/\(model.rawValue):generateContent"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "key", value: currentApiKey)]

        guard let url = components.url else {
            throw GeminiError.invalidURL
        }

        // Build request with function declarations
        var requestBody: [String: Any] = [
            "contents": contents.map { encodeContent($0) }
        ]

        if let instruction = systemInstruction {
            requestBody["systemInstruction"] = [
                "parts": [["text": instruction]]
            ]
        }

        if let config = generationConfig {
            requestBody["generationConfig"] = encodeGenerationConfig(config)
        }

        if let settings = safetySettings {
            requestBody["safetySettings"] = settings.map { encodeSafetySetting($0) }
        }

        // Add function declarations as tools
        let toolsArray: [[String: Any]] = [
            ["functionDeclarations": functions.map { encodeFunctionDeclaration($0) }]
        ]
        requestBody["tools"] = toolsArray

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        logger.info("Making function calling request to: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw GeminiError.apiError(message, httpResponse.statusCode)
                }
                throw GeminiError.apiError("Function calling request failed", httpResponse.statusCode)
            }

            return try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        } catch let error as GeminiError {
            throw error
        } catch {
            logger.error("Function calling request failed: \(error.localizedDescription)")
            throw GeminiError.requestFailed(error)
        }
    }

    private func parseFunctionCallingResponse(_ response: GeminiGenerateContentResponse) -> FunctionCallingResponse {
        var textResponse: String?
        var functionCalls: [FunctionCallResult] = []

        for candidate in response.candidates {
            for part in candidate.content.parts {
                if let text = part.text {
                    textResponse = (textResponse ?? "") + text
                }

                if let functionCall = part.functionCall {
                    // Convert string args to dictionary
                    var arguments: [String: Any] = [:]
                    for (key, value) in functionCall.args {
                        // Try to parse JSON values
                        if let data = value.data(using: .utf8),
                           let parsed = try? JSONSerialization.jsonObject(with: data) {
                            arguments[key] = parsed
                        } else {
                            arguments[key] = value
                        }
                    }

                    functionCalls.append(FunctionCallResult(
                        name: functionCall.name,
                        arguments: arguments
                    ))
                }
            }
        }

        return FunctionCallingResponse(
            textResponse: textResponse,
            functionCalls: functionCalls,
            rawResponse: response
        )
    }

    // MARK: - Encoding Helpers

    private func encodeContent(_ content: Content) -> [String: Any] {
        var result: [String: Any] = [:]

        if let role = content.role {
            result["role"] = role.rawValue
        }

        result["parts"] = content.parts.map { encodePart($0) }

        return result
    }

    private func encodePart(_ part: Part) -> [String: Any] {
        var result: [String: Any] = [:]

        if let text = part.text {
            result["text"] = text
        }

        if let functionCall = part.functionCall {
            result["functionCall"] = [
                "name": functionCall.name,
                "args": functionCall.args
            ]
        }

        if let functionResponse = part.functionResponse {
            result["functionResponse"] = [
                "name": functionResponse.name,
                "response": functionResponse.response
            ]
        }

        return result
    }

    private func encodeGenerationConfig(_ config: GenerationConfig) -> [String: Any] {
        var result: [String: Any] = [:]

        if let candidateCount = config.candidateCount {
            result["candidateCount"] = candidateCount
        }
        if let maxOutputTokens = config.maxOutputTokens {
            result["maxOutputTokens"] = maxOutputTokens
        }
        if let temperature = config.temperature {
            result["temperature"] = temperature
        }
        if let topP = config.topP {
            result["topP"] = topP
        }
        if let topK = config.topK {
            result["topK"] = topK
        }

        return result
    }

    private func encodeSafetySetting(_ setting: SafetySetting) -> [String: Any] {
        return [
            "category": setting.category.rawValue,
            "threshold": setting.threshold.rawValue
        ]
    }

    private func encodeFunctionDeclaration(_ declaration: FunctionDeclaration) -> [String: Any] {
        var result: [String: Any] = [
            "name": declaration.name,
            "description": declaration.description
        ]

        if let params = declaration.parameters {
            var paramsDict: [String: Any] = [
                "type": params.type,
                "properties": params.properties.mapValues { encodeParameterProperty($0) }
            ]

            if let required = params.required {
                paramsDict["required"] = required
            }

            result["parameters"] = paramsDict
        }

        return result
    }

    private func encodeParameterProperty(_ prop: ParameterProperty) -> [String: Any] {
        var result: [String: Any] = ["type": prop.type]

        if let description = prop.description {
            result["description"] = description
        }

        if let enumValues = prop.enum {
            result["enum"] = enumValues
        }

        if let items = prop.items {
            result["items"] = ["type": items.type]
        }

        return result
    }
}

// MARK: - Convenience Function Builders

extension FunctionDeclaration {
    /// Create a simple function with no parameters
    public static func simple(name: String, description: String) -> FunctionDeclaration {
        return FunctionDeclaration(name: name, description: description, parameters: nil)
    }

    /// Create a function with string parameters
    public static func withStringParams(
        name: String,
        description: String,
        params: [(name: String, description: String, required: Bool)]
    ) -> FunctionDeclaration {
        var properties: [String: ParameterProperty] = [:]
        var requiredParams: [String] = []

        for param in params {
            properties[param.name] = ParameterProperty(
                type: "string",
                description: param.description
            )
            if param.required {
                requiredParams.append(param.name)
            }
        }

        return FunctionDeclaration(
            name: name,
            description: description,
            parameters: FunctionParameters(
                properties: properties,
                required: requiredParams.isEmpty ? nil : requiredParams
            )
        )
    }
}
