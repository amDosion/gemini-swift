import XCTest
@testable import gemini_swfit

/// 测试YouTube视频多轮对话功能
final class YouTubeVideoConversationTests: XCTestCase {
    
    private var apiKey: String!
    private var conversationManager: GeminiConversationManager!
    
    override func setUp() {
        super.setUp()
        
        // 从环境变量获取API密钥
        apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        XCTAssertNotNil(apiKey, "请设置 GEMINI_API_KEY 环境变量")
        
        // 创建对话管理器
        conversationManager = GeminiConversationManager(apiKey: apiKey)
    }
    
    override func tearDown() {
        conversationManager = nil
        super.tearDown()
    }
    
    /// 测试基本的YouTube视频多轮对话
    func testYouTubeVideoBasicConversation() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // 第一轮：开始对话
        print("=== 第一轮：开始对话 ===")
        let response1 = try await conversationManager.startYouTubeVideoConversation(
            videoURL: youtubeURL,
            firstMessage: "这个视频是关于什么的？请简要描述。"
        )
        print("AI回复: \(response1)")
        XCTAssertFalse(response1.isEmpty)
        
        // 检查视频上下文已设置
        XCTAssertEqual(conversationManager.currentYouTubeVideo, youtubeURL)
        
        // 第二轮：继续对话
        print("\n=== 第二轮：继续对话 ===")
        let response2 = try await conversationManager.continueYouTubeVideoConversation(
            "视频中提到了哪些关键点？"
        )
        print("AI回复: \(response2)")
        XCTAssertFalse(response2.isEmpty)
        
        // 第三轮：深入询问
        print("\n=== 第三轮：深入询问 ===")
        let response3 = try await conversationManager.continueYouTubeVideoConversation(
            "你能总结一下视频的核心观点吗？"
        )
        print("AI回复: \(response3)")
        XCTAssertFalse(response3.isEmpty)
        
        // 验证对话历史
        XCTAssertEqual(conversationManager.messageCount, 6) // 3用户 + 3AI
        
        print("\n✅ YouTube视频多轮对话测试通过！")
    }
    
    /// 测试切换视频上下文
    func testSwitchVideoContext() async throws {
        let firstVideo = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        let secondVideo = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        
        // 第一个视频对话
        print("=== 第一个视频对话 ===")
        _ = try await conversationManager.startYouTubeVideoConversation(
            videoURL: firstVideo,
            firstMessage: "这个视频是关于什么的？"
        )
        
        // 验证上下文
        XCTAssertEqual(conversationManager.currentYouTubeVideo, firstVideo)
        
        // 切换到第二个视频
        print("\n=== 切换到第二个视频 ===")
        conversationManager.setYouTubeVideoContext(secondVideo)
        XCTAssertEqual(conversationManager.currentYouTubeVideo, secondVideo)
        
        // 使用新上下文对话
        let response = try await conversationManager.continueYouTubeVideoConversation(
            "现在讨论的是哪个视频？"
        )
        print("AI回复: \(response)")
        XCTAssertFalse(response.isEmpty)
        
        print("\n✅ 切换视频上下文测试通过！")
    }
    
    /// 测试消息结构的多媒体支持
    func testMessageContentTypes() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // 测试纯文本消息
        let textMessage = GeminiConversationManager.Message(
            role: .user,
            content: .text("你好")
        )
        XCTAssertEqual(textMessage.text, "你好")
        XCTAssertNil(textMessage.youtubeURL)
        
        // 测试YouTube视频消息
        let videoMessage = GeminiConversationManager.Message(
            role: .user,
            content: .youtubeVideo(url: youtubeURL)
        )
        XCTAssertNil(videoMessage.text)
        XCTAssertEqual(videoMessage.youtubeURL, youtubeURL)
        
        // 测试混合消息
        let mixedMessage = GeminiConversationManager.Message(
            role: .user,
            content: .mixed(text: "请分析这个视频", youtubeURL: youtubeURL)
        )
        XCTAssertEqual(mixedMessage.text, "请分析这个视频")
        XCTAssertEqual(mixedMessage.youtubeURL, youtubeURL)
        
        print("\n✅ 消息内容类型测试通过！")
    }
    
    /// 测试对话历史转换
    func testConversationHistoryConversion() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // 开始对话
        _ = try await conversationManager.startYouTubeVideoConversation(
            videoURL: youtubeURL,
            firstMessage: "这个视频讲了什么？"
        )
        
        // 继续对话
        _ = try await conversationManager.continueYouTubeVideoConversation("视频的主要内容是什么？")
        
        // 获取历史记录
        let history = conversationManager.getConversationHistory()
        XCTAssertEqual(history.count, 4) // 2用户 + 2AI
        
        // 检查第一条用户消息是否包含YouTube视频
        let firstUserMessage = history.first(where: { $0.role == .user })
        XCTAssertEqual(firstUserMessage?.youtubeURL, youtubeURL)
        
        // 检查AI消息是否只有文本
        let firstAIMessage = history.first(where: { $0.role == .model })
        XCTAssertNotNil(firstAIMessage?.text)
        XCTAssertNil(firstAIMessage?.youtubeURL)
        
        print("\n✅ 对话历史转换测试通过！")
    }
    
    /// 测试错误处理
    func testErrorHandling() async throws {
        // 尝试在没有设置视频上下文时继续对话
        do {
            _ = try await conversationManager.continueYouTubeVideoConversation("测试消息")
            XCTFail("应该抛出错误")
        } catch GeminiClient.GeminiError.invalidResponse {
            print("✅ 正确捕获了没有视频上下文的错误")
        } catch {
            XCTFail("错误的错误类型: \(error)")
        }
    }
    
    /// 测试对话导出和导入
    func testConversationExportImport() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // 进行对话
        _ = try await conversationManager.startYouTubeVideoConversation(
            videoURL: youtubeURL,
            firstMessage: "这个视频讲了什么？"
        )
        _ = try await conversationManager.continueYouTubeVideoConversation("请详细说明。")
        
        // 导出对话
        let export = conversationManager.exportConversation()
        XCTAssertEqual(export.messages.count, 4) // 2用户 + 2AI
        XCTAssertEqual(export.systemInstruction, conversationManager.systemInstruction)
        XCTAssertEqual(export.model, conversationManager.model)
        
        // 创建新的对话管理器并导入
        let newManager = GeminiConversationManager(apiKey: apiKey)
        newManager.importConversation(export)
        
        // 验证导入后的状态
        XCTAssertEqual(newManager.messageCount, 4)
        XCTAssertEqual(newManager.systemInstruction, conversationManager.systemInstruction)
        
        // 继续对话
        let response = try await newManager.continueYouTubeVideoConversation("总结一下视频内容。")
        XCTAssertFalse(response.isEmpty)
        
        print("\n✅ 对话导出导入测试通过！")
    }
    
    /// 测试批量消息处理
    func testBatchMessagesWithVideo() async throws {
        let youtubeURL = "https://www.youtube.com/watch?v=9hE5-98ZeCg"
        
        // 设置视频上下文
        conversationManager.setYouTubeVideoContext(youtubeURL)
        
        // 批量发送消息
        let messages = [
            "这个视频的主题是什么？",
            "视频中提到了哪些重要概念？",
            "你能解释一下视频的核心观点吗？"
        ]
        
        let responses = try await conversationManager.sendBatchMessages(messages)
        XCTAssertEqual(responses.count, 3)
        
        for (index, response) in responses.enumerated() {
            print("回复 \(index + 1): \(response)")
            XCTAssertFalse(response.isEmpty)
        }
        
        // 验证消息数量
        XCTAssertEqual(conversationManager.messageCount, 6) // 3用户 + 3AI
        
        print("\n✅ 批量消息处理测试通过！")
    }
}