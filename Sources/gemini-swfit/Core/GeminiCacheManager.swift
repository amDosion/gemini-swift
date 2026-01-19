import Foundation

// MARK: - Cache Configuration

/// Configuration for response caching
public struct GeminiCacheConfig: Sendable {
    /// Maximum number of cached entries
    public let maxEntries: Int

    /// Time-to-live for cached entries in seconds
    public let ttl: TimeInterval

    /// Whether to cache responses with errors
    public let cacheErrors: Bool

    /// Maximum size of a single cached response in bytes
    public let maxResponseSize: Int

    /// Default cache configuration
    public static let `default` = GeminiCacheConfig(
        maxEntries: 100,
        ttl: 300, // 5 minutes
        cacheErrors: false,
        maxResponseSize: 1024 * 1024 // 1 MB
    )

    /// Long-lived cache for stable requests
    public static let longLived = GeminiCacheConfig(
        maxEntries: 500,
        ttl: 3600, // 1 hour
        cacheErrors: false,
        maxResponseSize: 5 * 1024 * 1024 // 5 MB
    )

    /// Disabled cache
    public static let disabled = GeminiCacheConfig(
        maxEntries: 0,
        ttl: 0,
        cacheErrors: false,
        maxResponseSize: 0
    )

    public init(
        maxEntries: Int,
        ttl: TimeInterval,
        cacheErrors: Bool = false,
        maxResponseSize: Int = 1024 * 1024
    ) {
        self.maxEntries = max(0, maxEntries)
        self.ttl = max(0, ttl)
        self.cacheErrors = cacheErrors
        self.maxResponseSize = max(0, maxResponseSize)
    }

    public var isEnabled: Bool {
        return maxEntries > 0 && ttl > 0
    }
}

// MARK: - Cache Entry

/// A cached response entry
internal struct CacheEntry<T: Codable>: Codable {
    let value: T
    let timestamp: Date
    let expiresAt: Date
    let requestHash: String

    var isExpired: Bool {
        return Date() > expiresAt
    }
}

// MARK: - Cache Key Generator

/// Generates unique cache keys for requests
public struct CacheKeyGenerator {
    /// Generate a cache key from request parameters
    public static func generateKey(
        model: String,
        contents: [Content],
        systemInstruction: SystemInstruction?,
        generationConfig: GenerationConfig?,
        tools: [Tool]?
    ) -> String {
        var components: [String] = [model]

        // Hash contents
        for content in contents {
            if let role = content.role {
                components.append(role.rawValue)
            }
            for part in content.parts {
                if let text = part.text {
                    components.append(text)
                }
                if let inlineData = part.inlineData {
                    components.append(inlineData.mimeType)
                    // Use a short hash of the data to avoid huge keys
                    components.append(String(inlineData.data.hashValue))
                }
                if let fileData = part.fileData {
                    components.append(fileData.fileUri)
                }
            }
        }

        // Hash system instruction
        if let instruction = systemInstruction {
            for part in instruction.parts {
                if let text = part.text {
                    components.append("system:\(text)")
                }
            }
        }

        // Hash generation config
        if let config = generationConfig {
            if let temp = config.temperature {
                components.append("temp:\(temp)")
            }
            if let maxTokens = config.maxOutputTokens {
                components.append("maxTokens:\(maxTokens)")
            }
            if let topP = config.topP {
                components.append("topP:\(topP)")
            }
            if let topK = config.topK {
                components.append("topK:\(topK)")
            }
        }

        // Hash tools
        if let tools = tools {
            for tool in tools {
                if tool.googleSearch != nil {
                    components.append("tool:googleSearch")
                }
                if tool.urlContext != nil {
                    components.append("tool:urlContext")
                }
            }
        }

        // Generate SHA256 hash of combined components
        let combined = components.joined(separator: "|")
        return combined.sha256Hash
    }
}

// MARK: - String SHA256 Extension

extension String {
    var sha256Hash: String {
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: 32)

        data.withUnsafeBytes { buffer in
            var hasher = SHA256Hasher()
            hasher.update(data: buffer)
            hash = hasher.finalize()
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Simple SHA256 Implementation

private struct SHA256Hasher {
    private var h: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]

    private let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]

    private var buffer = Data()
    private var totalLength: UInt64 = 0

    mutating func update(data: UnsafeRawBufferPointer) {
        buffer.append(contentsOf: data)
        totalLength += UInt64(data.count)
    }

    mutating func finalize() -> [UInt8] {
        // Padding
        var paddedData = buffer
        paddedData.append(0x80)

        while (paddedData.count % 64) != 56 {
            paddedData.append(0x00)
        }

        // Append length in bits
        let bitLength = totalLength * 8
        for i in (0..<8).reversed() {
            paddedData.append(UInt8((bitLength >> (i * 8)) & 0xff))
        }

        // Process blocks
        for blockStart in stride(from: 0, to: paddedData.count, by: 64) {
            let block = paddedData.subdata(in: blockStart..<blockStart + 64)
            processBlock(block)
        }

        // Convert h to bytes
        var result = [UInt8]()
        for value in h {
            result.append(UInt8((value >> 24) & 0xff))
            result.append(UInt8((value >> 16) & 0xff))
            result.append(UInt8((value >> 8) & 0xff))
            result.append(UInt8(value & 0xff))
        }

        return result
    }

    private mutating func processBlock(_ block: Data) {
        var w = [UInt32](repeating: 0, count: 64)

        for i in 0..<16 {
            w[i] = UInt32(block[i * 4]) << 24 |
                   UInt32(block[i * 4 + 1]) << 16 |
                   UInt32(block[i * 4 + 2]) << 8 |
                   UInt32(block[i * 4 + 3])
        }

        for i in 16..<64 {
            let s0 = rightRotate(w[i - 15], by: 7) ^ rightRotate(w[i - 15], by: 18) ^ (w[i - 15] >> 3)
            let s1 = rightRotate(w[i - 2], by: 17) ^ rightRotate(w[i - 2], by: 19) ^ (w[i - 2] >> 10)
            w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
        }

        var a = h[0], b = h[1], c = h[2], d = h[3]
        var e = h[4], f = h[5], g = h[6], hh = h[7]

        for i in 0..<64 {
            let S1 = rightRotate(e, by: 6) ^ rightRotate(e, by: 11) ^ rightRotate(e, by: 25)
            let ch = (e & f) ^ (~e & g)
            let temp1 = hh &+ S1 &+ ch &+ k[i] &+ w[i]
            let S0 = rightRotate(a, by: 2) ^ rightRotate(a, by: 13) ^ rightRotate(a, by: 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = S0 &+ maj

            hh = g
            g = f
            f = e
            e = d &+ temp1
            d = c
            c = b
            b = a
            a = temp1 &+ temp2
        }

        h[0] &+= a
        h[1] &+= b
        h[2] &+= c
        h[3] &+= d
        h[4] &+= e
        h[5] &+= f
        h[6] &+= g
        h[7] &+= hh
    }

    private func rightRotate(_ value: UInt32, by amount: UInt32) -> UInt32 {
        return (value >> amount) | (value << (32 - amount))
    }
}

// MARK: - Cache Manager

/// Thread-safe cache manager for Gemini API responses
public actor GeminiCacheManager {
    private var cache: [String: Data] = [:]
    private var accessOrder: [String] = []
    private let config: GeminiCacheConfig

    public init(config: GeminiCacheConfig = .default) {
        self.config = config
    }

    /// Get a cached response
    public func get<T: Codable>(_ key: String) -> T? {
        guard config.isEnabled else { return nil }

        guard let data = cache[key] else { return nil }

        do {
            let entry = try JSONDecoder().decode(CacheEntry<T>.self, from: data)

            if entry.isExpired {
                // Remove expired entry
                cache.removeValue(forKey: key)
                accessOrder.removeAll { $0 == key }
                return nil
            }

            // Update access order (LRU)
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)

            return entry.value
        } catch {
            return nil
        }
    }

    /// Store a response in cache
    public func set<T: Codable>(_ key: String, value: T) {
        guard config.isEnabled else { return }

        let entry = CacheEntry(
            value: value,
            timestamp: Date(),
            expiresAt: Date().addingTimeInterval(config.ttl),
            requestHash: key
        )

        do {
            let data = try JSONEncoder().encode(entry)

            // Check size limit
            guard data.count <= config.maxResponseSize else { return }

            // Evict if necessary
            while cache.count >= config.maxEntries && !accessOrder.isEmpty {
                let oldestKey = accessOrder.removeFirst()
                cache.removeValue(forKey: oldestKey)
            }

            cache[key] = data
            accessOrder.append(key)
        } catch {
            // Silently fail on encoding errors
        }
    }

    /// Remove a specific entry
    public func remove(_ key: String) {
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    /// Clear all cached entries
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    /// Remove all expired entries
    public func pruneExpired() {
        var keysToRemove: [String] = []

        for (key, data) in cache {
            if let entry = try? JSONDecoder().decode(CacheEntry<GeminiGenerateContentResponse>.self, from: data),
               entry.isExpired {
                keysToRemove.append(key)
            }
        }

        for key in keysToRemove {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
    }

    /// Get cache statistics
    public var statistics: CacheStatistics {
        return CacheStatistics(
            entryCount: cache.count,
            maxEntries: config.maxEntries,
            totalSize: cache.values.reduce(0) { $0 + $1.count },
            ttl: config.ttl
        )
    }
}

// MARK: - Cache Statistics

/// Statistics about the cache
public struct CacheStatistics: Sendable {
    public let entryCount: Int
    public let maxEntries: Int
    public let totalSize: Int
    public let ttl: TimeInterval

    public var utilizationPercent: Double {
        guard maxEntries > 0 else { return 0 }
        return Double(entryCount) / Double(maxEntries) * 100
    }
}
