import Foundation
import SwiftyBeaver

public class GeminiLogger: @unchecked Sendable {
    public static let shared = GeminiLogger()
    
    private var isInitialized = false
    private let lock = NSLock()
    
    private init() {}
    
    public func setup(logLevel: SwiftyBeaver.Level = .debug) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isInitialized else { return }
        
        // Remove any existing destinations
        SwiftyBeaver.removeAllDestinations()
        
        // Add console destination with clean format
        let console = ConsoleDestination()
        console.format = "$DHH:mm:ss.SSS$d $C[L$c] $M"
        console.minLevel = logLevel
        SwiftyBeaver.addDestination(console)
        
        // Add file destination for debugging
        let file = FileDestination()
        file.logFileURL = URL(fileURLWithPath: "/tmp/gemini-swift.log")
        file.minLevel = .debug
        SwiftyBeaver.addDestination(file)
        
        isInitialized = true
        
        // Log initialization
        SwiftyBeaver.info("✅ GeminiLogger initialized with console output")
    }
    
    public func setupCustomConsole(
        format: String = "$DHH:mm:ss.SSS$d $C[L$c] $N.$F:$l - $M",
        logLevel: SwiftyBeaver.Level = .debug
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        // Remove any existing destinations
        SwiftyBeaver.removeAllDestinations()
        
        let console = ConsoleDestination()
        console.format = format
        console.minLevel = logLevel
        SwiftyBeaver.addDestination(console)
        
        isInitialized = true
        
        // Log initialization
        SwiftyBeaver.info("✅ GeminiLogger initialized with custom console format")
    }
    
    public func ensureInitialized() {
        if !isInitialized {
            setup()
        }
    }
}