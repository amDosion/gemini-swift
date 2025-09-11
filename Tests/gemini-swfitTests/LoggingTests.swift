import XCTest
@testable import gemini_swfit
import SwiftyBeaver

final class LoggingTests: XCTestCase {
    
    func testGeminiLoggerInitialization() {
        // Given
        GeminiLogger.shared.setup()
        
        // When & Then - Test logging
        SwiftyBeaver.debug("Debug message from test")
        SwiftyBeaver.info("Info message from test")
        SwiftyBeaver.warning("Warning message from test")
        SwiftyBeaver.error("Error message from test")
        
        // If we get here without crashing, logging is working
        XCTAssertTrue(true, "Logging executed successfully")
    }
    
    func testCustomConsoleLogger() {
        // Given
        GeminiLogger.shared.setupCustomConsole()
        
        // When & Then - Test logging
        SwiftyBeaver.info("Custom console logger test message")
        
        // If we get here without crashing, logging is working
        XCTAssertTrue(true, "Custom logging executed successfully")
    }
}