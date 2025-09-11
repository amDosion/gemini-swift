import Foundation
import gemini_swfit

class GeminiTestRunner {
    static func main() async {
        // 检查环境变量
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            print("❌ 错误: 请设置 GEMINI_API_KEY 环境变量")
            print("   例如: export GEMINI_API_KEY=your_api_key_here")
            return
        }
        
        print("🚀 Gemini Swift Test Runner")
        print("==========================")
        print("\n请选择要运行的测试:")
        print("1. 基础文本生成测试")
        print("2. 图片理解测试")
        print("3. 图片分析完整示例")
        print("4. 对话管理器示例")
        print("5. 搜索功能测试")
        print("6. 文档上传示例")
        print("7. 音频识别测试")
        print("8. 增强音频管理测试")
        print("9. 测试指定音频文件")
        print("10. 视频理解测试")
        print("11. 运行所有测试")
        print("\n请输入选项 (1-11): ", terminator: "")
        
        // 读取用户输入
        let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch input {
        case "1":
            await runBasicTests(apiKey: apiKey)
        case "2":
            await runImageTests(apiKey: apiKey)
        case "3":
            await ImageAnalysisExample.main()
        case "4":
            await ConversationExample.main()
        case "5":
            await SearchExample.runAllExamples()
        case "6":
            await DocumentUploadExample.main()
        case "7":
            await runAudioTests(apiKey: apiKey)
        case "8":
            await runEnhancedAudioTests(apiKey: apiKey)
        case "9":
            await runSpecificAudioTest(apiKey: apiKey)
        case "10":
            await runVideoTests(apiKey: apiKey)
        case "11":
            await runBasicTests(apiKey: apiKey)
            print("\n" + "=" * 50)
            await runImageTests(apiKey: apiKey)
            print("\n" + "=" * 50)
            await ImageAnalysisExample.main()
            print("\n" + "=" * 50)
            await ConversationExample.main()
            print("\n" + "=" * 50)
            await SearchExample.runAllExamples()
            print("\n" + "=" * 50)
            await DocumentUploadExample.main()
            print("\n" + "=" * 50)
            await runAudioTests(apiKey: apiKey)
            print("\n" + "=" * 50)
            await runEnhancedAudioTests(apiKey: apiKey)
            print("\n" + "=" * 50)
            await runSpecificAudioTest(apiKey: apiKey)
            print("\n" + "=" * 50)
            await runVideoTests(apiKey: apiKey)
        default:
            print("无效选项，运行基础测试...")
            await runBasicTests(apiKey: apiKey)
        }
    }
    
    static func runBasicTests(apiKey: String) async {
        print("\n🔤 基础文本生成测试")
        print("====================")
        
        // Initialize the library
        GeminiSwift.initialize()
        
        // Create client with provided API key
        let client = GeminiClient(apiKey: apiKey)
        
        // Test 1: System Instruction (Cat example from curl)
        print("\n1. 测试系统指令 - 猫咪角色")
        print("-------------------------------")
        do {
            let response = try await client.generateText(
                model: .gemini25Flash,
                prompt: "Hello there",
                systemInstruction: "You are a cat. Your name is Neko."
            )
            print("✅ 回复: \(response)")
        } catch {
            print("❌ 错误: \(error)")
        }  
        
        // Test 2: Simple question without system instruction
        print("\n2. 测试简单问题")
        print("----------------")
        do {
            let response = try await client.generateText(
                model: .gemini25Flash,
                prompt: "What is 2+2?"
            )
            print("✅ 回复: \(response)")
        } catch {
            print("❌ 错误: \(error)")
        }
        
        // Test 3: With custom temperature
        print("\n3. 测试自定义温度")
        print("------------------")
        do {
            let response = try await client.generateText(
                model: .gemini25Flash,
                prompt: "Tell me a joke",
                temperature: 0.9
            )
            print("✅ 回复: \(response)")
        } catch {
            print("❌ 错误: \(error)")
        }
        
        // Test 4: Different model
        print("\n4. 测试 Gemini Pro")
        print("----------------")
        do {
            let response = try await client.generateText(
                model: .gemini25Pro,
                prompt: "Explain quantum computing in one sentence"
            )
            print("✅ 回复: \(response)")
        } catch {
            print("❌ 错误: \(error)")
        }
        
        print("\n🎉 基础文本生成测试完成！")
    }
    
    static func runAudioTests(apiKey: String) async {
        print("\n🎵 音频识别测试")
        print("================")
        
        // Initialize the library
        GeminiSwift.initialize()
        
        // Create client with provided API key
        let client = GeminiClient(apiKey: apiKey)
        let audioExample = AudioExample(client: client, apiKey: apiKey)
        
        print("\n注意: 此测试需要音频文件。请确保有以下文件之一:")
        print("- sample.mp3, sample.wav, audio.m4a (在 Resources 目录)")
        print("- /tmp/sample.mp3")
        print("- /Users/Shared/sample.mp3")
        
        await audioExample.runAudioTranscriptionExample()
        await audioExample.runAudioAnalysisExample()
        await audioExample.runBatchAudioUploadExample()
        
        print("\n🎉 音频识别测试完成！")
    }
    
    static func runEnhancedAudioTests(apiKey: String) async {
        print("\n🚀 增强音频管理测试")
        print("==================")
        
        // Initialize the library
        GeminiSwift.initialize()
        
        // Create client with provided API key
        let client = GeminiClient(apiKey: apiKey)
        
        print("\n注意: 此测试需要多个音频文件。请确保有以下文件:")
        print("- /tmp/sample1.mp3, /tmp/sample2.mp3, /tmp/sample3.mp3")
        print("- /Users/Shared/audio1.mp3, /Users/Shared/audio2.mp3")
        
        let example = EnhancedAudioExample(client: client, apiKey: apiKey)
        
        await example.runEnhancedBatchExample()
        await example.runSmartSchedulingExample()
        await example.runKeyOptimizationExample()
        await example.runRetryMechanismExample()
        
        print("\n🎉 增强音频管理测试完成！")
    }
    
    static func runSpecificAudioTest(apiKey: String) async {
        print("\n🎵 测试指定音频文件")
        print("===================")
        
        // Initialize the library
        GeminiSwift.initialize()
        
        // Create client with provided API key
        let client = GeminiClient(apiKey: apiKey)
        
        // Test with specific audio file
        let test = AudioTest(client: client, apiKey: apiKey)
        await test.runAudioTests()
    }
    
    static func runImageTests(apiKey: String) async {
        print("\n🖼️ 图片理解测试")
        print("==================")
        
        // Initialize the library
        GeminiSwift.initialize()
        
        // Create client with provided API key
        let client = GeminiClient(apiKey: apiKey)
        
        // Test 1: Use existing test image
        print("\n1. 测试简单图片分析 - 使用现有图片")
        print("------------------------------------")
        
        do {
            // Load the existing test image
            guard let imagePath = Bundle.main.path(forResource: "image", ofType: "png") else {
                print("❌ 错误: 找不到测试图片文件")
                return
            }
            let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            
            let response = try await client.analyzeImage(
                model: .gemini25Flash,
                prompt: "What do you see in this image? Describe the colors and shape.",
                imageData: imageData,
                mimeType: "image/png"
            )
            print("✅ 图片分析结果: \(response)")
        } catch {
            print("❌ 错误: \(error)")
        }
        
        // Test 2: Test with different models
        print("\n2. 测试不同模型的图片理解能力")
        print("--------------------------------")
        
        do {
            // Load the existing test image
            guard let imagePath = Bundle.main.path(forResource: "image", ofType: "png") else {
                print("❌ 错误: 找不到测试图片文件")
                return
            }
            let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            
            // Test with Flash Image Preview model
            let response = try await client.analyzeImage(
                model: .gemini25FlashImagePreview,
                prompt: "Analyze this image in detail. What patterns, colors, and shapes do you see?",
                imageData: imageData,
                mimeType: "image/png"
            )
            print("✅ Flash Image Preview 分析: \(response)")
        } catch {
            print("❌ 错误: \(error)")
        }
        
        // Test 3: Multi-turn conversation with image
        print("\n3. 测试图片+对话组合")
        print("--------------------")
        
        do {
            // Load the existing test image
            guard let imagePath = Bundle.main.path(forResource: "image", ofType: "png") else {
                print("❌ 错误: 找不到测试图片文件")
                return
            }
            let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            var history: [Content] = []
            
            // First message with image
            let response1 = try await client.sendMessage(
                model: .gemini25Flash,
                message: "Please describe this image",
                history: history
            )
            
            // Add the multimodal message to history manually
            history.append(Content.multimodalMessage(text: "Please describe this image", imageData: imageData))
            history.append(Content.modelMessage(response1.candidates.first?.content.parts.first?.text ?? ""))
            
            print("✅ 第一轮对话: \(response1.candidates.first?.content.parts.first?.text ?? "")")
            
            // Follow-up question without image
            let response2 = try await client.sendMessage(
                model: .gemini25Flash,
                message: "What would be a good use case for this type of image?",
                history: history
            )
            
            print("✅ 第二轮对话: \(response2.candidates.first?.content.parts.first?.text ?? "")")
            
        } catch {
            print("❌ 错误: \(error)")
        }
        
        print("\n🎉 图片理解测试完成！")
    }
    
    static func runVideoTests(apiKey: String) async {
        print("\n🎥 视频理解测试")
        print("==================")
        
        // Initialize the library
        GeminiSwift.initialize()
        
        // Create video example instance
        let videoExample = VideoExample(apiKey: apiKey)
        
        // Run examples
        await videoExample.runExamples()
    }
    
}

// MARK: - 辅助扩展

extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

Task {
    await GeminiTestRunner.main()
}

// Keep the program running
RunLoop.main.run(until: Date(timeIntervalSinceNow: 60))