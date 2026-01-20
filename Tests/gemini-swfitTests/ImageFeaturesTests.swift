import XCTest
@testable import gemini_swfit

final class ImageFeaturesTests: XCTestCase {

    // MARK: - Image Generation Config Tests

    func testImageGenerationConfigDefault() {
        let config = ImageGenerationConfig.default
        XCTAssertEqual(config.numberOfImages, 1)
        XCTAssertEqual(config.outputFormat, .png)
        XCTAssertEqual(config.aspectRatio, .square)
        XCTAssertTrue(config.addWatermark)
    }

    func testImageGenerationConfigHighQuality() {
        let config = ImageGenerationConfig.highQuality
        XCTAssertEqual(config.outputResolution, .resolution2K)
    }

    func testImageGenerationConfigUltraQuality() {
        let config = ImageGenerationConfig.ultraQuality
        XCTAssertEqual(config.outputResolution, .resolution4K)
        XCTAssertEqual(config.aspectRatio, .landscape16x9)
    }

    func testImageGenerationConfigBounds() {
        let config = ImageGenerationConfig(numberOfImages: 10)
        XCTAssertEqual(config.numberOfImages, 4)  // Capped at 4

        let config2 = ImageGenerationConfig(numberOfImages: 0)
        XCTAssertEqual(config2.numberOfImages, 1)  // Minimum 1
    }

    // MARK: - Aspect Ratio Tests

    func testAspectRatios() {
        XCTAssertEqual(AspectRatio.square.rawValue, "1:1")
        XCTAssertEqual(AspectRatio.portrait3x4.rawValue, "3:4")
        XCTAssertEqual(AspectRatio.portrait9x16.rawValue, "9:16")
        XCTAssertEqual(AspectRatio.landscape4x3.rawValue, "4:3")
        XCTAssertEqual(AspectRatio.landscape16x9.rawValue, "16:9")
    }

    func testAspectRatioDescription() {
        XCTAssertEqual(AspectRatio.square.description, "Square (1:1)")
        XCTAssertTrue(AspectRatio.portrait3x4.description.contains("Portrait"))
        XCTAssertTrue(AspectRatio.landscape16x9.description.contains("Landscape"))
    }

    // MARK: - Image Format Tests

    func testImageFormats() {
        XCTAssertEqual(ImageFormat.png.rawValue, "png")
        XCTAssertEqual(ImageFormat.jpeg.rawValue, "jpeg")
        XCTAssertEqual(ImageFormat.webp.rawValue, "webp")
    }

    // MARK: - Safety Settings Tests

    func testSafetyFilterLevels() {
        XCTAssertEqual(SafetyFilterLevel.blockNone.rawValue, "block_none")
        XCTAssertEqual(SafetyFilterLevel.blockMediumAndAbove.rawValue, "block_medium_and_above")
    }

    func testPersonGeneration() {
        XCTAssertEqual(PersonGeneration.dontAllow.rawValue, "dont_allow")
        XCTAssertEqual(PersonGeneration.allowAdult.rawValue, "allow_adult")
        XCTAssertEqual(PersonGeneration.allowAll.rawValue, "allow_all")
    }

    // MARK: - Output Resolution Tests

    func testOutputResolutions() {
        XCTAssertEqual(OutputResolution.resolution1K.rawValue, "1024")
        XCTAssertEqual(OutputResolution.resolution2K.rawValue, "2048")
        XCTAssertEqual(OutputResolution.resolution4K.rawValue, "4096")
    }

    // MARK: - Image Generation Model Tests

    func testImageGenerationModels() {
        XCTAssertEqual(ImageGenerationModel.gemini25FlashImage.rawValue, "gemini-2.5-flash-image")
        XCTAssertEqual(ImageGenerationModel.gemini3ProImage.rawValue, "gemini-3-pro-image-preview")
        XCTAssertEqual(ImageGenerationModel.imagen4Ultra.rawValue, "imagen-4-ultra")
        XCTAssertEqual(ImageGenerationModel.imagen4Standard.rawValue, "imagen-4-standard")
    }

    func testModelCapabilities() {
        XCTAssertTrue(ImageGenerationModel.gemini25FlashImage.supportsMultiTurnEditing)
        XCTAssertTrue(ImageGenerationModel.gemini3ProImage.supportsMultiTurnEditing)
        XCTAssertFalse(ImageGenerationModel.imagen4Ultra.supportsMultiTurnEditing)

        XCTAssertTrue(ImageGenerationModel.gemini3ProImage.supports4K)
        XCTAssertTrue(ImageGenerationModel.imagen4Ultra.supports4K)
        XCTAssertFalse(ImageGenerationModel.gemini25FlashImage.supports4K)

        XCTAssertTrue(ImageGenerationModel.gemini3ProImage.supportsThinking)
        XCTAssertFalse(ImageGenerationModel.gemini25FlashImage.supportsThinking)
    }

    // MARK: - Image Input Tests

    func testImageInputFromData() {
        let testData = Data([0x89, 0x50, 0x4E, 0x47])  // PNG header
        let input = ImageInput(data: testData, mimeType: "image/png")

        XCTAssertNotNil(input.data)
        XCTAssertNil(input.url)
        XCTAssertEqual(input.mimeType, "image/png")
    }

    func testImageInputMimeType() {
        XCTAssertEqual(ImageInput.mimeType(for: "png"), "image/png")
        XCTAssertEqual(ImageInput.mimeType(for: "jpg"), "image/jpeg")
        XCTAssertEqual(ImageInput.mimeType(for: "jpeg"), "image/jpeg")
        XCTAssertEqual(ImageInput.mimeType(for: "webp"), "image/webp")
        XCTAssertEqual(ImageInput.mimeType(for: "gif"), "image/gif")
        XCTAssertEqual(ImageInput.mimeType(for: "heic"), "image/heic")
        XCTAssertEqual(ImageInput.mimeType(for: "unknown"), "image/png")  // Default
    }

    func testImageInputConvenience() {
        let pngData = Data([0x89, 0x50])
        let pngInput = ImageInput.fromPNG(pngData)
        XCTAssertEqual(pngInput.mimeType, "image/png")

        let jpegData = Data([0xFF, 0xD8])
        let jpegInput = ImageInput.fromJPEG(jpegData)
        XCTAssertEqual(jpegInput.mimeType, "image/jpeg")
    }

    // MARK: - Generated Image Tests

    func testGeneratedImage() {
        let testData = Data("test".utf8)
        let image = GeneratedImage(
            data: testData,
            mimeType: "image/png",
            index: 0
        )

        XCTAssertEqual(image.data, testData)
        XCTAssertEqual(image.mimeType, "image/png")
        XCTAssertEqual(image.index, 0)
        XCTAssertNotNil(image.base64String)
    }

    func testGeneratedImageFileExtension() {
        let pngImage = GeneratedImage(data: Data(), mimeType: "image/png", index: 0)
        XCTAssertEqual(pngImage.fileExtension, "png")

        let jpegImage = GeneratedImage(data: Data(), mimeType: "image/jpeg", index: 0)
        XCTAssertEqual(jpegImage.fileExtension, "jpg")

        let webpImage = GeneratedImage(data: Data(), mimeType: "image/webp", index: 0)
        XCTAssertEqual(webpImage.fileExtension, "webp")
    }

    func testGeneratedImageFilename() {
        let image = GeneratedImage(data: Data(), mimeType: "image/png", index: 2)
        let filename = image.suggestedFilename

        XCTAssertTrue(filename.hasPrefix("generated_"))
        XCTAssertTrue(filename.hasSuffix("_2.png"))
    }

    // MARK: - Image Generation Response Tests

    func testImageGenerationResponse() {
        let images = [
            GeneratedImage(data: Data("img1".utf8), mimeType: "image/png", index: 0),
            GeneratedImage(data: Data("img2".utf8), mimeType: "image/png", index: 1)
        ]

        let response = ImageGenerationResponse(
            images: images,
            thoughtSignature: "test-signature",
            textResponse: "Generated 2 images"
        )

        XCTAssertEqual(response.images.count, 2)
        XCTAssertNotNil(response.thoughtSignature)
        XCTAssertEqual(response.textResponse, "Generated 2 images")
        XCTAssertFalse(response.wasFiltered)
    }

    func testImageGenerationResponseFiltered() {
        let response = ImageGenerationResponse(
            images: [],
            wasFiltered: true,
            filterReason: "Content policy violation"
        )

        XCTAssertTrue(response.wasFiltered)
        XCTAssertEqual(response.filterReason, "Content policy violation")
    }

    func testImageGenerationResponseConvenience() {
        let image = GeneratedImage(data: Data("test".utf8), mimeType: "image/png", index: 0)
        let response = ImageGenerationResponse(images: [image])

        XCTAssertNotNil(response.firstImage)
        XCTAssertNotNil(response.firstImageData)
    }

    // MARK: - Thought Signature Tests

    func testThoughtSignature() {
        let signature = ThoughtSignature(
            signature: "encrypted-data",
            model: "gemini-2.5-flash-image"
        )

        XCTAssertEqual(signature.signature, "encrypted-data")
        XCTAssertEqual(signature.model, "gemini-2.5-flash-image")
        XCTAssertTrue(signature.isValid)  // Just created, should be valid
    }

    func testThoughtSignatureExpiry() {
        // Create a signature with an old timestamp
        let oldTimestamp = Date().addingTimeInterval(-25 * 60 * 60)  // 25 hours ago
        let signature = ThoughtSignature(
            signature: "old-data",
            timestamp: oldTimestamp
        )

        XCTAssertFalse(signature.isValid)  // Should be expired
    }

    // MARK: - Image Edit Mode Tests

    func testImageEditModes() {
        XCTAssertEqual(ImageEditMode.inpaint.rawValue, "INPAINT")
        XCTAssertEqual(ImageEditMode.outpaint.rawValue, "OUTPAINT")
        XCTAssertEqual(ImageEditMode.editImage.rawValue, "EDIT_IMAGE")
        XCTAssertEqual(ImageEditMode.controlledGeneration.rawValue, "CONTROLLED_GENERATION")
    }

    // MARK: - Conversation Turn Tests

    func testConversationTurn() {
        let turn = ImageConversationTurn(
            role: .user,
            content: .text("Generate a cat")
        )

        XCTAssertEqual(turn.role, .user)
        XCTAssertNotNil(turn.id)
        XCTAssertNotNil(turn.timestamp)
    }

    func testConversationRoles() {
        XCTAssertEqual(ConversationRole.user.rawValue, "user")
        XCTAssertEqual(ConversationRole.model.rawValue, "model")
    }

    // MARK: - Imagen Config Tests

    func testImagenConfigDefault() {
        let config = ImagenConfig.default
        XCTAssertEqual(config.sampleCount, 1)
        XCTAssertEqual(config.aspectRatio, .square1x1)
        XCTAssertEqual(config.safetyFilterLevel, .blockMediumAndAbove)
        XCTAssertEqual(config.personGeneration, .dontAllow)
    }

    func testImagenConfigBounds() {
        let config = ImagenConfig(sampleCount: 10)
        XCTAssertEqual(config.sampleCount, 4)  // Capped at 4
    }

    func testImagenAspectRatios() {
        XCTAssertEqual(ImagenAspectRatio.square1x1.rawValue, "1:1")
        XCTAssertEqual(ImagenAspectRatio.portrait3x4.rawValue, "3:4")
        XCTAssertEqual(ImagenAspectRatio.landscape16x9.rawValue, "16:9")
    }

    func testImagenOutputOptions() {
        let defaultOptions = ImagenOutputOptions.default
        XCTAssertEqual(defaultOptions.mimeType, "image/png")
        XCTAssertEqual(defaultOptions.compressionQuality, 80)

        let highQuality = ImagenOutputOptions.highQualityPNG
        XCTAssertEqual(highQuality.compressionQuality, 100)

        let compressed = ImagenOutputOptions.compressedJPEG
        XCTAssertEqual(compressed.mimeType, "image/jpeg")
    }

    func testImagenOutputOptionsBounds() {
        let options = ImagenOutputOptions(compressionQuality: 150)
        XCTAssertEqual(options.compressionQuality, 100)  // Capped

        let options2 = ImagenOutputOptions(compressionQuality: 0)
        XCTAssertEqual(options2.compressionQuality, 1)  // Minimum
    }

    // MARK: - Imagen Model Tests

    func testImagenModels() {
        XCTAssertEqual(ImagenClient.ImagenModel.imagen4Ultra.rawValue, "imagen-4-ultra")
        XCTAssertEqual(ImagenClient.ImagenModel.imagen4Standard.rawValue, "imagen-4-standard")
        XCTAssertEqual(ImagenClient.ImagenModel.imagen4Ultra.displayName, "Imagen 4 Ultra")
    }

    // MARK: - Upscale Factor Tests

    func testUpscaleFactors() {
        XCTAssertEqual(UpscaleFactor.x2.rawValue, "x2")
        XCTAssertEqual(UpscaleFactor.x4.rawValue, "x4")
    }

    // MARK: - Error Tests

    func testImageConversationErrors() {
        let errors: [ImageConversationError] = [
            .noImageToEdit,
            .invalidImage,
            .invalidResponse,
            .generationFailed("test"),
            .signatureExpired,
            .modelNotSupported
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testImagenErrors() {
        let errors: [ImagenError] = [
            .invalidResponse,
            .generationFailed("test"),
            .invalidImage,
            .quotaExceeded,
            .contentFiltered("reason")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }

    // MARK: - Detected Object Tests

    func testDetectedObject() {
        let object = DetectedObject(
            name: "cat",
            location: "center",
            confidence: "high"
        )

        XCTAssertEqual(object.name, "cat")
        XCTAssertEqual(object.location, "center")
        XCTAssertEqual(object.confidence, "high")
    }

    // MARK: - Expand Direction Tests

    func testExpandDirections() {
        XCTAssertEqual(ExpandDirection.left.rawValue, "left")
        XCTAssertEqual(ExpandDirection.right.rawValue, "right")
        XCTAssertEqual(ExpandDirection.top.rawValue, "top")
        XCTAssertEqual(ExpandDirection.bottom.rawValue, "bottom")
        XCTAssertEqual(ExpandDirection.all.rawValue, "all sides")
    }

    // MARK: - Image Conversation Builder Tests

    func testImageConversationBuilder() {
        let builder = ImageConversationBuilder()
            .model(.gemini25FlashImage)
            .numberOfImages(2)
            .aspectRatio(.landscape16x9)
            .resolution(.resolution2K)

        // Can't build without API key, but we can verify the builder pattern works
        XCTAssertNotNil(builder)
    }
}
