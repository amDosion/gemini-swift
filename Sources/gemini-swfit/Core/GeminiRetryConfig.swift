import Foundation

// MARK: - Retry Configuration

/// Configuration for automatic retry with exponential backoff
public struct GeminiRetryConfig: Sendable {
    /// Maximum number of retry attempts
    public let maxRetries: Int

    /// Base delay in seconds for exponential backoff
    public let baseDelay: TimeInterval

    /// Maximum delay in seconds between retries
    public let maxDelay: TimeInterval

    /// Multiplier for exponential backoff (default: 2.0)
    public let multiplier: Double

    /// Jitter factor to add randomness to delay (0.0 - 1.0)
    public let jitterFactor: Double

    /// HTTP status codes that should trigger a retry
    public let retryableStatusCodes: Set<Int>

    /// Whether to retry on network errors
    public let retryOnNetworkError: Bool

    /// Default retry configuration
    public static let `default` = GeminiRetryConfig(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitterFactor: 0.1,
        retryableStatusCodes: [429, 500, 502, 503, 504],
        retryOnNetworkError: true
    )

    /// No retry configuration
    public static let noRetry = GeminiRetryConfig(
        maxRetries: 0,
        baseDelay: 0,
        maxDelay: 0,
        multiplier: 1.0,
        jitterFactor: 0,
        retryableStatusCodes: [],
        retryOnNetworkError: false
    )

    /// Aggressive retry configuration for critical requests
    public static let aggressive = GeminiRetryConfig(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        multiplier: 2.0,
        jitterFactor: 0.2,
        retryableStatusCodes: [429, 500, 502, 503, 504, 408],
        retryOnNetworkError: true
    )

    public init(
        maxRetries: Int,
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        multiplier: Double = 2.0,
        jitterFactor: Double = 0.1,
        retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504],
        retryOnNetworkError: Bool = true
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.multiplier = max(1.0, multiplier)
        self.jitterFactor = min(max(0, jitterFactor), 1.0)
        self.retryableStatusCodes = retryableStatusCodes
        self.retryOnNetworkError = retryOnNetworkError
    }

    /// Calculate delay for a given retry attempt
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(multiplier, Double(attempt))
        let clampedDelay = min(exponentialDelay, maxDelay)

        // Add jitter
        let jitter = clampedDelay * jitterFactor * Double.random(in: -1...1)
        return max(0, clampedDelay + jitter)
    }

    /// Check if an HTTP status code should trigger a retry
    public func shouldRetry(statusCode: Int) -> Bool {
        return retryableStatusCodes.contains(statusCode)
    }

    /// Check if an error should trigger a retry
    public func shouldRetry(error: Error) -> Bool {
        if retryOnNetworkError {
            let nsError = error as NSError
            let networkErrorCodes: Set<Int> = [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorNotConnectedToInternet
            ]
            return networkErrorCodes.contains(nsError.code)
        }
        return false
    }
}

// MARK: - Retry Result

/// Result of a retry operation
public enum RetryResult<T> {
    case success(T, attempts: Int)
    case failure(Error, attempts: Int)

    public var value: T? {
        if case .success(let value, _) = self {
            return value
        }
        return nil
    }

    public var error: Error? {
        if case .failure(let error, _) = self {
            return error
        }
        return nil
    }

    public var attemptCount: Int {
        switch self {
        case .success(_, let attempts): return attempts
        case .failure(_, let attempts): return attempts
        }
    }
}

// MARK: - Retry Executor

/// Executes operations with automatic retry and exponential backoff
public actor RetryExecutor {
    private let config: GeminiRetryConfig

    public init(config: GeminiRetryConfig = .default) {
        self.config = config
    }

    /// Execute an async operation with retry logic
    public func execute<T>(
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...config.maxRetries {
            do {
                let result = try await operation()
                return result
            } catch {
                lastError = error

                // Check if we should retry
                let shouldRetry = config.shouldRetry(error: error) ||
                    (error as? GeminiClient.GeminiError).map { geminiError in
                        if case .apiError(_, let statusCode) = geminiError,
                           let code = statusCode {
                            return config.shouldRetry(statusCode: code)
                        }
                        return false
                    } ?? false

                // If this is the last attempt or we shouldn't retry, throw
                if attempt == config.maxRetries || !shouldRetry {
                    throw error
                }

                // Wait before retrying
                let delay = config.delay(forAttempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? GeminiClient.GeminiError.invalidResponse
    }

    /// Execute with detailed result including attempt count
    public func executeWithResult<T>(
        operation: @Sendable () async throws -> T
    ) async -> RetryResult<T> {
        var lastError: Error?

        for attempt in 0...config.maxRetries {
            do {
                let result = try await operation()
                return .success(result, attempts: attempt + 1)
            } catch {
                lastError = error

                let shouldRetry = config.shouldRetry(error: error)

                if attempt == config.maxRetries || !shouldRetry {
                    return .failure(error, attempts: attempt + 1)
                }

                let delay = config.delay(forAttempt: attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        return .failure(lastError ?? GeminiClient.GeminiError.invalidResponse, attempts: config.maxRetries + 1)
    }
}

// MARK: - Retry Statistics

/// Statistics about retry operations
public struct RetryStatistics: Sendable {
    public let totalAttempts: Int
    public let successfulAttempts: Int
    public let failedAttempts: Int
    public let totalRetries: Int
    public let averageRetriesPerRequest: Double

    public var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(successfulAttempts) / Double(totalAttempts)
    }
}
