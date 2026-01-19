import Foundation

// MARK: - Request Tracing

/// Unique identifier for tracking requests across the system
public struct RequestTraceId: Hashable, Sendable, CustomStringConvertible {
    public let value: String
    public let timestamp: Date

    public init() {
        self.value = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        self.timestamp = Date()
    }

    public init(value: String) {
        self.value = value
        self.timestamp = Date()
    }

    public var description: String {
        return value
    }

    /// Short version of the trace ID (first 8 characters)
    public var shortId: String {
        return String(value.prefix(8))
    }
}

// MARK: - Request Context

/// Context for a single request including trace information
public struct RequestContext: Sendable {
    public let traceId: RequestTraceId
    public let parentTraceId: RequestTraceId?
    public let spanId: String
    public let operation: String
    public let startTime: Date
    public var metadata: [String: String]

    public init(
        operation: String,
        parentTraceId: RequestTraceId? = nil,
        metadata: [String: String] = [:]
    ) {
        self.traceId = RequestTraceId()
        self.parentTraceId = parentTraceId
        self.spanId = UUID().uuidString.prefix(16).lowercased()
        self.operation = operation
        self.startTime = Date()
        self.metadata = metadata
    }

    /// Duration since request started
    public var duration: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }

    /// Create a child context for nested operations
    public func createChild(operation: String) -> RequestContext {
        return RequestContext(
            operation: operation,
            parentTraceId: traceId,
            metadata: metadata
        )
    }
}

// MARK: - Request Event

/// Events that occur during request processing
public enum RequestEvent: Sendable {
    case started(RequestContext)
    case retrying(attempt: Int, reason: String)
    case cacheHit(key: String)
    case cacheMiss(key: String)
    case responseReceived(statusCode: Int, duration: TimeInterval)
    case completed(duration: TimeInterval)
    case failed(error: String, duration: TimeInterval)
}

// MARK: - Request Trace

/// Complete trace of a request lifecycle
public struct RequestTrace: Sendable {
    public let context: RequestContext
    public private(set) var events: [RequestEvent]
    public private(set) var endTime: Date?
    public private(set) var result: RequestResult?

    public init(context: RequestContext) {
        self.context = context
        self.events = [.started(context)]
    }

    public mutating func addEvent(_ event: RequestEvent) {
        events.append(event)
    }

    public mutating func complete(result: RequestResult) {
        self.result = result
        self.endTime = Date()

        let duration = context.duration
        switch result {
        case .success:
            events.append(.completed(duration: duration))
        case .failure(let error):
            events.append(.failed(error: error, duration: duration))
        }
    }

    public var duration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(context.startTime)
        }
        return context.duration
    }

    public var isComplete: Bool {
        return result != nil
    }
}

/// Result of a traced request
public enum RequestResult: Sendable {
    case success(statusCode: Int)
    case failure(String)
}

// MARK: - Trace Observer Protocol

/// Protocol for observing request traces
public protocol TraceObserver: Sendable {
    func onEvent(_ event: RequestEvent, context: RequestContext)
    func onTraceComplete(_ trace: RequestTrace)
}

// MARK: - Console Trace Observer

/// Observer that logs traces to console
public final class ConsoleTraceObserver: TraceObserver, @unchecked Sendable {
    private let enabled: Bool
    private let includeMetadata: Bool

    public init(enabled: Bool = true, includeMetadata: Bool = false) {
        self.enabled = enabled
        self.includeMetadata = includeMetadata
    }

    public func onEvent(_ event: RequestEvent, context: RequestContext) {
        guard enabled else { return }

        let prefix = "[\(context.traceId.shortId)]"

        switch event {
        case .started(let ctx):
            print("\(prefix) Started: \(ctx.operation)")
        case .retrying(let attempt, let reason):
            print("\(prefix) Retry #\(attempt): \(reason)")
        case .cacheHit(let key):
            print("\(prefix) Cache HIT: \(key.prefix(16))...")
        case .cacheMiss(let key):
            print("\(prefix) Cache MISS: \(key.prefix(16))...")
        case .responseReceived(let statusCode, let duration):
            print("\(prefix) Response: \(statusCode) in \(String(format: "%.2f", duration * 1000))ms")
        case .completed(let duration):
            print("\(prefix) Completed in \(String(format: "%.2f", duration * 1000))ms")
        case .failed(let error, let duration):
            print("\(prefix) Failed after \(String(format: "%.2f", duration * 1000))ms: \(error)")
        }
    }

    public func onTraceComplete(_ trace: RequestTrace) {
        guard enabled && includeMetadata else { return }

        let prefix = "[\(trace.context.traceId.shortId)]"
        print("\(prefix) Trace complete - Operation: \(trace.context.operation), Duration: \(String(format: "%.2f", trace.duration * 1000))ms")

        if !trace.context.metadata.isEmpty {
            print("\(prefix) Metadata: \(trace.context.metadata)")
        }
    }
}

// MARK: - Trace Storage

/// Thread-safe storage for request traces
public actor TraceStorage {
    private var traces: [String: RequestTrace] = [:]
    private let maxTraces: Int
    private var traceOrder: [String] = []

    public init(maxTraces: Int = 1000) {
        self.maxTraces = maxTraces
    }

    public func store(_ trace: RequestTrace) {
        let id = trace.context.traceId.value

        // Evict oldest if at capacity
        if traces.count >= maxTraces && !traceOrder.isEmpty {
            let oldestId = traceOrder.removeFirst()
            traces.removeValue(forKey: oldestId)
        }

        traces[id] = trace
        traceOrder.append(id)
    }

    public func get(_ traceId: String) -> RequestTrace? {
        return traces[traceId]
    }

    public func getRecent(count: Int = 10) -> [RequestTrace] {
        let recentIds = traceOrder.suffix(count)
        return recentIds.compactMap { traces[$0] }
    }

    public func clear() {
        traces.removeAll()
        traceOrder.removeAll()
    }

    public var count: Int {
        return traces.count
    }
}

// MARK: - Tracing Manager

/// Central manager for request tracing
public actor TracingManager {
    private var observers: [any TraceObserver] = []
    private let storage: TraceStorage
    private var activeTraces: [String: RequestTrace] = [:]
    private let enabled: Bool

    public init(enabled: Bool = true, storageCapacity: Int = 1000) {
        self.enabled = enabled
        self.storage = TraceStorage(maxTraces: storageCapacity)
    }

    public func addObserver(_ observer: any TraceObserver) {
        observers.append(observer)
    }

    public func startTrace(operation: String, metadata: [String: String] = [:]) -> RequestContext {
        let context = RequestContext(operation: operation, metadata: metadata)

        if enabled {
            let trace = RequestTrace(context: context)
            activeTraces[context.traceId.value] = trace

            for observer in observers {
                observer.onEvent(.started(context), context: context)
            }
        }

        return context
    }

    public func recordEvent(_ event: RequestEvent, for context: RequestContext) {
        guard enabled else { return }

        if var trace = activeTraces[context.traceId.value] {
            trace.addEvent(event)
            activeTraces[context.traceId.value] = trace
        }

        for observer in observers {
            observer.onEvent(event, context: context)
        }
    }

    public func completeTrace(_ context: RequestContext, result: RequestResult) async {
        guard enabled else { return }

        if var trace = activeTraces[context.traceId.value] {
            trace.complete(result: result)
            activeTraces.removeValue(forKey: context.traceId.value)

            await storage.store(trace)

            for observer in observers {
                observer.onTraceComplete(trace)
            }
        }
    }

    public func getTrace(_ traceId: String) async -> RequestTrace? {
        if let active = activeTraces[traceId] {
            return active
        }
        return await storage.get(traceId)
    }

    public func getRecentTraces(count: Int = 10) async -> [RequestTrace] {
        return await storage.getRecent(count: count)
    }

    public var activeTraceCount: Int {
        return activeTraces.count
    }
}

// MARK: - Trace Statistics

/// Statistics computed from traces
public struct TraceStatistics: Sendable {
    public let totalRequests: Int
    public let successCount: Int
    public let failureCount: Int
    public let averageDuration: TimeInterval
    public let p50Duration: TimeInterval
    public let p95Duration: TimeInterval
    public let p99Duration: TimeInterval
    public let cacheHitRate: Double
    public let averageRetries: Double

    public var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successCount) / Double(totalRequests)
    }
}

extension TraceStorage {
    /// Compute statistics from stored traces
    public func computeStatistics() -> TraceStatistics {
        let allTraces = Array(traces.values)

        guard !allTraces.isEmpty else {
            return TraceStatistics(
                totalRequests: 0,
                successCount: 0,
                failureCount: 0,
                averageDuration: 0,
                p50Duration: 0,
                p95Duration: 0,
                p99Duration: 0,
                cacheHitRate: 0,
                averageRetries: 0
            )
        }

        let completedTraces = allTraces.filter { $0.isComplete }
        let successCount = completedTraces.filter {
            if case .success = $0.result { return true }
            return false
        }.count

        let durations = completedTraces.map { $0.duration }.sorted()
        let avgDuration = durations.reduce(0, +) / Double(max(1, durations.count))

        // Calculate percentiles
        let p50Index = Int(Double(durations.count) * 0.50)
        let p95Index = Int(Double(durations.count) * 0.95)
        let p99Index = Int(Double(durations.count) * 0.99)

        // Count cache hits
        var cacheHits = 0
        var cacheMisses = 0
        var totalRetries = 0

        for trace in allTraces {
            for event in trace.events {
                switch event {
                case .cacheHit:
                    cacheHits += 1
                case .cacheMiss:
                    cacheMisses += 1
                case .retrying:
                    totalRetries += 1
                default:
                    break
                }
            }
        }

        let totalCacheOps = cacheHits + cacheMisses
        let cacheHitRate = totalCacheOps > 0 ? Double(cacheHits) / Double(totalCacheOps) : 0
        let avgRetries = allTraces.isEmpty ? 0 : Double(totalRetries) / Double(allTraces.count)

        return TraceStatistics(
            totalRequests: allTraces.count,
            successCount: successCount,
            failureCount: completedTraces.count - successCount,
            averageDuration: avgDuration,
            p50Duration: durations.isEmpty ? 0 : durations[min(p50Index, durations.count - 1)],
            p95Duration: durations.isEmpty ? 0 : durations[min(p95Index, durations.count - 1)],
            p99Duration: durations.isEmpty ? 0 : durations[min(p99Index, durations.count - 1)],
            cacheHitRate: cacheHitRate,
            averageRetries: avgRetries
        )
    }
}
