import Foundation
import gemini_swfit

/// GeminiConversationManager 使用示例
/// 这个文件展示了如何使用对话管理器来简化多轮对话

public struct ConversationExample {
    
    public static func main() async {
        // 从环境变量获取 API 密钥
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("❌ 错误: 请设置 GEMINI_API_KEY 环境变量")
            print("   例如: export GEMINI_API_KEY=your_api_key_here")
            return
        }
        
        await runExamples(apiKey: apiKey)
    }
    
    static func runExamples(apiKey: String) async {
        print("🚀 Gemini Conversation Manager 使用示例\n")
        
        // 示例 1: 基础对话
        await basicConversationExample(apiKey: apiKey)
        
        // 示例 2: 链式调用
        await chainConversationExample(apiKey: apiKey)
        
        // 示例 3: 角色扮演
        await rolePlayExample(apiKey: apiKey)
        
        // 示例 4: 导入导出对话
        await importExportExample(apiKey: apiKey)
    }
    
    // MARK: - 示例 1: 基础对话
    static func basicConversationExample(apiKey: String) async {
        print("📝 示例 1: 基础对话")
        print("-" * 30)
        
        // 创建对话管理器
        let conversation = GeminiConversationManager(
            apiKey: apiKey,
            systemInstruction: "你是一个友好的助手，总是用中文回答。"
        )
        
        do {
            // 发送第一条消息
            let response1 = try await conversation.sendMessage("你好！我想学 Swift 编程。")
            print("👤 你: 你好！我想学 Swift 编程。")
            print("🤖 助手: \(response1)")
            
            // 发送第二条消息（自动维护对话历史）
            let response2 = try await conversation.sendMessage("请给我一个简单的例子")
            print("👤 你: 请给我一个简单的例子")
            print("🤖 助手: \(response2)")
            
            // 查看对话历史
            print("\n📊 对话统计:")
            print("   消息总数: \(conversation.messageCount)")
            print("   最后一条用户消息: \(conversation.lastUserMessage?.text ?? "无")")
            
        } catch {
            print("❌ 错误: \(error)")
        }
        
        print("\n")
    }
    
    // MARK: - 示例 2: 链式调用
    static func chainConversationExample(apiKey: String) async {
        print("🔗 示例 2: 链式调用")
        print("-" * 30)
        
        // 使用便捷方法创建对话
        let conversation = GeminiConversationManager.startConversation(
            apiKey: apiKey,
            systemInstruction: "你是一个旅行规划师，帮助用户制定旅行计划。"
        )
        
        do {
            // 方法1: 链式调用并获取每次回复
            print("\n📝 方法1: 链式调用并获取每次回复")
            let result1 = try await conversation.continueConversationWithResponse("我想去日本旅行一周")
            print("🤖 回复1: \(result1.response)")
            
            let result2 = try await result1.conversation.continueConversationWithResponse("预算大约 2 万元人民币")
            print("🤖 回复2: \(result2.response)")
            
            let result3 = try await result2.conversation.continueConversationWithResponse("请推荐一个具体的行程安排")
            print("🤖 回复3: \(result3.response)")
            
            print("\n✅ 链式对话完成！")
            
            // 方法2: 批量发送消息
            print("\n📝 方法2: 批量发送消息")
            let questions = [
                "这个行程有什么亮点？",
                "需要准备什么签证？",
                "有什么注意事项？"
            ]
            let batchResponses = try await result3.conversation.sendBatchMessagesWithDetails(questions)
            
            for (index, response) in batchResponses.enumerated() {
                print("🤖 批量回复\(index + 1): \(response.aiResponse)")
                print("   ⏱️  响应时间: \(String(format: "%.2f", response.duration * 1000)) 毫秒")
            }
            
        } catch {
            print("❌ 错误: \(error)")
        }
        
        print("\n")
    }
    
    // MARK: - 示例 3: 角色扮演
    static func rolePlayExample(apiKey: String) async {
        print("🎭 示例 3: 角色扮演")
        print("-" * 30)
        
        // 创建一个厨师角色
        let chefConversation = GeminiConversationManager.rolePlayConversation(
            apiKey: apiKey,
            role: "意大利米其林星级厨师",
            personality: "你热情洋溢，热爱美食，总是用生动的语言描述菜品。你经常在讲解时加入一些意大利语词汇。"
        )
        
        do {
            let response = try await chefConversation.sendMessage(
                "请教我如何制作正宗的意大利肉酱面"
            )
            
            print("👨‍🍳 厨师: \(response)")
            
            // 继续对话
            let followUp = try await chefConversation.sendMessage(
                "有什么配酒建议吗？"
            )
            
            print("👨‍🍳 厨师: \(followUp)")
            
            // 查看格式化的对话历史
            print("\n📋 完整对话记录:")
            print(chefConversation.getFormattedHistory())
            
        } catch {
            print("❌ 错误: \(error)")
        }
        
        print("\n")
    }
    
    // MARK: - 示例 4: 导入导出对话
    static func importExportExample(apiKey: String) async {
        print("💾 示例 4: 导入导出对话")
        print("-" * 30)
        
        let conversation = GeminiConversationManager(
            apiKey: apiKey,
            systemInstruction: "你是一个健身教练，提供专业的健身建议。"
        )
        
        do {
            // 进行一些对话
            try await conversation
                .continueConversation("我想增肌，有什么建议吗？")
                .continueConversation("我每周可以锻炼 4 次")
                .continueConversation("请帮我制定一个简单的计划")
            
            // 导出对话
            let exported = conversation.exportConversation()
            print("📤 导出成功！")
            print("   导出时间: \(exported.exportDate)")
            print("   消息数量: \(exported.messages.count)")
            print("   使用的模型: \(exported.model.displayName)")
            
            // 创建新的对话并导入
            let newConversation = GeminiConversationManager(apiKey: apiKey)
            newConversation.importConversation(exported)
            
            print("\n📥 导入成功！")
            print("   新对话的消息数: \(newConversation.messageCount)")
            
            // 在导入的对话基础上继续
            let additionalResponse = try await newConversation.sendMessage(
                "第一个动作是什么？"
            )
            
            print("🤖 继续对话: \(additionalResponse.prefix(100))...")
            
        } catch {
            print("❌ 错误: \(error)")
        }
        
        print("\n")
    }
}