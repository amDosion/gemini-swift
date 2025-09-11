import Foundation

/// 对话管理器 - 简化多轮对话的使用
public class GeminiConversationManager {
    
    // MARK: - Properties
    
    /// Gemini 客户端
    private let client: GeminiClient
    
    /// 对话历史
    private var messages: [Message] = []
    
    /// 系统指令
    public var systemInstruction: String?
    
    /// 使用的模型
    public let model: GeminiClient.Model
    
    /// 生成配置
    public var generationConfig: GenerationConfig?
    
    /// 安全设置
    public var safetySettings: [SafetySetting]?
    
    /// 当前YouTube视频上下文
    public var currentYouTubeVideo: String?
    
    // MARK: - Message Structure
    
    /// 消息内容类型
    public enum MessageContent {
        case text(String)
        case youtubeVideo(url: String)
        case mixed(text: String, youtubeURL: String?)
    }
    
    /// 消息结构
    public struct Message {
        public let role: Role
        public let content: MessageContent
        public let timestamp: Date
        
        public init(role: Role, content: MessageContent, timestamp: Date = Date()) {
            self.role = role
            self.content = content
            self.timestamp = timestamp
        }
        
        /// 获取文本内容（如果存在）
        public var text: String? {
            switch content {
            case .text(let text):
                return text
            case .youtubeVideo:
                return nil
            case .mixed(let text, _):
                return text
            }
        }
        
        /// 获取YouTube URL（如果存在）
        public var youtubeURL: String? {
            switch content {
            case .text:
                return nil
            case .youtubeVideo(let url):
                return url
            case .mixed(_, let youtubeURL):
                return youtubeURL
            }
        }
    }
    
    /// 消息角色
    public enum Role: String, CaseIterable {
        case user = "user"
        case model = "model"
        
        public var displayName: String {
            switch self {
            case .user: return "用户"
            case .model: return "AI助手"
            }
        }
    }
    
    // MARK: - Initialization
    
    /// 初始化对话管理器
    /// - Parameters:
    ///   - apiKey: Gemini API 密钥
    ///   - model: 使用的模型
    ///   - systemInstruction: 系统指令（可选）
    public init(
        apiKey: String,
        model: GeminiClient.Model = .gemini25Flash,
        systemInstruction: String? = nil
    ) {
        self.client = GeminiClient(apiKey: apiKey)
        self.model = model
        self.systemInstruction = systemInstruction
    }
    
    /// 使用现有客户端初始化
    public init(
        client: GeminiClient,
        model: GeminiClient.Model = .gemini25Flash,
        systemInstruction: String? = nil
    ) {
        self.client = client
        self.model = model
        self.systemInstruction = systemInstruction
    }
    
    // MARK: - Public Methods
    
    /// 发送消息并获取回复
    /// - Parameter message: 用户消息
    /// - Returns: AI 的回复
    public func sendMessage(_ message: String) async throws -> String {
        // 添加用户消息到历史
        let userMessage = Message(role: .user, content: .text(message))
        messages.append(userMessage)
        
        // 转换为 Gemini 格式
        var history = convertToGeminiHistory()
        
        // 发送请求
        let response = try await client.chat(
            model: model,
            message: message,
            conversationHistory: &history,
            systemInstruction: systemInstruction,
            temperature: generationConfig?.temperature,
            maxOutputTokens: generationConfig?.maxOutputTokens
        )
        
        // 添加 AI 回复到历史
        let assistantMessage = Message(role: .model, content: .text(response))
        messages.append(assistantMessage)
        
        return response
    }
    
    /// 发送消息并获取结构化回复
    /// - Parameter message: 用户消息
    /// - Returns: 包含元数据的回复
    public func sendMessageWithMetadata(_ message: String) async throws -> ChatResponse {
        let startTime = Date()
        let response = try await sendMessage(message)
        let endTime = Date()
        
        return ChatResponse(
            message: response,
            timestamp: endTime,
            duration: endTime.timeIntervalSince(startTime),
            messageCount: messages.count
        )
    }
    
    /// 继续对话（链式调用）
    /// - Parameter message: 用户消息
    /// - Returns: 自身，支持链式调用
    @discardableResult
    public func continueConversation(_ message: String) async throws -> GeminiConversationManager {
        _ = try await sendMessage(message)
        return self
    }
    
    /// 继续对话并获取AI回复
    /// - Parameter message: 用户消息
    /// - Returns: 包含AI回复和对话管理器的元组
    public func continueConversationWithResponse(_ message: String) async throws -> (response: String, conversation: GeminiConversationManager) {
        let response = try await sendMessage(message)
        return (response: response, conversation: self)
    }
    
    /// 批量发送消息并获取所有回复
    /// - Parameter messages: 消息数组
    /// - Returns: 所有回复的数组
    public func sendBatchMessages(_ messages: [String]) async throws -> [String] {
        var responses: [String] = []
        for message in messages {
            let response = try await sendMessage(message)
            responses.append(response)
        }
        return responses
    }
    
    /// 批量发送消息并获取详细回复
    /// - Parameter messages: 消息数组
    /// - Returns: 包含每个回复详细信息的数组
    public func sendBatchMessagesWithDetails(_ messages: [String]) async throws -> [BatchMessageResponse] {
        var responses: [BatchMessageResponse] = []
        for (index, message) in messages.enumerated() {
            let startTime = Date()
            let response = try await sendMessage(message)
            let endTime = Date()
            
            let detail = BatchMessageResponse(
                messageIndex: index,
                userMessage: message,
                aiResponse: response,
                timestamp: endTime,
                duration: endTime.timeIntervalSince(startTime),
                totalMessageCount: messages.count
            )
            responses.append(detail)
        }
        return responses
    }
    
    /// 获取完整的对话历史
    /// - Returns: 所有消息
    public func getConversationHistory() -> [Message] {
        return messages
    }
    
    /// 获取格式化的对话历史
    /// - Returns: 格式化的字符串
    public func getFormattedHistory() -> String {
        return messages.map { message in
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .medium
            let timeString = timeFormatter.string(from: message.timestamp)
            
            return "[\(timeString)] \(message.role.displayName): \(message.content)"
        }.joined(separator: "\n")
    }
    
    /// 清空对话历史
    public func clearHistory() {
        messages.removeAll()
    }
    
    /// 获取消息数量
    public var messageCount: Int {
        return messages.count
    }
    
    /// 获取最后一条消息
    public var lastMessage: Message? {
        return messages.last
    }
    
    /// 获取最后一条用户消息
    public var lastUserMessage: Message? {
        return messages.last(where: { $0.role == .user })
    }
    
    /// 获取最后一条 AI 回复
    public var lastAssistantMessage: Message? {
        return messages.last(where: { $0.role == .model })
    }
    
    /// 设置系统指令
    public func setSystemInstruction(_ instruction: String?) {
        systemInstruction = instruction
    }
    
    /// 设置生成配置
    public func setGenerationConfig(_ config: GenerationConfig?) {
        generationConfig = config
    }
    
    /// 设置安全设置
    public func setSafetySettings(_ settings: [SafetySetting]?) {
        safetySettings = settings
    }
    
    /// 设置YouTube视频上下文
    /// - Parameter videoURL: YouTube视频URL
    public func setYouTubeVideoContext(_ videoURL: String?) {
        currentYouTubeVideo = videoURL
    }
    
    /// 发送消息并获取回复（带YouTube视频上下文）
    /// - Parameters:
    ///   - message: 用户消息
    ///   - youtubeURL: YouTube视频URL（可选，如果不提供则使用当前上下文）
    /// - Returns: AI的回复
    public func sendMessage(_ message: String, withYouTubeVideo youtubeURL: String? = nil) async throws -> String {
        // 确定使用的YouTube URL
        let videoURL = youtubeURL ?? currentYouTubeVideo
        
        // 创建消息内容
        let content: MessageContent
        if let videoURL = videoURL {
            content = .mixed(text: message, youtubeURL: videoURL)
        } else {
            content = .text(message)
        }
        
        // 添加用户消息到历史
        let userMessage = Message(role: .user, content: content)
        messages.append(userMessage)
        
        // 转换为 Gemini 格式
        var history = convertToGeminiHistory()
        
        // 发送请求
        let response: String
        if let videoURL = videoURL {
            // 使用YouTube视频上下文
            response = try await client.chatWithYouTubeVideo(
                model: model,
                message: message,
                youtubeURL: videoURL,
                conversationHistory: &history,
                systemInstruction: systemInstruction,
                temperature: generationConfig?.temperature,
                maxOutputTokens: generationConfig?.maxOutputTokens
            )
        } else {
            // 普通文本对话
            response = try await client.chat(
                model: model,
                message: message,
                conversationHistory: &history,
                systemInstruction: systemInstruction,
                temperature: generationConfig?.temperature,
                maxOutputTokens: generationConfig?.maxOutputTokens
            )
        }
        
        // 添加 AI 回复到历史
        let assistantMessage = Message(role: .model, content: .text(response))
        messages.append(assistantMessage)
        
        return response
    }
    
    /// 开始YouTube视频对话（设置视频上下文并发送第一条消息）
    /// - Parameters:
    ///   - videoURL: YouTube视频URL
    ///   - message: 第一条用户消息
    /// - Returns: AI的回复
    public func startYouTubeVideoConversation(videoURL: String, firstMessage: String) async throws -> String {
        // 设置视频上下文
        currentYouTubeVideo = videoURL
        
        // 发送第一条消息
        return try await sendMessage(firstMessage, withYouTubeVideo: videoURL)
    }
    
    /// 继续YouTube视频对话
    /// - Parameter message: 用户消息
    /// - Returns: AI的回复
    public func continueYouTubeVideoConversation(_ message: String) async throws -> String {
        guard currentYouTubeVideo != nil else {
            throw GeminiClient.GeminiError.invalidResponse
        }
        
        return try await sendMessage(message)
    }
    
    /// 导出对话
    public func exportConversation() -> ConversationExport {
        return ConversationExport(
            messages: messages,
            systemInstruction: systemInstruction,
            model: model,
            exportDate: Date()
        )
    }
    
    /// 从导出恢复对话
    public func importConversation(_ export: ConversationExport) {
        messages = export.messages
        systemInstruction = export.systemInstruction
        // 注意：模型可能不同，根据需要处理
    }
    
    // MARK: - Private Methods
    
    /// 转换为 Gemini 格式的历史记录
    private func convertToGeminiHistory() -> [Content] {
        return messages.compactMap { message in
            switch message.role {
            case .user:
                let parts: [Part]
                switch message.content {
                case .text(let text):
                    parts = [Part(text: text)]
                case .youtubeVideo(let url):
                    parts = [Part(fileDataYouTube: YouTubeVideoData(fileUri: url))]
                case .mixed(let text, let youtubeURL):
                    var mixedParts: [Part] = []
                    if !text.isEmpty {
                        mixedParts.append(Part(text: text))
                    }
                    if let youtubeURL = youtubeURL {
                        mixedParts.append(Part(fileDataYouTube: YouTubeVideoData(fileUri: youtubeURL)))
                    }
                    parts = mixedParts
                }
                return Content(role: .user, parts: parts)
            case .model:
                guard let text = message.text else { return nil }
                return Content(role: .model, parts: [Part(text: text)])
            }
        }
    }
}

// MARK: - Supporting Structures

/// 聊天回复（包含元数据）
public struct ChatResponse {
    public let message: String
    public let timestamp: Date
    public let duration: TimeInterval
    public let messageCount: Int
}

/// 批量消息回复详细信息
public struct BatchMessageResponse {
    public let messageIndex: Int
    public let userMessage: String
    public let aiResponse: String
    public let timestamp: Date
    public let duration: TimeInterval
    public let totalMessageCount: Int
}

/// 对话导出结构
public struct ConversationExport {
    public let messages: [GeminiConversationManager.Message]
    public let systemInstruction: String?
    public let model: GeminiClient.Model
    public let exportDate: Date
}

// MARK: - Convenience Extensions

extension GeminiConversationManager {
    
    /// 快速开始一个新对话
    public static func startConversation(
        apiKey: String,
        systemInstruction: String? = nil
    ) -> GeminiConversationManager {
        return GeminiConversationManager(
            apiKey: apiKey,
            systemInstruction: systemInstruction
        )
    }
    
    /// 创建一个角色扮演对话
    public static func rolePlayConversation(
        apiKey: String,
        role: String,
        personality: String? = nil
    ) -> GeminiConversationManager {
        let instruction = personality != nil 
            ? "You are \(role). \(personality!)"
            : "You are \(role)."
        
        return GeminiConversationManager(
            apiKey: apiKey,
            systemInstruction: instruction
        )
    }
}