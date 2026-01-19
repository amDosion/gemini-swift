import Foundation
import SwiftyBeaver

// MARK: - Live API Configuration

/// Configuration for Gemini Live API sessions
public struct LiveAPIConfig: Sendable {
    /// Voice configuration for audio output
    public let voiceConfig: VoiceConfig?

    /// Whether to enable proactive audio (model only responds when relevant)
    public let proactiveAudio: Bool

    /// Whether to enable affective dialog (emotion detection)
    public let affectiveDialog: Bool

    /// Whether to enable thinking in live sessions
    public let enableThinking: Bool

    /// Session timeout in seconds
    public let sessionTimeout: TimeInterval

    /// Audio sample rate
    public let sampleRate: Int

    /// Audio encoding format
    public let audioEncoding: AudioEncoding

    public init(
        voiceConfig: VoiceConfig? = nil,
        proactiveAudio: Bool = false,
        affectiveDialog: Bool = false,
        enableThinking: Bool = false,
        sessionTimeout: TimeInterval = 300,
        sampleRate: Int = 16000,
        audioEncoding: AudioEncoding = .linear16
    ) {
        self.voiceConfig = voiceConfig
        self.proactiveAudio = proactiveAudio
        self.affectiveDialog = affectiveDialog
        self.enableThinking = enableThinking
        self.sessionTimeout = sessionTimeout
        self.sampleRate = sampleRate
        self.audioEncoding = audioEncoding
    }

    /// Default configuration for voice conversations
    public static let voiceConversation = LiveAPIConfig(
        voiceConfig: .default,
        proactiveAudio: true,
        affectiveDialog: true
    )

    /// Configuration for video analysis
    public static let videoAnalysis = LiveAPIConfig(
        proactiveAudio: false,
        affectiveDialog: false,
        sessionTimeout: 600
    )
}

/// Voice configuration for native audio
public struct VoiceConfig: Sendable {
    /// Voice name (e.g., "Puck", "Charon", "Kore")
    public let voiceName: String

    /// Language code (e.g., "en-US", "ja-JP")
    public let languageCode: String

    /// Speaking rate (0.25 to 4.0)
    public let speakingRate: Double

    /// Pitch adjustment (-20.0 to 20.0)
    public let pitch: Double

    public init(
        voiceName: String = "Puck",
        languageCode: String = "en-US",
        speakingRate: Double = 1.0,
        pitch: Double = 0.0
    ) {
        self.voiceName = voiceName
        self.languageCode = languageCode
        self.speakingRate = max(0.25, min(4.0, speakingRate))
        self.pitch = max(-20.0, min(20.0, pitch))
    }

    public static let `default` = VoiceConfig()

    /// Available HD voices
    public static let availableVoices = [
        "Puck", "Charon", "Kore", "Fenrir", "Aoede",
        "Leda", "Orus", "Zephyr", "Clio", "Helios"
    ]
}

/// Audio encoding format
public enum AudioEncoding: String, Sendable {
    case linear16 = "LINEAR16"
    case flac = "FLAC"
    case mulaw = "MULAW"
    case amr = "AMR"
    case amrWb = "AMR_WB"
    case oggOpus = "OGG_OPUS"
    case speexWithHeaderByte = "SPEEX_WITH_HEADER_BYTE"
    case mp3 = "MP3"
}

// MARK: - Live Session

/// Represents an active Live API session
public actor LiveSession {
    private let sessionId: String
    private let config: LiveAPIConfig
    private let apiKey: String
    private let model: String
    private var webSocket: URLSessionWebSocketTask?
    private var isConnected: Bool = false
    private var messageHandlers: [(LiveMessage) -> Void] = []
    private var errorHandlers: [(Error) -> Void] = []
    private let logger: SwiftyBeaver.Type

    public init(
        apiKey: String,
        model: String = "gemini-2.5-flash-preview-native-audio-dialog",
        config: LiveAPIConfig = .voiceConversation,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.sessionId = UUID().uuidString
        self.config = config
        self.apiKey = apiKey
        self.model = model
        self.logger = logger
    }

    /// Connect to the Live API
    public func connect() async throws {
        let wsURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)"

        guard let url = URL(string: wsURL) else {
            throw LiveAPIError.invalidURL
        }

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        // Send setup message
        try await sendSetupMessage()

        isConnected = true
        logger.info("Live session connected: \(sessionId)")

        // Start receiving messages
        Task {
            await receiveMessages()
        }
    }

    /// Disconnect from the Live API
    public func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        isConnected = false
        logger.info("Live session disconnected: \(sessionId)")
    }

    /// Send audio data to the session
    public func sendAudio(_ audioData: Data) async throws {
        guard isConnected else {
            throw LiveAPIError.notConnected
        }

        let message = LiveClientMessage.realtimeInput(
            mediaChunks: [MediaChunk(mimeType: "audio/pcm", data: audioData.base64EncodedString())]
        )

        try await sendMessage(message)
    }

    /// Send text input to the session
    public func sendText(_ text: String) async throws {
        guard isConnected else {
            throw LiveAPIError.notConnected
        }

        let message = LiveClientMessage.clientContent(
            turns: [Turn(role: "user", parts: [TurnPart(text: text)])],
            turnComplete: true
        )

        try await sendMessage(message)
    }

    /// Send video frame to the session
    public func sendVideoFrame(_ frameData: Data, mimeType: String = "image/jpeg") async throws {
        guard isConnected else {
            throw LiveAPIError.notConnected
        }

        let message = LiveClientMessage.realtimeInput(
            mediaChunks: [MediaChunk(mimeType: mimeType, data: frameData.base64EncodedString())]
        )

        try await sendMessage(message)
    }

    /// Register a message handler
    public func onMessage(_ handler: @escaping (LiveMessage) -> Void) {
        messageHandlers.append(handler)
    }

    /// Register an error handler
    public func onError(_ handler: @escaping (Error) -> Void) {
        errorHandlers.append(handler)
    }

    // MARK: - Private Methods

    private func sendSetupMessage() async throws {
        var setupConfig: [String: Any] = [
            "model": "models/\(model)"
        ]

        // Add generation config
        var generationConfig: [String: Any] = [:]

        if let voiceConfig = config.voiceConfig {
            generationConfig["speechConfig"] = [
                "voiceConfig": [
                    "prebuiltVoiceConfig": [
                        "voiceName": voiceConfig.voiceName
                    ]
                ]
            ]
        }

        if config.enableThinking {
            generationConfig["thinkingConfig"] = [
                "thinkingBudget": -1  // Dynamic thinking
            ]
        }

        if !generationConfig.isEmpty {
            setupConfig["generationConfig"] = generationConfig
        }

        let setupMessage: [String: Any] = ["setup": setupConfig]

        let data = try JSONSerialization.data(withJSONObject: setupMessage)
        try await webSocket?.send(.data(data))
    }

    private func sendMessage(_ message: LiveClientMessage) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        try await webSocket?.send(.data(data))
    }

    private func receiveMessages() async {
        while isConnected {
            do {
                guard let webSocket = webSocket else { break }

                let message = try await webSocket.receive()

                switch message {
                case .data(let data):
                    if let liveMessage = try? JSONDecoder().decode(LiveMessage.self, from: data) {
                        for handler in messageHandlers {
                            handler(liveMessage)
                        }
                    }
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let liveMessage = try? JSONDecoder().decode(LiveMessage.self, from: data) {
                        for handler in messageHandlers {
                            handler(liveMessage)
                        }
                    }
                @unknown default:
                    break
                }
            } catch {
                for handler in errorHandlers {
                    handler(error)
                }
                break
            }
        }
    }
}

// MARK: - Live API Errors

public enum LiveAPIError: Error, LocalizedError {
    case invalidURL
    case notConnected
    case connectionFailed(Error)
    case sendFailed(Error)
    case sessionExpired
    case invalidMessage

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .notConnected:
            return "Not connected to Live API"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .sendFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        case .sessionExpired:
            return "Live session has expired"
        case .invalidMessage:
            return "Invalid message format"
        }
    }
}

// MARK: - Live API Messages

/// Message sent from client to server
public enum LiveClientMessage: Codable, Sendable {
    case setup(SetupMessage)
    case clientContent(turns: [Turn], turnComplete: Bool)
    case realtimeInput(mediaChunks: [MediaChunk])
    case toolResponse(functionResponses: [FunctionResponseMessage])

    public struct SetupMessage: Codable, Sendable {
        public let model: String
        public let generationConfig: [String: AnyCodable]?
        public let systemInstruction: SystemInstruction?
        public let tools: [Tool]?
    }

    private enum CodingKeys: String, CodingKey {
        case setup, clientContent, realtimeInput, toolResponse
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .setup(let message):
            try container.encode(message, forKey: .setup)
        case .clientContent(let turns, let turnComplete):
            try container.encode(["turns": turns, "turnComplete": turnComplete] as [String: Any], forKey: .clientContent)
        case .realtimeInput(let mediaChunks):
            try container.encode(["mediaChunks": mediaChunks], forKey: .realtimeInput)
        case .toolResponse(let responses):
            try container.encode(["functionResponses": responses], forKey: .toolResponse)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let setup = try? container.decode(SetupMessage.self, forKey: .setup) {
            self = .setup(setup)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown message type"))
        }
    }
}

/// Turn in a conversation
public struct Turn: Codable, Sendable {
    public let role: String
    public let parts: [TurnPart]

    public init(role: String, parts: [TurnPart]) {
        self.role = role
        self.parts = parts
    }
}

/// Part of a turn
public struct TurnPart: Codable, Sendable {
    public let text: String?
    public let inlineData: InlineData?
    public let functionCall: FunctionCall?
    public let functionResponse: FunctionResponse?

    public init(
        text: String? = nil,
        inlineData: InlineData? = nil,
        functionCall: FunctionCall? = nil,
        functionResponse: FunctionResponse? = nil
    ) {
        self.text = text
        self.inlineData = inlineData
        self.functionCall = functionCall
        self.functionResponse = functionResponse
    }
}

/// Media chunk for streaming
public struct MediaChunk: Codable, Sendable {
    public let mimeType: String
    public let data: String

    public init(mimeType: String, data: String) {
        self.mimeType = mimeType
        self.data = data
    }
}

/// Function response message
public struct FunctionResponseMessage: Codable, Sendable {
    public let name: String
    public let id: String
    public let response: [String: AnyCodable]

    public init(name: String, id: String, response: [String: AnyCodable]) {
        self.name = name
        self.id = id
        self.response = response
    }
}

/// Message received from server
public struct LiveMessage: Codable, Sendable {
    public let setupComplete: SetupComplete?
    public let serverContent: ServerContent?
    public let toolCall: ToolCallMessage?
    public let toolCallCancellation: ToolCallCancellation?

    public struct SetupComplete: Codable, Sendable {}

    public struct ServerContent: Codable, Sendable {
        public let modelTurn: ModelTurn?
        public let turnComplete: Bool?
        public let interrupted: Bool?
    }

    public struct ModelTurn: Codable, Sendable {
        public let parts: [TurnPart]
    }

    public struct ToolCallMessage: Codable, Sendable {
        public let functionCalls: [FunctionCallWithId]
    }

    public struct FunctionCallWithId: Codable, Sendable {
        public let name: String
        public let id: String
        public let args: [String: AnyCodable]
    }

    public struct ToolCallCancellation: Codable, Sendable {
        public let ids: [String]
    }
}

// MARK: - AnyCodable Helper

public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Extension for encoding [String: Any]

extension KeyedEncodingContainer {
    mutating func encode(_ value: [String: Any], forKey key: Key) throws {
        let anyCodable = value.mapValues { AnyCodable($0) }
        try encode(anyCodable, forKey: key)
    }
}
