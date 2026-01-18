import Foundation

// MARK: - Streaming Response Types

/// A chunk of a streaming response
public struct StreamingChunk: Sendable {
    public let text: String?
    public let isComplete: Bool
    public let finishReason: FinishReason?
    public let safetyRatings: [SafetyRating]?
    public let index: Int

    public init(
        text: String?,
        isComplete: Bool,
        finishReason: FinishReason? = nil,
        safetyRatings: [SafetyRating]? = nil,
        index: Int = 0
    ) {
        self.text = text
        self.isComplete = isComplete
        self.finishReason = finishReason
        self.safetyRatings = safetyRatings
        self.index = index
    }
}

/// Accumulated streaming response
public struct StreamingAccumulator: Sendable {
    public private(set) var fullText: String = ""
    public private(set) var chunks: [StreamingChunk] = []
    public private(set) var isComplete: Bool = false
    public private(set) var finishReason: FinishReason?

    public mutating func append(_ chunk: StreamingChunk) {
        chunks.append(chunk)
        if let text = chunk.text {
            fullText += text
        }
        if chunk.isComplete {
            isComplete = true
            finishReason = chunk.finishReason
        }
    }
}

// MARK: - Streaming Configuration

/// Configuration for streaming requests
public struct StreamingConfig: Sendable {
    /// Buffer size for reading stream data
    public let bufferSize: Int

    /// Timeout for individual chunks in seconds
    public let chunkTimeout: TimeInterval

    /// Whether to automatically accumulate text
    public let autoAccumulate: Bool

    public static let `default` = StreamingConfig(
        bufferSize: 4096,
        chunkTimeout: 30.0,
        autoAccumulate: true
    )

    public init(
        bufferSize: Int = 4096,
        chunkTimeout: TimeInterval = 30.0,
        autoAccumulate: Bool = true
    ) {
        self.bufferSize = max(1024, bufferSize)
        self.chunkTimeout = max(5.0, chunkTimeout)
        self.autoAccumulate = autoAccumulate
    }
}

// MARK: - SSE Parser

/// Parser for Server-Sent Events (SSE) format
internal struct SSEParser {
    private var buffer: String = ""

    mutating func parse(_ data: Data) -> [SSEEvent] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        buffer += text
        var events: [SSEEvent] = []

        // Split by double newline (event separator)
        let eventStrings = buffer.components(separatedBy: "\n\n")

        // Keep the last incomplete event in buffer
        if !buffer.hasSuffix("\n\n") && eventStrings.count > 1 {
            buffer = eventStrings.last ?? ""
        } else if buffer.hasSuffix("\n\n") {
            buffer = ""
        } else {
            buffer = eventStrings.last ?? ""
        }

        // Parse complete events (all but possibly the last)
        let completeEvents = buffer.isEmpty ? eventStrings : eventStrings.dropLast()

        for eventString in completeEvents {
            if let event = parseEvent(eventString) {
                events.append(event)
            }
        }

        return events
    }

    private func parseEvent(_ eventString: String) -> SSEEvent? {
        var eventType: String?
        var data: String = ""
        var id: String?

        let lines = eventString.components(separatedBy: "\n")

        for line in lines {
            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let dataLine = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if !data.isEmpty {
                    data += "\n"
                }
                data += dataLine
            } else if line.hasPrefix("id:") {
                id = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
        }

        guard !data.isEmpty else { return nil }

        return SSEEvent(type: eventType, data: data, id: id)
    }
}

/// Represents a Server-Sent Event
internal struct SSEEvent {
    let type: String?
    let data: String
    let id: String?
}

// MARK: - GeminiClient Streaming Extension

extension GeminiClient {

    /// Generate content with streaming response
    /// - Parameters:
    ///   - model: The model to use
    ///   - text: The prompt text
    ///   - systemInstruction: Optional system instruction
    ///   - generationConfig: Optional generation configuration
    ///   - safetySettings: Optional safety settings
    ///   - streamingConfig: Configuration for streaming behavior
    /// - Returns: An AsyncThrowingStream of StreamingChunk
    public func generateContentStream(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        streamingConfig: StreamingConfig = .default
    ) -> AsyncThrowingStream<StreamingChunk, Error> {
        let request = GeminiGenerateContentRequest(
            contents: [Content(parts: [Part(text: text)])],
            systemInstruction: systemInstruction != nil ? SystemInstruction(text: systemInstruction!) : nil,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )

        return generateContentStream(model: model, request: request, streamingConfig: streamingConfig)
    }

    /// Generate content with streaming response using a full request
    /// - Parameters:
    ///   - model: The model to use
    ///   - request: The complete request
    ///   - streamingConfig: Configuration for streaming behavior
    /// - Returns: An AsyncThrowingStream of StreamingChunk
    public func generateContentStream(
        model: Model,
        request: GeminiGenerateContentRequest,
        streamingConfig: StreamingConfig = .default
    ) -> AsyncThrowingStream<StreamingChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await performStreamingRequest(
                        model: model,
                        request: request,
                        config: streamingConfig,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Collect all streaming chunks into a single response
    public func generateContentStreamCollected(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) async throws -> StreamingAccumulator {
        var accumulator = StreamingAccumulator()

        let stream = generateContentStream(
            model: model,
            text: text,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )

        for try await chunk in stream {
            accumulator.append(chunk)
        }

        return accumulator
    }

    // MARK: - Private Streaming Implementation

    private func performStreamingRequest(
        model: Model,
        request: GeminiGenerateContentRequest,
        config: StreamingConfig,
        continuation: AsyncThrowingStream<StreamingChunk, Error>.Continuation
    ) async throws {
        let currentApiKey = getNextApiKey()

        // Use streamGenerateContent endpoint for streaming
        var components = URLComponents(
            url: baseURL.appendingPathComponent("models/\(model.rawValue):streamGenerateContent"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "key", value: currentApiKey),
            URLQueryItem(name: "alt", value: "sse")
        ]

        guard let url = components.url else {
            throw GeminiError.invalidURL
        }

        logger.info("Making streaming request to: \(url.absoluteString)")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = config.chunkTimeout

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        // Use bytes for streaming
        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiError.apiError("Streaming request failed", httpResponse.statusCode)
        }

        var parser = SSEParser()
        var chunkIndex = 0
        var buffer = Data()

        for try await byte in bytes {
            buffer.append(byte)

            // Try to parse when we have enough data
            if buffer.count >= config.bufferSize || byte == UInt8(ascii: "\n") {
                let events = parser.parse(buffer)
                buffer.removeAll()

                for event in events {
                    if let chunk = try parseStreamingEvent(event, index: chunkIndex) {
                        continuation.yield(chunk)
                        chunkIndex += 1

                        if chunk.isComplete {
                            continuation.finish()
                            return
                        }
                    }
                }
            }
        }

        // Parse any remaining data
        if !buffer.isEmpty {
            let events = parser.parse(buffer)
            for event in events {
                if let chunk = try parseStreamingEvent(event, index: chunkIndex) {
                    continuation.yield(chunk)
                    chunkIndex += 1
                }
            }
        }

        continuation.finish()
    }

    private func parseStreamingEvent(_ event: SSEEvent, index: Int) throws -> StreamingChunk? {
        // Check for [DONE] signal
        if event.data == "[DONE]" {
            return StreamingChunk(text: nil, isComplete: true, index: index)
        }

        // Parse JSON response
        guard let data = event.data.data(using: .utf8) else {
            return nil
        }

        do {
            let response = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)

            guard let candidate = response.candidates.first else {
                return nil
            }

            let text = candidate.content.parts.compactMap { $0.text }.joined()
            let isComplete = candidate.finishReason != nil && candidate.finishReason != .unspecified

            return StreamingChunk(
                text: text.isEmpty ? nil : text,
                isComplete: isComplete,
                finishReason: candidate.finishReason,
                safetyRatings: candidate.safetyRatings,
                index: index
            )
        } catch {
            logger.warning("Failed to parse streaming chunk: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Streaming with Callbacks

extension GeminiClient {

    /// Generate content with streaming using callbacks
    /// - Parameters:
    ///   - model: The model to use
    ///   - text: The prompt text
    ///   - onChunk: Called for each received chunk
    ///   - onComplete: Called when streaming is complete
    ///   - onError: Called if an error occurs
    public func generateContentStream(
        model: Model,
        text: String,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        onChunk: @escaping @Sendable (StreamingChunk) -> Void,
        onComplete: @escaping @Sendable (StreamingAccumulator) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) -> Task<Void, Never> {
        Task {
            var accumulator = StreamingAccumulator()

            do {
                let stream = generateContentStream(
                    model: model,
                    text: text,
                    systemInstruction: systemInstruction,
                    generationConfig: generationConfig,
                    safetySettings: safetySettings
                )

                for try await chunk in stream {
                    accumulator.append(chunk)
                    onChunk(chunk)
                }

                onComplete(accumulator)
            } catch {
                onError(error)
            }
        }
    }
}
