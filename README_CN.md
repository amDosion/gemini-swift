# Gemini Swift 库

[![Swift](https://img.shields.io/badge/Swift-6.1+-FA7343.svg?style=flat-square)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue.svg?style=flat-square)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

一个生产就绪的 Swift Package Manager 库，提供与 Google Gemini AI API 的全面集成。使用 Swift 6.1+ 构建，支持所有 Apple 平台。

## 功能特性

### 🤖 **AI 能力**
- **文本生成**: 支持可配置参数的高级文本生成
- **多模态处理**: 同时分析文本、图像、音频、视频和文档
- **对话管理**: 内置历史记录跟踪和会话管理
- **搜索集成**: 带有基础元数据的实时 Google 搜索

### 🎵 **媒体处理**
- **音频转录**: 支持多语言的语音转文本
- **图像分析**: 理解和描述图像内容
- **视频理解**: 分析视频内容和场景
- **文档对话**: 上传并与 PDF 和文本文件对话

### 🔧 **高级功能**
- **结构化输出**: 生成特定 JSON 格式的响应
- **JSON Schema 生成**: 从 Codable 类型自动生成模式
- **多密钥轮换**: 智能 API 密钥管理和配额处理
- **增强日志**: SwiftyBeaver 集成和可配置级别

## 系统要求

- **Swift**: 6.1+
- **平台**:
  - macOS 12.0+
  - iOS 15.0+
  - watchOS 8.0+
  - tvOS 15.0+
- **Xcode**: 14.0+ (用于 Xcode 项目)

## 安装

### Swift Package Manager

将包添加到您的 `Package.swift` 文件中：

```swift
dependencies: [
    .package(url: "https://github.com/huifer/gemini-swift.git", from: "1.0.0")
]
```

或在 Xcode 中直接添加：
1. 前往 **File > Add Packages...**
2. 输入包 URL：`https://github.com/huifer/gemini-swift.git`
3. 选择版本并添加到您的目标

## 快速开始

### 1. **API 密钥设置**

从 [Google AI Studio](https://aistudio.google.com/apikey) 获取您的 API 密钥：

```swift
import gemini_swfit

// 设置您的 API 密钥
let client = GeminiClient(apiKey: "your-api-key-here")

// 或使用多个密钥进行轮换
let client = GeminiClient(apiKeys: [
    "key1", "key2", "key3"
])
```

### 2. **基本文本生成**

```swift
do {
    let response = try await client.generateText(
        model: .gemini25Flash,
        prompt: "什么是人工智能？",
        systemInstruction: "你是一个有帮助的助手"
    )
    print(response.text)
} catch {
    print("错误：\(error)")
}
```

### 3. **图像分析**

```swift
// 加载图像
let imageURL = Bundle.main.url(forResource: "example", withExtension: "jpg")!
let imageData = try Data(contentsOf: imageURL)

do {
    let response = try await client.generateContent(
        model: .gemini25Pro,
        prompt: "详细描述这张图片",
        imageData: imageData,
        mimeType: "image/jpeg"
    )
    print(response.text)
} catch {
    print("错误：\(error)")
}
```

### 4. **音频转录**

```swift
let audioURL = Bundle.main.url(forResource: "recording", withExtension: "mp3")!

do {
    // 使用增强的音频管理器
    let audioManager = GeminiAudioManager(client: client)
    let result = try await audioManager.transcribe(audioFileURL: audioURL)
    print("转录内容：\(result.transcription)")
    
    // 获取音频分析
    let analysis = try await audioManager.analyze(
        audioFileURL: audioURL,
        prompt: "这段音频在讨论什么？"
    )
    print("分析：\(analysis.text)")
} catch {
    print("错误：\(error)")
}
```

### 5. **文档上传和对话**

```swift
let documentURL = Bundle.main.url(forResource: "report", withExtension: "pdf")!

do {
    // 上传文档
    let uploader = GeminiDocumentUploader(client: client)
    let file = try await uploader.upload(documentURL: documentURL)
    
    // 与文档对话
    let conversationManager = GeminiDocumentConversationManager(client: client)
    let response = try await conversationManager.sendMessage(
        "总结这个文档",
        toFile: file
    )
    print(response.text)
} catch {
    print("错误：\(error)")
}
```

### 6. **结构化输出**

```swift
// 定义您的 Codable 类型
struct 食谱: Codable {
    let 名称: String
    let 配料: [String]
    let 烹饪时间: Int
}

// 生成结构化输出
do {
    let 食谱列表: [食谱] = try await client.generateStructuredOutput(
        model: .gemini25Flash,
        prompt: "给我3个饼干食谱",
        schema: .from(type: 食谱.self)
    )
    
    for 食谱 in 食谱列表 {
        print("- \(食谱.名称) (\(食谱.烹饪时间) 分钟)")
    }
} catch {
    print("错误：\(error)")
}
```

### 7. **带基础的搜索**

```swift
do {
    let response = try await client.generateContentWithSearch(
        model: .gemini25Pro,
        prompt: "量子计算的最新发展是什么？"
    )
    
    print("答案：\(response.text)")
    
    // 检查基础元数据
    if let grounding = response.groundingMetadata {
        print("来源：")
        for chunk in grounding.groundingChunks {
            print("- \(chunk.web.title): \(chunk.web.uri)")
        }
    }
} catch {
    print("错误：\(error)")
}
```

## 支持的模型

- **Gemini 2.5 Pro** (`gemini-2.5-pro`) - 最强大的模型
- **Gemini 2.5 Flash** (`gemini-2.5-flash`) - 平衡性能
- **Gemini 2.5 Flash Lite** (`gemini-2.5-flash-lite`) - 轻量版本
- **Gemini Live** (`gemini-live-2.5-flash-preview`) - 实时对话预览
- **音频模型** - 原生音频对话和思考模型
- **图像预览** (`gemini-2.5-flash-image-preview`) - 图像优化
- **嵌入** (`gemini-embedding-001`) - 嵌入模型

## API 参考

### GeminiClient

所有 API 操作的主要客户端。

```swift
// 初始化
let client = GeminiClient(apiKey: "your-api-key")

// 生成文本
func generateText(
    model: Model,
    prompt: String,
    systemInstruction: String? = nil,
    temperature: Double? = nil,
    maxOutputTokens: Int? = nil,
    topP: Double? = nil,
    topK: Int? = nil
) async throws -> GenerateContentResponse

// 生成带图像的内容
func generateContent(
    model: Model,
    prompt: String,
    imageData: Data,
    mimeType: String
) async throws -> GenerateContentResponse

// 创建对话
func createConversation(
    model: Model,
    systemInstruction: String? = nil
) -> GeminiConversationManager

// 等等...
```

### 配置选项

```swift
// 配置客户端
client.logLevel = .debug
client.enableSearchTools = true
client.maxRetries = 3
client.timeout = 30.0

// 安全设置
client.safetySettings = [
    SafetySetting(category: .harassment, threshold: .blockNone),
    SafetySetting(category: .hateSpeech, threshold: .blockNone)
]
```

## 测试

该库包含全面的测试套件：

```bash
# 设置您的 API 密钥
export GEMINI_API_KEY=your_api_key_here

# 运行所有测试
swift test

# 运行交互式测试运行器
swift run GeminiTestRunner

# 运行特定测试
swift test --filter gemini_swfitTests.AudioTests
```

### 测试运行器

交互式测试运行器包括 11 个测试场景：
1. 基本文本生成
2. 图像理解
3. 对话管理
4. 搜索功能
5. 文档上传
6. 音频识别
7. 视频理解
8. 等等...

## 示例

查看 `Sources/GeminiTestRunner/` 目录以获取所有功能的综合示例。

## 项目结构

```
Sources/gemini-swfit/
├── GeminiClient.swift              # 主要客户端
├── Models/                         # API 模型
├── Audio/                          # 音频处理
├── Document/                       # 文档处理
├── Video/                          # 视频处理
├── Schema/                         # JSON Schema
├── API/                            # API 管理
├── Extensions/                     # 功能扩展
└── Utils/                          # 工具类
```

## 架构

- **Swift 6 并发**: 完整的 async/await 支持和严格的数据隔离
- **模块化设计**: 基于功能的组织和清晰的关注点分离
- **面向协议**: 可扩展的基于协议的接口设计
- **线程安全**: 所有操作都是线程安全的，具有适当的同步
- **资源管理**: 自动清理和高效的内存使用

## 贡献

欢迎贡献！请随时提交 Pull Request。

## 许可证

本项目采用 MIT 许可证 - 详情请查看 [LICENSE](LICENSE) 文件。

## 致谢

- Google Gemini AI API
- SwiftyBeaver 日志框架
- Swift 社区

## 支持

- [文档](docs/)
- [问题](https://github.com/huifer/gemini-swift/issues)
- [示例](Sources/GeminiTestRunner/)

---

**注意**: 本库未与 Google 官方关联。这是一个社区驱动的 Gemini API Swift 实现。