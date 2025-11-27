//
//  Logger.swift
//  Shlf
//
//  Created by João Fernandes on 27/11/2025.
//

import Foundation
import OSLog

/// Centralized logging system using Apple's unified logging
/// Swift 6 compliant: Logger is Sendable and thread-safe, safe for concurrent access
struct AppLogger: Sendable {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.shlf.app"

    nonisolated static let network = Logger(subsystem: subsystem, category: "Network")
    nonisolated static let cache = Logger(subsystem: subsystem, category: "Cache")
    nonisolated static let database = Logger(subsystem: subsystem, category: "Database")
    nonisolated static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Log an error with context
    nonisolated static func logError(_ error: Error, context: String, logger: Logger = AppLogger.network) {
        logger.error("\(context): \(error.localizedDescription)")
    }

    /// Log a warning
    nonisolated static func logWarning(_ message: String, logger: Logger = AppLogger.network) {
        logger.warning("\(message)")
    }

    /// Log info
    nonisolated static func logInfo(_ message: String, logger: Logger = AppLogger.network) {
        logger.info("\(message)")
    }
}
