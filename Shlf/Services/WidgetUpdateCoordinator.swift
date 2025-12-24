//
//  WidgetUpdateCoordinator.swift
//  Shlf
//
//  Created by Claude Code on 24/12/2025.
//

import Foundation
import SwiftData

/// iOS 26 optimized widget update coordinator with debouncing
/// Prevents excessive widget reloads that drain battery
final class WidgetUpdateCoordinator {
    static let shared = WidgetUpdateCoordinator()

    private var pendingUpdate: Task<Void, Never>?
    private let debounceInterval: Duration = .seconds(2)
    private let queue = DispatchQueue(label: "com.shlf.widgetUpdates", qos: .utility)

    private init() {}

    /// Schedule a debounced widget update
    /// Multiple rapid calls will coalesce into a single update
    /// - Parameter modelContext: SwiftData context to export
    func scheduleUpdate(modelContext: ModelContext) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Cancel any pending update
            self.pendingUpdate?.cancel()

            // Schedule new update after debounce interval
            self.pendingUpdate = Task { @MainActor in
                do {
                    try await Task.sleep(for: self.debounceInterval)

                    // Only execute if not cancelled
                    guard !Task.isCancelled else { return }

                    // Perform the actual widget update
                    WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                } catch {
                    // Task was cancelled or sleep failed - ignore
                }
            }
        }
    }

    /// Force immediate widget update (bypass debouncing)
    /// Use sparingly - only for critical updates like session completion
    /// - Parameter modelContext: SwiftData context to export
    func forceUpdate(modelContext: ModelContext) {
        queue.async { [weak self] in
            self?.pendingUpdate?.cancel()
            Task { @MainActor in
                WidgetDataExporter.exportSnapshot(modelContext: modelContext)
            }
        }
    }

    /// Cancel any pending updates
    func cancelPendingUpdates() {
        queue.async { [weak self] in
            self?.pendingUpdate?.cancel()
            self?.pendingUpdate = nil
        }
    }
}
