import Foundation
import gemini_swfit

/// Image Analysis Example
/// 展示如何使用 Gemini Swift 库进行图片理解和分析

public struct ImageAnalysisExample {
    
    public static func main() async {
        // 从环境变量获取 API 密钥
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("❌ 错误: 请设置 GEMINI_API_KEY 环境变量")
            print("   例如: export GEMINI_API_KEY=your_api_key_here")
            return
        }
        
        await runImageAnalysisExamples(apiKey: apiKey)
    }
    
    static func runImageAnalysisExamples(apiKey: String) async {
        print("🖼️ Gemini 图片分析示例\n")
        
        // 示例 1: 基础图片分析
        await basicImageAnalysis(apiKey: apiKey)
        
        // 示例 2: 多模型对比分析
        await multiModelComparison(apiKey: apiKey)
        
        // 示例 3: 图片+对话组合
        await imageWithConversation(apiKey: apiKey)
        
        // 示例 4: 批量图片分析
        await batchImageAnalysis(apiKey: apiKey)
    }
    
    // MARK: - 示例 1: 基础图片分析
    static func basicImageAnalysis(apiKey: String) async {
        print("📝 示例 1: 基础图片分析")
        print("-" * 30)
        
        let client = GeminiClient(apiKey: apiKey)
        
        do {
            // 加载现有测试图片
            guard let imagePath = Bundle.main.path(forResource: "image", ofType: "png") else {
                print("❌ 错误: 找不到测试图片文件")
                return
            }
            let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            
            // 分析图片
            let response = try await client.analyzeImage(
                model: .gemini25Flash,
                prompt: "Please describe this image in detail. What colors, shapes, and patterns do you see?",
                imageData: imageData,
                mimeType: "image/png"
            )
            
            print("🖼️ 加载了测试图片")
            print("🤖 AI 分析结果:")
            print("   \(response)")
            
        } catch {
            print("❌ 错误: \(error)")
        }
        
        print("\n")
    }
    
    // MARK: - 示例 2: 多模型对比分析
    static func multiModelComparison(apiKey: String) async {
        print("🔄 示例 2: 多模型对比分析")
        print("-" * 30)
        
        let client = GeminiClient(apiKey: apiKey)
        
        do {
            // 加载现有测试图片
            guard let imagePath = Bundle.main.path(forResource: "image", ofType: "png") else {
                print("❌ 错误: 找不到测试图片文件")
                return
            }
            let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            let prompt = "Analyze this image and describe the visual patterns you observe."
            
            // 测试不同模型
            let models: [GeminiClient.Model] = [
                .gemini25Flash,
                .gemini25FlashImagePreview,
                .gemini25Pro
            ]
            
            for model in models {
                if model.supportsMultimodal {
                    print("🔍 使用模型: \(model.displayName)")
                    
                    let startTime = Date()
                    let response = try await client.analyzeImage(
                        model: model,
                        prompt: prompt,
                        imageData: imageData,
                        mimeType: "image/png"
                    )
                    let duration = Date().timeIntervalSince(startTime)
                    
                    print("   ⏱️ 响应时间: \(String(format: "%.2f", duration * 1000)) 毫秒")
                    print("   🤖 分析结果: \(response.prefix(150))...")
                    print("")
                }
            }
            
        } catch {
            print("❌ 错误: \(error)")
        }
        
        print("\n")
    }
    
    // MARK: - 示例 3: 图片+对话组合
    static func imageWithConversation(apiKey: String) async {
        print("💬 示例 3: 图片+对话组合")
        print("-" * 30)
        
        let client = GeminiClient(apiKey: apiKey)
        
        do {
            // 加载现有测试图片
            guard let imagePath = Bundle.main.path(forResource: "image", ofType: "png") else {
                print("❌ 错误: 找不到测试图片文件")
                return
            }
            let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            var conversationHistory: [Content] = []
            
            // 第一轮：分析图片
            print("👤 用户: [上传了一张测试图片] 这张图片显示了什么？")
            
            let response1 = try await client.generateContentWithImage(
                model: .gemini25Flash,
                text: "这张图片显示了什么？请详细描述。",
                imageData: imageData,
                mimeType: "image/png"
            )
            
            let aiResponse1 = response1.candidates.first?.content.parts.first?.text ?? ""
            print("🤖 AI: \(aiResponse1)")
            
            // 更新对话历史
            conversationHistory.append(Content.multimodalMessage(text: "这张图片显示了什么？请详细描述。", imageData: imageData))
            conversationHistory.append(Content.modelMessage(aiResponse1))
            
            // 第二轮：追问
            print("\n👤 用户: 这种图案通常用在什么地方？")
            
            let response2 = try await client.sendMessage(
                model: .gemini25Flash,
                message: "这种图案通常用在什么地方？",
                history: conversationHistory
            )
            
            let aiResponse2 = response2.candidates.first?.content.parts.first?.text ?? ""
            print("🤖 AI: \(aiResponse2)")
            
            // 第三轮：设计建议
            conversationHistory.append(Content.userMessage("这种图案通常用在什么地方？"))
            conversationHistory.append(Content.modelMessage(aiResponse2))
            
            print("\n👤 用户: 如果我要设计类似的图案，有什么建议？")
            
            let response3 = try await client.sendMessage(
                model: .gemini25Flash,
                message: "如果我要设计类似的图案，有什么建议？",
                history: conversationHistory
            )
            
            let aiResponse3 = response3.candidates.first?.content.parts.first?.text ?? ""
            print("🤖 AI: \(aiResponse3)")
            
            print("\n📊 对话统计:")
            print("   总消息数: \(conversationHistory.count + 4)")
            print("   包含图片的消息: 1")
            
        } catch {
            print("❌ 错误: \(error)")
        }
        
        print("\n")
    }
    
    // MARK: - 示例 4: 批量图片分析
    static func batchImageAnalysis(apiKey: String) async {
        print("📦 示例 4: 批量图片分析")
        print("-" * 30)
        
        let client = GeminiClient(apiKey: apiKey)
        
        // 加载现有测试图片
        let imageData: Data
        do {
            guard let imagePath = Bundle.main.path(forResource: "image", ofType: "png") else {
                print("❌ 错误: 找不到测试图片文件")
                return
            }
            imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        } catch {
            print("❌ 错误: 无法加载测试图片 - \(error)")
            return
        }
        
        // 创建测试图片数组（使用同一张图片的多个副本）
        let testImages: [(name: String, data: Data, description: String)] = [
            ("测试图片 1", imageData, "基本图像分析"),
            ("测试图片 2", imageData, "重复测试分析"),
            ("测试图片 3", imageData, "验证一致性"),
            ("测试图片 4", imageData, "性能测试")
        ]
        
        print("🔄 开始批量分析 \(testImages.count) 张图片...\n")
        
        for (index, image) in testImages.enumerated() {
            print("📷 图片 \(index + 1): \(image.name)")
            print("   任务: \(image.description)")
            
            do {
                let startTime = Date()
                let response = try await client.analyzeImage(
                    model: .gemini25Flash,
                    prompt: "Describe this image focusing on shapes, colors, and patterns. Be concise but specific.",
                    imageData: image.data,
                    mimeType: "image/png"
                )
                let duration = Date().timeIntervalSince(startTime)
                
                print("   ⏱️ 分析时间: \(String(format: "%.2f", duration * 1000)) 毫秒")
                print("   🤖 分析结果: \(response)")
                print("   ✅ 成功\n")
                
            } catch {
                print("   ❌ 失败: \(error)\n")
            }
        }
        
        print("🎉 批量分析完成！")
    }
    }