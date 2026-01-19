import XCTest
@testable import gemini_swfit

final class V2FeaturesTests: XCTestCase {

    // MARK: - Thinking Mode Tests

    func testThinkingConfigPresets() {
        XCTAssertEqual(ThinkingConfig.disabled.thinkingBudget, 0)
        XCTAssertFalse(ThinkingConfig.disabled.includeThoughts)

        XCTAssertEqual(ThinkingConfig.dynamic.thinkingBudget, -1)
        XCTAssertTrue(ThinkingConfig.dynamic.includeThoughts)

        XCTAssertEqual(ThinkingConfig.light.thinkingBudget, 1024)
        XCTAssertEqual(ThinkingConfig.standard.thinkingBudget, 4096)
        XCTAssertEqual(ThinkingConfig.deep.thinkingBudget, 16384)
        XCTAssertEqual(ThinkingConfig.maximum.thinkingBudget, 32768)
    }

    func testThinkingLevel() {
        XCTAssertEqual(ThinkingLevel.low.rawValue, "LOW")
        XCTAssertEqual(ThinkingLevel.medium.rawValue, "MEDIUM")
        XCTAssertEqual(ThinkingLevel.high.rawValue, "HIGH")
    }

    func testThinkingGenerationConfig() {
        let config = ThinkingGenerationConfig(
            maxOutputTokens: 8192,
            temperature: 0.7,
            thinkingBudget: 4096,
            thinkingLevel: .medium
        )

        XCTAssertEqual(config.maxOutputTokens, 8192)
        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertNotNil(config.thinkingConfig)
        XCTAssertEqual(config.thinkingConfig?.thinkingBudget, 4096)
        XCTAssertEqual(config.thinkingConfig?.thinkingLevel, "MEDIUM")
    }

    func testReasoningStep() {
        let step = ReasoningStep(
            index: 1,
            description: "Analyze the problem",
            conclusion: "Found solution"
        )

        XCTAssertEqual(step.index, 1)
        XCTAssertEqual(step.description, "Analyze the problem")
        XCTAssertEqual(step.conclusion, "Found solution")
    }

    // MARK: - Live API Tests

    func testLiveAPIConfig() {
        let config = LiveAPIConfig(
            voiceConfig: .default,
            proactiveAudio: true,
            affectiveDialog: true,
            enableThinking: true
        )

        XCTAssertNotNil(config.voiceConfig)
        XCTAssertTrue(config.proactiveAudio)
        XCTAssertTrue(config.affectiveDialog)
        XCTAssertTrue(config.enableThinking)
    }

    func testVoiceConfig() {
        let voiceConfig = VoiceConfig(
            voiceName: "Puck",
            languageCode: "en-US",
            speakingRate: 1.2,
            pitch: 0.5
        )

        XCTAssertEqual(voiceConfig.voiceName, "Puck")
        XCTAssertEqual(voiceConfig.languageCode, "en-US")
        XCTAssertEqual(voiceConfig.speakingRate, 1.2)
        XCTAssertEqual(voiceConfig.pitch, 0.5)
    }

    func testVoiceConfigBounds() {
        let extremeConfig = VoiceConfig(
            speakingRate: 10.0,  // Should be capped at 4.0
            pitch: 50.0         // Should be capped at 20.0
        )

        XCTAssertEqual(extremeConfig.speakingRate, 4.0)
        XCTAssertEqual(extremeConfig.pitch, 20.0)
    }

    func testAvailableVoices() {
        XCTAssertTrue(VoiceConfig.availableVoices.contains("Puck"))
        XCTAssertTrue(VoiceConfig.availableVoices.contains("Charon"))
        XCTAssertEqual(VoiceConfig.availableVoices.count, 10)
    }

    func testAudioEncoding() {
        XCTAssertEqual(AudioEncoding.linear16.rawValue, "LINEAR16")
        XCTAssertEqual(AudioEncoding.mp3.rawValue, "MP3")
        XCTAssertEqual(AudioEncoding.oggOpus.rawValue, "OGG_OPUS")
    }

    // MARK: - Code Execution Tests

    func testExtendedTool() {
        let codeExecTool = ExtendedTool.codeExecution()
        XCTAssertNotNil(codeExecTool.codeExecution)
        XCTAssertNil(codeExecTool.googleSearch)

        let mapsTool = ExtendedTool.googleMaps()
        XCTAssertNotNil(mapsTool.googleMaps)
        XCTAssertNil(mapsTool.codeExecution)
    }

    func testMultiTool() {
        let multiTool = ExtendedTool.multiTool(
            googleSearch: true,
            urlContext: true,
            codeExecution: true,
            googleMaps: false
        )

        XCTAssertNotNil(multiTool.googleSearch)
        XCTAssertNotNil(multiTool.urlContext)
        XCTAssertNotNil(multiTool.codeExecution)
        XCTAssertNil(multiTool.googleMaps)
    }

    func testCodeExecutionResult() {
        XCTAssertEqual(CodeExecutionResult.ExecutionOutcome.outcomeOk.rawValue, "OUTCOME_OK")
        XCTAssertEqual(CodeExecutionResult.ExecutionOutcome.outcomeFailed.rawValue, "OUTCOME_FAILED")
    }

    func testExecutedCodeBlock() {
        let block = ExecutedCodeBlock(
            language: "python",
            code: "print('hello')",
            output: "hello",
            error: nil
        )

        XCTAssertEqual(block.language, "python")
        XCTAssertEqual(block.code, "print('hello')")
        XCTAssertTrue(block.isSuccess)
    }

    func testFunctionDeclarationPayload() {
        let simple = FunctionDeclarationPayload.simple(
            name: "getWeather",
            description: "Get weather info"
        )

        XCTAssertEqual(simple.name, "getWeather")
        XCTAssertNil(simple.parameters)

        let withParams = FunctionDeclarationPayload.withStringParams(
            name: "search",
            description: "Search",
            params: [
                (name: "query", description: "Query", required: true),
                (name: "limit", description: "Limit", required: false)
            ]
        )

        XCTAssertNotNil(withParams.parameters)
        XCTAssertEqual(withParams.parameters?.required, ["query"])
    }

    func testNonBlockingFunction() {
        let func1 = FunctionDeclarationPayload.nonBlocking(
            name: "asyncOp",
            description: "Async operation"
        )

        XCTAssertEqual(func1.behavior, .nonBlocking)
    }

    // MARK: - Batch Processing Tests

    func testBatchConfig() {
        let defaultConfig = BatchConfig.default
        XCTAssertEqual(defaultConfig.maxBatchSize, 100)
        XCTAssertEqual(defaultConfig.batchTimeout, 3600)

        let largeConfig = BatchConfig.large
        XCTAssertEqual(largeConfig.maxBatchSize, 500)
    }

    func testBatchRequest() {
        let request = BatchRequest.text(
            "Hello, world!",
            model: "gemini-2.5-flash",
            id: "test-1"
        )

        XCTAssertEqual(request.id, "test-1")
        XCTAssertEqual(request.model, "gemini-2.5-flash")
        XCTAssertEqual(request.contents.count, 1)
    }

    func testBatchJobStatus() {
        XCTAssertEqual(BatchJob.BatchJobStatus.pending.rawValue, "JOB_STATE_PENDING")
        XCTAssertEqual(BatchJob.BatchJobStatus.succeeded.rawValue, "JOB_STATE_SUCCEEDED")
    }

    func testBatchError() {
        let errors: [BatchError] = [
            .emptyBatch,
            .batchTooLarge(max: 100),
            .timeout
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }

    // MARK: - Model Tests

    func testGeminiModel() {
        XCTAssertEqual(GeminiModel.gemini25Flash.rawValue, "gemini-2.5-flash")
        XCTAssertEqual(GeminiModel.gemini25Pro.rawValue, "gemini-2.5-pro")
        XCTAssertEqual(GeminiModel.gemini3FlashPreview.rawValue, "gemini-3-flash-preview")
    }

    func testModelCapabilities() {
        XCTAssertTrue(GeminiModel.gemini25Pro.supportsThinking)
        XCTAssertTrue(GeminiModel.gemini25Flash.supportsCodeExecution)
        XCTAssertTrue(GeminiModel.geminiLive25FlashPreview.supportsLiveAPI)
        XCTAssertTrue(GeminiModel.imagen4Ultra.supportsImageGeneration)
        XCTAssertTrue(GeminiModel.veo31.supportsVideoGeneration)
    }

    func testModelCategory() {
        XCTAssertEqual(GeminiModel.gemini3FlashPreview.category, .gemini3)
        XCTAssertEqual(GeminiModel.gemini25Pro.category, .gemini25)
        XCTAssertEqual(GeminiModel.geminiLive25FlashPreview.category, .liveAudio)
        XCTAssertEqual(GeminiModel.imagen4Ultra.category, .imagen)
        XCTAssertEqual(GeminiModel.veo31.category, .veo)
    }

    func testModelTokenLimits() {
        let proLimits = GeminiModel.gemini25Pro.tokenLimits
        XCTAssertEqual(proLimits.input, 2_097_152)
        XCTAssertEqual(proLimits.output, 65_536)

        let embeddingLimits = GeminiModel.geminiEmbedding001.tokenLimits
        XCTAssertEqual(embeddingLimits.output, 0)
    }

    func testModelSelector() {
        let fastModel = ModelSelector.forTextGeneration(fast: true)
        XCTAssertEqual(fastModel, .gemini25FlashLite)

        let thinkingModel = ModelSelector.forTextGeneration(thinking: true)
        XCTAssertEqual(thinkingModel, .gemini25Flash)

        let codingModel = ModelSelector.forCoding(complex: true)
        XCTAssertEqual(codingModel, .gemini25Pro)
    }

    func testModelInfo() {
        let allModels = ModelInfo.allModels
        XCTAssertFalse(allModels.isEmpty)

        let thinkingModels = ModelInfo.models(supporting: .thinking)
        XCTAssertTrue(thinkingModels.contains(.gemini25Pro))

        let liveModels = ModelInfo.models(supporting: .liveAPI)
        XCTAssertTrue(liveModels.contains(.geminiLive25FlashPreview))
    }

    // MARK: - Multi-Tool Builder Tests

    func testMultiToolRequestBuilder() {
        let request = MultiToolRequestBuilder()
            .addGoogleSearch()
            .addCodeExecution()
            .prompt("Test prompt")
            .systemInstruction("Be helpful")
            .build()

        XCTAssertEqual(request.tools.count, 2)
        XCTAssertEqual(request.contents.count, 1)
        XCTAssertNotNil(request.systemInstruction)
    }

    // MARK: - AnyCodable Tests

    func testAnyCodable() throws {
        let intValue = AnyCodable(42)
        let stringValue = AnyCodable("hello")
        let boolValue = AnyCodable(true)
        let arrayValue = AnyCodable([1, 2, 3])
        let dictValue = AnyCodable(["key": "value"])

        // Test encoding
        let encoder = JSONEncoder()
        XCTAssertNoThrow(try encoder.encode(intValue))
        XCTAssertNoThrow(try encoder.encode(stringValue))
        XCTAssertNoThrow(try encoder.encode(boolValue))
        XCTAssertNoThrow(try encoder.encode(arrayValue))
        XCTAssertNoThrow(try encoder.encode(dictValue))
    }

    // MARK: - MediaChunk Tests

    func testMediaChunk() {
        let chunk = MediaChunk(
            mimeType: "audio/pcm",
            data: "base64encodeddata"
        )

        XCTAssertEqual(chunk.mimeType, "audio/pcm")
        XCTAssertEqual(chunk.data, "base64encodeddata")
    }

    // MARK: - Turn Tests

    func testTurn() {
        let turn = Turn(
            role: "user",
            parts: [TurnPart(text: "Hello")]
        )

        XCTAssertEqual(turn.role, "user")
        XCTAssertEqual(turn.parts.count, 1)
        XCTAssertEqual(turn.parts.first?.text, "Hello")
    }
}
