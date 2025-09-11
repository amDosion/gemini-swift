@_exported import Foundation

// Re-export all public APIs
public struct GeminiSwift {
    public static let version = "1.0.0"
    
    public static func initialize() {
        GeminiLogger.shared.setup()
    }
}

