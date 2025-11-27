//
//  RetryPolicy.swift
//  Shlf
//
//  Created by João Fernandes on 27/11/2025.
//

import Foundation

/// Retry policy with exponential backoff for network requests
actor RetryPolicy {
    private let maxRetries: Int
    private let baseDelay: TimeInterval

    init(maxRetries: Int = 3, baseDelay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }

    /// Execute an async operation with retry logic
    /// - Parameter operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: The last error if all retries fail
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry on final attempt
                if attempt == maxRetries - 1 {
                    break
                }

                // Only retry on retryable errors
                if !isRetryable(error: error) {
                    throw error
                }

                // Calculate delay with exponential backoff
                let delay = baseDelay * pow(2.0, Double(attempt))
                let jitter = Double.random(in: 0...0.3) * delay // Add jitter to prevent thundering herd
                let totalDelay = delay + jitter

                try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
            }
        }

        // All retries failed, throw the last error
        throw lastError ?? NSError(domain: "RetryPolicy", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retries failed"])
    }

    /// Determine if an error is retryable
    private func isRetryable(error: Error) -> Bool {
        // Network errors that are retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .dnsLookupFailed,
                 .cannotFindHost:
                return true
            default:
                return false
            }
        }

        // HTTP errors - only retry 5xx server errors, not 4xx client errors
        if let httpError = error as NSError?, httpError.domain == "HTTPError" {
            let statusCode = httpError.code
            return statusCode >= 500 && statusCode < 600
        }

        return false
    }
}
