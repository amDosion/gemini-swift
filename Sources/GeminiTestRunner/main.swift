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
        print("11. 工作流系统测试 (新)")
        print("12. 运行所有测试")
        print("\n请输入选项 (1-12): ", terminator: "")
        
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
            await runWorkflowTests(apiKey: apiKey)
        case "12":
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
            print("\n" + "=" * 50)
            await runWorkflowTests(apiKey: apiKey)
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

    static func runWorkflowTests(apiKey: String) async {
        print("\n🔄 工作流系统测试")
        print("==================")

        // Initialize the library
        GeminiSwift.initialize()

        guard let client = GeminiClient(apiKeys: [apiKey]) else {
            print("❌ 错误: 无法初始化 GeminiClient")
            return
        }

        // Test data
        let salesData = """
        销售报告 - 2024年Q4

        产品销售:
        | 产品名称      | 销量   | 收入      | 增长率 |
        |--------------|--------|----------|--------|
        | iPhone 15    | 15,234 | ¥1523万  | +23%   |
        | MacBook Pro  | 8,456  | ¥1691万  | +15%   |
        | AirPods Pro  | 28,789 | ¥719万   | +45%   |

        区域表现:
        - 华东: ¥2850万 (+18%)
        - 华南: ¥1230万 (+22%)
        - 华北: ¥890万 (+35%)
        """

        let documentData = """
        发票编号: INV-2024-12345

        卖方: 科技有限公司
        地址: 北京市海淀区中关村大街1号
        电话: 010-12345678

        买方: 某某公司
        联系人: 张三
        电话: 138-0000-0000

        日期: 2024年12月15日

        项目:
        | 描述           | 数量 | 单价     | 金额      |
        |---------------|------|---------|----------|
        | 企业软件许可    | 1    | ¥50,000 | ¥50,000  |
        | 实施服务       | 40   | ¥250    | ¥10,000  |
        | 培训服务       | 25   | ¥500    | ¥12,500  |

        小计: ¥72,500
        税额: ¥6,162.50
        总计: ¥78,662.50
        """

        // Test 1: Boundary Agent
        print("\n1️⃣ 测试边界验证代理 (BoundaryAgent)")
        print("------------------------------------")
        do {
            let boundary = BoundaryAgent(client: client)
            let input = AgentInput(
                id: UUID().uuidString,
                content: "测试输入内容: 这是一段正常的文本，用于验证边界检查功能。"
            )
            let result = try await boundary.process(input: input)
            print("✅ 边界验证完成")
            print("   置信度: \(String(format: "%.2f", result.confidence))")
            print("   处理时间: \(String(format: "%.2f", result.processingTime))秒")
        } catch {
            print("❌ 边界验证失败: \(error)")
        }

        // Test 2: Context Agent
        print("\n2️⃣ 测试上下文管理代理 (ContextAgent)")
        print("--------------------------------------")
        do {
            let context = ContextAgent(client: client)
            let input = AgentInput(
                id: UUID().uuidString,
                content: "用户正在分析电商数据，需要了解销售趋势和客户行为。主要关注华东地区。"
            )
            let result = try await context.process(input: input)
            print("✅ 上下文处理完成")
            print("   置信度: \(String(format: "%.2f", result.confidence))")
            printOutputPreview(result.content)
        } catch {
            print("❌ 上下文处理失败: \(error)")
        }

        // Test 3: Sales Analyzer
        print("\n3️⃣ 测试销售分析代理 (SalesAnalyzerAgent)")
        print("-----------------------------------------")
        do {
            let salesAnalyzer = SalesAnalyzerAgent(client: client)
            let input = AgentInput(
                id: UUID().uuidString,
                content: salesData
            )
            let result = try await salesAnalyzer.process(input: input)
            print("✅ 销售分析完成")
            print("   置信度: \(String(format: "%.2f", result.confidence))")
            print("   处理时间: \(String(format: "%.2f", result.processingTime))秒")
            printOutputPreview(result.content, maxLines: 25)
        } catch {
            print("❌ 销售分析失败: \(error)")
        }

        // Test 4: Document Extractor
        print("\n4️⃣ 测试文档提取代理 (DocumentExtractorAgent)")
        print("---------------------------------------------")
        do {
            let extractor = DocumentExtractorAgent(client: client)
            let input = AgentInput(
                id: UUID().uuidString,
                content: documentData
            )
            let result = try await extractor.process(input: input)
            print("✅ 文档提取完成")
            print("   置信度: \(String(format: "%.2f", result.confidence))")
            print("   处理时间: \(String(format: "%.2f", result.processingTime))秒")
            printOutputPreview(result.content, maxLines: 30)
        } catch {
            print("❌ 文档提取失败: \(error)")
        }

        // Test 5: Trend Analyzer
        print("\n5️⃣ 测试趋势分析代理 (TrendAnalyzerAgent)")
        print("-----------------------------------------")
        do {
            let trendAnalyzer = TrendAnalyzerAgent(client: client)
            let input = AgentInput(
                id: UUID().uuidString,
                content: salesData
            )
            let result = try await trendAnalyzer.process(input: input)
            print("✅ 趋势分析完成")
            print("   置信度: \(String(format: "%.2f", result.confidence))")
            printOutputPreview(result.content, maxLines: 20)
        } catch {
            print("❌ 趋势分析失败: \(error)")
        }

        // Test 6: Data Analyzer
        print("\n6️⃣ 测试数据分析代理 (DataAnalyzerAgent)")
        print("-----------------------------------------")
        do {
            let dataAnalyzer = DataAnalyzerAgent(client: client)
            let input = AgentInput(
                id: UUID().uuidString,
                content: salesData
            )
            let result = try await dataAnalyzer.process(input: input)
            print("✅ 数据分析完成")
            print("   置信度: \(String(format: "%.2f", result.confidence))")
            printOutputPreview(result.content, maxLines: 20)
        } catch {
            print("❌ 数据分析失败: \(error)")
        }

        // Test 7: Review Agent
        print("\n7️⃣ 测试审查代理 (ReviewAgent)")
        print("-------------------------------")
        do {
            let reviewer = ReviewAgent(client: client)
            let contentToReview = """
            分析建议:
            1. 增加 AirPods Pro 营销预算 30%
            2. 针对 iPad Pro 推出促销活动
            3. 扩大华北地区市场份额
            4. 优化移动端用户体验

            预计这些措施将在 Q1 2025 带来 15-20% 的增长。
            """

            let input = AgentInput(
                id: UUID().uuidString,
                content: "请审查以下分析建议的准确性和完整性",
                previousOutputs: [
                    AgentOutput(
                        agentId: "previous_agent",
                        content: contentToReview,
                        confidence: 0.8,
                        processingTime: 1.0
                    )
                ]
            )
            let result = try await reviewer.process(input: input)
            print("✅ 审查完成")
            print("   置信度: \(String(format: "%.2f", result.confidence))")
            printOutputPreview(result.content, maxLines: 25)
        } catch {
            print("❌ 审查失败: \(error)")
        }

        // Test 8: Self-Argumentation Agent
        print("\n8️⃣ 测试自我论证代理 (SelfArgueAgent) - 5+轮循环")
        print("------------------------------------------------")
        do {
            let selfArgue = SelfArgueAgent(
                client: client,
                minCycles: 5,
                confidenceThreshold: 0.85
            )

            let topic = "电商企业应该优先发展移动App还是响应式网页？请考虑用户体验、开发成本、维护难度和市场覆盖等因素。"

            let input = AgentInput(
                id: UUID().uuidString,
                content: topic
            )

            print("   论题: \(topic)")
            print("   开始自我论证过程...\n")

            let result = try await selfArgue.process(input: input)
            print("✅ 自我论证完成")
            print("   最终置信度: \(String(format: "%.2f", result.confidence))")
            print("   处理时间: \(String(format: "%.2f", result.processingTime))秒")

            if let data = result.structuredData,
               let cycles = data["total_cycles"] {
                print("   论证轮数: \(cycles.value)")
            }

            printOutputPreview(result.content, maxLines: 40)
        } catch {
            print("❌ 自我论证失败: \(error)")
        }

        // Test 9: Complete Workflow Pipeline
        print("\n9️⃣ 测试完整工作流管道 (WorkflowCoordinator)")
        print("--------------------------------------------")
        do {
            let coordinator = WorkflowCoordinator(client: client)

            // Create workflow using factory
            let factory = WorkflowFactory(client: client)
            var workflow = factory.ecommerceInsights()

            // Set initial input
            workflow = Workflow(
                id: workflow.id,
                name: workflow.name,
                description: workflow.description,
                steps: workflow.steps,
                initialInput: AgentInput(
                    id: UUID().uuidString,
                    content: salesData
                )
            )

            print("   工作流: \(workflow.name)")
            print("   步骤数: \(workflow.steps.count)")

            // Subscribe to events
            coordinator.onEvent { event in
                switch event {
                case .stepStarted(_, let stepId):
                    print("   ▶️ 开始: \(stepId)")
                case .stepCompleted(_, let stepId, let output):
                    print("   ✅ 完成: \(stepId) (置信度: \(String(format: "%.2f", output.confidence)))")
                case .stepFailed(_, let stepId, let error):
                    print("   ❌ 失败: \(stepId) - \(error)")
                default:
                    break
                }
            }

            let result = try await coordinator.execute(workflow: workflow)

            print("\n✅ 工作流执行完成!")
            print("   状态: \(result.status)")
            print("   总处理时间: \(String(format: "%.2f", result.totalProcessingTime))秒")
            print("   整体置信度: \(String(format: "%.2f", result.confidence))")
            print("   输出数量: \(result.outputs.count)")

            printOutputPreview(result.finalOutput, maxLines: 30)

        } catch {
            print("❌ 工作流执行失败: \(error)")
        }

        print("\n🎉 工作流系统测试完成!")
    }

    // Helper function for output preview
    static func printOutputPreview(_ content: String, maxLines: Int = 15) {
        let lines = content.components(separatedBy: "\n")
        let preview = lines.prefix(maxLines)
        print("\n   输出预览:")
        print("   " + String(repeating: "-", count: 50))
        for line in preview {
            print("   \(line)")
        }
        if lines.count > maxLines {
            print("   ... (还有 \(lines.count - maxLines) 行)")
        }
        print("   " + String(repeating: "-", count: 50))
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