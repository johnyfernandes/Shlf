//
//  RateLimiter.swift
//  Shlf
//
//  Created by João Fernandes on 27/11/2025.
//

import Foundation

/// Actor-based rate limiter for API requests
/// Implements token bucket algorithm with sliding window
actor RateLimiter {
    private let maxRequestsPerSecond: Int
    private var requestTimestamps: [Date] = []

    init(maxRequestsPerSecond: Int) {
        self.maxRequestsPerSecond = maxRequestsPerSecond
    }

    /// Wait until a token is available for making a request
    /// Automatically sleeps if rate limit is exceeded
    func waitForToken() async {
        let now = Date()
        let oneSecondAgo = now.addingTimeInterval(-1.0)

        // Remove timestamps older than 1 second (sliding window)
        requestTimestamps.removeAll { $0 < oneSecondAgo }

        // If we've hit the limit, wait
        if requestTimestamps.count >= maxRequestsPerSecond {
            // Calculate how long to wait
            if let oldestRequest = requestTimestamps.first {
                let timeSinceOldest = now.timeIntervalSince(oldestRequest)
                let waitTime = 1.0 - timeSinceOldest

                if waitTime > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }

            // Clean up again after waiting
            let afterWait = Date()
            let oneSecondAgoAfterWait = afterWait.addingTimeInterval(-1.0)
            requestTimestamps.removeAll { $0 < oneSecondAgoAfterWait }
        }

        // Record this request
        requestTimestamps.append(Date())
    }
}
