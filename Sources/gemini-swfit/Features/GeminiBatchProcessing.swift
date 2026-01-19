import Foundation
import SwiftyBeaver

// MARK: - Batch Processing Configuration

/// Configuration for batch processing
public struct BatchConfig: Sendable {
    /// Maximum requests per batch
    public let maxBatchSize: Int

    /// Timeout for entire batch operation
    public let batchTimeout: TimeInterval

    /// Polling interval for batch status
    public let pollingInterval: TimeInterval

    /// Whether to retry failed requests in batch
    public let retryFailedRequests: Bool

    public init(
        maxBatchSize: Int = 100,
        batchTimeout: TimeInterval = 3600,
        pollingInterval: TimeInterval = 5.0,
        retryFailedRequests: Bool = true
    ) {
        self.maxBatchSize = maxBatchSize
        self.batchTimeout = batchTimeout
        self.pollingInterval = pollingInterval
        self.retryFailedRequests = retryFailedRequests
    }

    public static let `default` = BatchConfig()

    public static let large = BatchConfig(
        maxBatchSize: 500,
        batchTimeout: 7200,
        pollingInterval: 10.0
    )
}

// MARK: - Batch Request

/// A single request in a batch
public struct BatchRequest: Codable, Sendable {
    public let id: String
    public let model: String
    public let contents: [Content]
    public let systemInstruction: SystemInstruction?
    public let generationConfig: GenerationConfig?
    public let safetySettings: [SafetySetting]?

    public init(
        id: String = UUID().uuidString,
        model: String,
        contents: [Content],
        systemInstruction: SystemInstruction? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil
    ) {
        self.id = id
        self.model = model
        self.contents = contents
        self.systemInstruction = systemInstruction
        self.generationConfig = generationConfig
        self.safetySettings = safetySettings
    }

    /// Create a simple text request
    public static func text(
        _ text: String,
        model: String = "gemini-2.5-flash",
        id: String = UUID().uuidString
    ) -> BatchRequest {
        return BatchRequest(
            id: id,
            model: model,
            contents: [Content(parts: [Part(text: text)])]
        )
    }
}

// MARK: - Batch Response

/// Response for a single request in a batch
public struct BatchResponse: Codable, Sendable {
    public let id: String
    public let response: GeminiGenerateContentResponse?
    public let error: BatchError?
    public let status: BatchItemStatus

    public enum BatchItemStatus: String, Codable, Sendable {
        case pending = "PENDING"
        case processing = "PROCESSING"
        case completed = "COMPLETED"
        case failed = "FAILED"
    }

    public struct BatchError: Codable, Sendable {
        public let code: Int
        public let message: String

        public init(code: Int, message: String) {
            self.code = code
            self.message = message
        }
    }

    public var isSuccess: Bool {
        return status == .completed && error == nil
    }

    public var text: String? {
        return response?.candidates.first?.content.parts.compactMap { $0.text }.joined()
    }
}

// MARK: - Batch Job

/// Represents a batch processing job
public struct BatchJob: Codable, Sendable {
    public let jobId: String
    public let status: BatchJobStatus
    public let createTime: Date
    public let updateTime: Date?
    public let completedCount: Int
    public let failedCount: Int
    public let totalCount: Int
    public let outputUri: String?

    public enum BatchJobStatus: String, Codable, Sendable {
        case stateUnspecified = "STATE_UNSPECIFIED"
        case pending = "JOB_STATE_PENDING"
        case running = "JOB_STATE_RUNNING"
        case succeeded = "JOB_STATE_SUCCEEDED"
        case failed = "JOB_STATE_FAILED"
        case cancelled = "JOB_STATE_CANCELLED"
    }

    public var isComplete: Bool {
        return status == .succeeded || status == .failed || status == .cancelled
    }

    public var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount + failedCount) / Double(totalCount)
    }
}

// MARK: - Batch Processor

/// Processor for handling batch requests
public actor BatchProcessor {
    private let apiKey: String
    private let baseURL: String
    private let config: BatchConfig
    private let session: URLSession
    private let logger: SwiftyBeaver.Type
    private var activeJobs: [String: BatchJob] = [:]

    public init(
        apiKey: String,
        baseURL: String = "https://generativelanguage.googleapis.com/v1beta",
        config: BatchConfig = .default,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.config = config
        self.session = URLSession.shared
        self.logger = logger
    }

    /// Submit a batch of requests for processing
    public func submitBatch(_ requests: [BatchRequest]) async throws -> BatchJob {
        guard !requests.isEmpty else {
            throw BatchError.emptyBatch
        }

        guard requests.count <= config.maxBatchSize else {
            throw BatchError.batchTooLarge(max: config.maxBatchSize)
        }

        let batchPayload = BatchSubmitPayload(
            requests: requests.map { request in
                BatchSubmitPayload.RequestItem(
                    customId: request.id,
                    request: BatchSubmitPayload.GenerateRequest(
                        model: "models/\(request.model)",
                        contents: request.contents,
                        systemInstruction: request.systemInstruction,
                        generationConfig: request.generationConfig,
                        safetySettings: request.safetySettings
                    )
                )
            }
        )

        let url = URL(string: "\(baseURL)/batchGenerateContent?key=\(apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(batchPayload)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BatchError.submissionFailed(errorMessage)
        }

        let jobResponse = try JSONDecoder().decode(BatchJobResponse.self, from: data)

        let job = BatchJob(
            jobId: jobResponse.name,
            status: .pending,
            createTime: Date(),
            updateTime: nil,
            completedCount: 0,
            failedCount: 0,
            totalCount: requests.count,
            outputUri: nil
        )

        activeJobs[job.jobId] = job
        logger.info("Batch job submitted: \(job.jobId)")

        return job
    }

    /// Wait for a batch job to complete and return results
    public func waitForCompletion(_ jobId: String) async throws -> [BatchResponse] {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < config.batchTimeout {
            let status = try await getJobStatus(jobId)

            if status.isComplete {
                if status.status == .succeeded {
                    return try await getResults(jobId)
                } else {
                    throw BatchError.jobFailed(status.status.rawValue)
                }
            }

            logger.debug("Batch job \(jobId): \(Int(status.progress * 100))% complete")

            try await Task.sleep(nanoseconds: UInt64(config.pollingInterval * 1_000_000_000))
        }

        throw BatchError.timeout
    }

    /// Get the status of a batch job
    public func getJobStatus(_ jobId: String) async throws -> BatchJob {
        let url = URL(string: "\(baseURL)/\(jobId)?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BatchError.statusCheckFailed
        }

        let jobResponse = try JSONDecoder().decode(BatchJobStatusResponse.self, from: data)

        let job = BatchJob(
            jobId: jobId,
            status: BatchJob.BatchJobStatus(rawValue: jobResponse.state) ?? .stateUnspecified,
            createTime: activeJobs[jobId]?.createTime ?? Date(),
            updateTime: Date(),
            completedCount: jobResponse.completedCount ?? 0,
            failedCount: jobResponse.failedCount ?? 0,
            totalCount: jobResponse.totalCount ?? activeJobs[jobId]?.totalCount ?? 0,
            outputUri: jobResponse.outputUri
        )

        activeJobs[jobId] = job
        return job
    }

    /// Get results for a completed batch job
    public func getResults(_ jobId: String) async throws -> [BatchResponse] {
        let url = URL(string: "\(baseURL)/\(jobId)/results?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BatchError.resultsFetchFailed
        }

        let resultsResponse = try JSONDecoder().decode(BatchResultsResponse.self, from: data)

        return resultsResponse.responses.map { item in
            BatchResponse(
                id: item.customId,
                response: item.response,
                error: item.error != nil ? BatchResponse.BatchError(
                    code: item.error?.code ?? 0,
                    message: item.error?.message ?? "Unknown error"
                ) : nil,
                status: item.error == nil ? .completed : .failed
            )
        }
    }

    /// Cancel a batch job
    public func cancelJob(_ jobId: String) async throws {
        let url = URL(string: "\(baseURL)/\(jobId):cancel?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BatchError.cancellationFailed
        }

        if var job = activeJobs[jobId] {
            activeJobs[jobId] = BatchJob(
                jobId: job.jobId,
                status: .cancelled,
                createTime: job.createTime,
                updateTime: Date(),
                completedCount: job.completedCount,
                failedCount: job.failedCount,
                totalCount: job.totalCount,
                outputUri: job.outputUri
            )
        }

        logger.info("Batch job cancelled: \(jobId)")
    }

    /// Get all active jobs
    public func getActiveJobs() -> [BatchJob] {
        return Array(activeJobs.values)
    }
}

// MARK: - Batch Errors

public enum BatchError: Error, LocalizedError {
    case emptyBatch
    case batchTooLarge(max: Int)
    case submissionFailed(String)
    case statusCheckFailed
    case resultsFetchFailed
    case cancellationFailed
    case timeout
    case jobFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyBatch:
            return "Batch cannot be empty"
        case .batchTooLarge(let max):
            return "Batch size exceeds maximum of \(max)"
        case .submissionFailed(let message):
            return "Batch submission failed: \(message)"
        case .statusCheckFailed:
            return "Failed to check batch status"
        case .resultsFetchFailed:
            return "Failed to fetch batch results"
        case .cancellationFailed:
            return "Failed to cancel batch job"
        case .timeout:
            return "Batch processing timed out"
        case .jobFailed(let status):
            return "Batch job failed with status: \(status)"
        }
    }
}

// MARK: - API Response Models

private struct BatchSubmitPayload: Codable {
    let requests: [RequestItem]

    struct RequestItem: Codable {
        let customId: String
        let request: GenerateRequest
    }

    struct GenerateRequest: Codable {
        let model: String
        let contents: [Content]
        let systemInstruction: SystemInstruction?
        let generationConfig: GenerationConfig?
        let safetySettings: [SafetySetting]?
    }
}

private struct BatchJobResponse: Codable {
    let name: String
}

private struct BatchJobStatusResponse: Codable {
    let name: String
    let state: String
    let completedCount: Int?
    let failedCount: Int?
    let totalCount: Int?
    let outputUri: String?
}

private struct BatchResultsResponse: Codable {
    let responses: [ResultItem]

    struct ResultItem: Codable {
        let customId: String
        let response: GeminiGenerateContentResponse?
        let error: ErrorInfo?
    }

    struct ErrorInfo: Codable {
        let code: Int
        let message: String
    }
}

// MARK: - Convenience Extensions

extension BatchProcessor {
    /// Submit and wait for simple text prompts
    public func processTexts(
        _ texts: [String],
        model: String = "gemini-2.5-flash"
    ) async throws -> [BatchResponse] {
        let requests = texts.enumerated().map { index, text in
            BatchRequest.text(text, model: model, id: "request-\(index)")
        }

        let job = try await submitBatch(requests)
        return try await waitForCompletion(job.jobId)
    }

    /// Process with progress callback
    public func processWithProgress(
        _ requests: [BatchRequest],
        onProgress: @escaping (Double) -> Void
    ) async throws -> [BatchResponse] {
        let job = try await submitBatch(requests)

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < config.batchTimeout {
            let status = try await getJobStatus(job.jobId)

            onProgress(status.progress)

            if status.isComplete {
                if status.status == .succeeded {
                    return try await getResults(job.jobId)
                } else {
                    throw BatchError.jobFailed(status.status.rawValue)
                }
            }

            try await Task.sleep(nanoseconds: UInt64(config.pollingInterval * 1_000_000_000))
        }

        throw BatchError.timeout
    }
}
