//
//  GeminiAPIProvider.swift
//  gemini-swfit
//
//  Created by Claude on 2025-01-19.
//

import Foundation
import SwiftyBeaver

/// Represents a third-party API provider configuration
///
/// This allows the library to work with:
/// - Google's official Gemini API
/// - Third-party providers (OpenRouter, Together AI, etc.)
/// - Self-hosted endpoints
/// - Proxy servers
public struct GeminiAPIProvider: Sendable {

    // MARK: - Properties

    /// Provider name for identification
    public let name: String

    /// Base URL for the API
    public let baseURL: URL

    /// API keys for this provider
    public let apiKeys: [String]

    /// Custom headers to include in requests
    public let customHeaders: [String: String]

    /// Whether this provider requires a different authentication scheme
    public let authScheme: AuthScheme

    /// Model name mapping (provider model name -> Gemini model name)
    public let modelMapping: [String: String]

    /// Request transformation closure
    public let requestTransformer: (@Sendable (URLRequest) -> URLRequest)?

    /// Response transformation closure
    public let responseTransformer: (@Sendable (Data) throws -> Data)?

    // MARK: - Types

    /// Authentication scheme
    public enum AuthScheme: String, Sendable {
        /// API key in query parameter (Google style)
        case queryParameter = "query"
        /// API key in Authorization header as Bearer token
        case bearerToken = "bearer"
        /// API key in X-API-Key header
        case xApiKey = "x-api-key"
        /// Custom header (use customHeaders)
        case customHeader = "custom"
    }

    // MARK: - Initialization

    public init(
        name: String,
        baseURL: URL,
        apiKeys: [String],
        customHeaders: [String: String] = [:],
        authScheme: AuthScheme = .queryParameter,
        modelMapping: [String: String] = [:],
        requestTransformer: (@Sendable (URLRequest) -> URLRequest)? = nil,
        responseTransformer: (@Sendable (Data) throws -> Data)? = nil
    ) {
        self.name = name
        self.baseURL = baseURL
        self.apiKeys = apiKeys
        self.customHeaders = customHeaders
        self.authScheme = authScheme
        self.modelMapping = modelMapping
        self.requestTransformer = requestTransformer
        self.responseTransformer = responseTransformer
    }

    // MARK: - Predefined Providers

    /// Google's official Gemini API
    public static func google(apiKeys: [String]) -> GeminiAPIProvider {
        return GeminiAPIProvider(
            name: "Google Gemini",
            baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta/")!,
            apiKeys: apiKeys,
            authScheme: .queryParameter
        )
    }

    /// Google's official Gemini API with single key
    public static func google(apiKey: String) -> GeminiAPIProvider {
        return google(apiKeys: [apiKey])
    }

    /// OpenRouter provider
    public static func openRouter(apiKey: String) -> GeminiAPIProvider {
        return GeminiAPIProvider(
            name: "OpenRouter",
            baseURL: URL(string: "https://openrouter.ai/api/v1/")!,
            apiKeys: [apiKey],
            customHeaders: [
                "HTTP-Referer": "https://github.com/anthropics/gemini-swift",
                "X-Title": "Gemini Swift SDK"
            ],
            authScheme: .bearerToken,
            modelMapping: [
                "gemini-2.5-pro": "google/gemini-2.5-pro",
                "gemini-2.5-flash": "google/gemini-2.5-flash"
            ]
        )
    }

    /// Together AI provider
    public static func togetherAI(apiKey: String) -> GeminiAPIProvider {
        return GeminiAPIProvider(
            name: "Together AI",
            baseURL: URL(string: "https://api.together.xyz/v1/")!,
            apiKeys: [apiKey],
            authScheme: .bearerToken
        )
    }

    /// Fireworks AI provider
    public static func fireworks(apiKey: String) -> GeminiAPIProvider {
        return GeminiAPIProvider(
            name: "Fireworks AI",
            baseURL: URL(string: "https://api.fireworks.ai/inference/v1/")!,
            apiKeys: [apiKey],
            authScheme: .bearerToken
        )
    }

    /// Custom provider with URL string
    public static func custom(
        name: String,
        baseURL: String,
        apiKey: String,
        authScheme: AuthScheme = .bearerToken,
        customHeaders: [String: String] = [:]
    ) -> GeminiAPIProvider? {
        guard let url = URL(string: baseURL) else { return nil }
        return GeminiAPIProvider(
            name: name,
            baseURL: url,
            apiKeys: [apiKey],
            customHeaders: customHeaders,
            authScheme: authScheme
        )
    }

    /// Self-hosted endpoint
    public static func selfHosted(
        baseURL: String,
        apiKey: String? = nil,
        authScheme: AuthScheme = .bearerToken
    ) -> GeminiAPIProvider? {
        guard let url = URL(string: baseURL) else { return nil }
        return GeminiAPIProvider(
            name: "Self-Hosted",
            baseURL: url,
            apiKeys: apiKey.map { [$0] } ?? [],
            authScheme: authScheme
        )
    }

    // MARK: - Methods

    /// Apply authentication to a URL request
    public func applyAuth(to request: inout URLRequest, apiKey: String) {
        switch authScheme {
        case .queryParameter:
            // Add API key to URL query parameters
            if var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) {
                var queryItems = components.queryItems ?? []
                queryItems.append(URLQueryItem(name: "key", value: apiKey))
                components.queryItems = queryItems
                request.url = components.url
            }

        case .bearerToken:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        case .xApiKey:
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        case .customHeader:
            // Custom headers are applied separately
            break
        }

        // Apply custom headers
        for (key, value) in customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    /// Map a model name to this provider's model name
    public func mapModel(_ modelName: String) -> String {
        return modelMapping[modelName] ?? modelName
    }

    /// Transform a request for this provider
    public func transformRequest(_ request: URLRequest) -> URLRequest {
        if let transformer = requestTransformer {
            return transformer(request)
        }
        return request
    }

    /// Transform a response from this provider
    public func transformResponse(_ data: Data) throws -> Data {
        if let transformer = responseTransformer {
            return try transformer(data)
        }
        return data
    }
}

// MARK: - Provider Manager

/// Manages multiple API providers
public class GeminiProviderManager {

    // MARK: - Properties

    private var providers: [String: GeminiAPIProvider] = [:]
    private var currentProviderName: String?
    private let providerQueue = DispatchQueue(label: "com.gemini.providers", attributes: .concurrent)
    private let logger: SwiftyBeaver.Type

    /// Default provider (first registered or explicitly set)
    public var defaultProvider: GeminiAPIProvider? {
        return providerQueue.sync {
            if let name = currentProviderName {
                return providers[name]
            }
            return providers.values.first
        }
    }

    // MARK: - Initialization

    public init(logger: SwiftyBeaver.Type = SwiftyBeaver.self) {
        self.logger = logger
    }

    /// Initialize with a single provider
    public convenience init(provider: GeminiAPIProvider, logger: SwiftyBeaver.Type = SwiftyBeaver.self) {
        self.init(logger: logger)
        register(provider)
    }

    // MARK: - Provider Management

    /// Register a provider
    public func register(_ provider: GeminiAPIProvider) {
        providerQueue.sync(flags: .barrier) {
            providers[provider.name] = provider
            if currentProviderName == nil {
                currentProviderName = provider.name
            }
        }
        logger.info("Registered API provider: \(provider.name)")
    }

    /// Remove a provider
    public func remove(_ providerName: String) {
        providerQueue.sync(flags: .barrier) {
            providers.removeValue(forKey: providerName)
            if currentProviderName == providerName {
                currentProviderName = providers.keys.first
            }
        }
        logger.info("Removed API provider: \(providerName)")
    }

    /// Set the current provider
    public func setCurrentProvider(_ providerName: String) -> Bool {
        return providerQueue.sync(flags: .barrier) {
            guard providers[providerName] != nil else { return false }
            currentProviderName = providerName
            return true
        }
    }

    /// Get a provider by name
    public func getProvider(_ name: String) -> GeminiAPIProvider? {
        return providerQueue.sync {
            providers[name]
        }
    }

    /// Get all registered provider names
    public var providerNames: [String] {
        return providerQueue.sync {
            Array(providers.keys)
        }
    }

    /// Get the current provider name
    public var currentName: String? {
        return providerQueue.sync {
            currentProviderName
        }
    }
}

// MARK: - Extended GeminiClient Support

extension GeminiClient {

    /// Create a client with a specific provider
    public convenience init(provider: GeminiAPIProvider, logger: SwiftyBeaver.Type = SwiftyBeaver.self) {
        self.init(
            apiKeys: provider.apiKeys,
            baseURL: provider.baseURL,
            logger: logger
        )
    }

    /// Create a client with custom third-party URL and key
    public convenience init(
        thirdPartyURL: String,
        apiKey: String,
        authScheme: GeminiAPIProvider.AuthScheme = .bearerToken,
        logger: SwiftyBeaver.Type = SwiftyBeaver.self
    ) {
        guard let provider = GeminiAPIProvider.custom(
            name: "Custom Provider",
            baseURL: thirdPartyURL,
            apiKey: apiKey,
            authScheme: authScheme
        ) else {
            fatalError("Invalid URL: \(thirdPartyURL)")
        }

        self.init(provider: provider, logger: logger)
    }

    /// Create a client with OpenRouter
    public static func withOpenRouter(apiKey: String, logger: SwiftyBeaver.Type = SwiftyBeaver.self) -> GeminiClient {
        let provider = GeminiAPIProvider.openRouter(apiKey: apiKey)
        return GeminiClient(provider: provider, logger: logger)
    }

    /// Create a client with Together AI
    public static func withTogetherAI(apiKey: String, logger: SwiftyBeaver.Type = SwiftyBeaver.self) -> GeminiClient {
        let provider = GeminiAPIProvider.togetherAI(apiKey: apiKey)
        return GeminiClient(provider: provider, logger: logger)
    }
}
