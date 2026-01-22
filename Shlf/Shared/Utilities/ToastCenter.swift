//
//  ToastCenter.swift
//  Shlf
//
//  Created by Codex on 19/01/2026.
//

import SwiftUI
import Combine
#if canImport(UserNotifications)
import UserNotifications
#endif

@MainActor
final class ToastCenter: ObservableObject {
    @Published private(set) var toast: ToastData?

    private var showTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var queue: [ToastData] = []
    private var scenePhase: ScenePhase = .active
    private var didRequestNotificationAuth = false

    func updateScenePhase(_ phase: ScenePhase) {
        scenePhase = phase
    }

    func show(_ toast: ToastData, delay: TimeInterval = 0) {
        if delay > 0 {
            showTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.enqueue(toast)
            }
        } else {
            enqueue(toast)
        }
    }

    func dismiss() {
        showTask?.cancel()
        dismissTask?.cancel()
        toast = nil
        showNextIfNeeded()
    }

    private func enqueue(_ toast: ToastData) {
        if shouldSendNotification(for: toast) {
            sendNotificationIfNeeded(for: toast)
            return
        }

        if self.toast == nil {
            present(toast)
        } else {
            queue.append(toast)
        }
    }

    private func present(_ toast: ToastData) {
        self.toast = toast
        performHaptic(for: toast.haptic)
        scheduleDismiss(for: toast)
    }

    private func scheduleDismiss(for toast: ToastData) {
        guard toast.duration > 0 else { return }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            guard let self else { return }
            if self.toast?.id == toast.id {
                self.toast = nil
                self.showNextIfNeeded()
            }
        }
    }

    private func showNextIfNeeded() {
        guard toast == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        present(next)
    }

    private func performHaptic(for haptic: ToastHaptic?) {
        switch haptic {
        case .selection:
            Haptics.selection()
        case .light:
            Haptics.impact(.light)
        case .medium:
            Haptics.impact(.medium)
        case .none:
            break
        }
    }

    private func shouldSendNotification(for toast: ToastData) -> Bool {
        guard toast.notification != nil else { return false }
        return scenePhase != .active
    }

    private func sendNotificationIfNeeded(for toast: ToastData) {
        guard let notification = toast.notification else { return }
#if canImport(UserNotifications)
        Task {
            guard await ensureNotificationAuthorization() else { return }
            let content = UNMutableNotificationContent()
            content.title = notification.title
            if let body = notification.body {
                content.body = body
            }
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: notification.identifier ?? UUID().uuidString,
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
#endif
    }

    private func ensureNotificationAuthorization() async -> Bool {
#if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        if !didRequestNotificationAuth {
            didRequestNotificationAuth = true
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            return granted
        }
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
#else
        return false
#endif
    }
}

struct ToastNotificationData {
    let title: String
    let body: String?
    let identifier: String?

    init(title: String, body: String? = nil, identifier: String? = nil) {
        self.title = title
        self.body = body
        self.identifier = identifier
    }
}

struct ToastData: Identifiable {
    let id = UUID()
    let title: String
    let style: ToastStyle
    let tint: Color?
    let duration: TimeInterval
    let haptic: ToastHaptic?
    let notification: ToastNotificationData?

    static func sessionLogged(tint: Color?) -> ToastData {
        ToastData(
            title: String(localized: "Session logged"),
            style: .successCheck,
            tint: tint,
            duration: 3,
            haptic: .light,
            notification: nil
        )
    }

    static func achievementUnlocked(title: String, tint: Color?) -> ToastData {
        ToastData(
            title: title,
            style: .successCheck,
            tint: tint,
            duration: 3,
            haptic: .medium,
            notification: nil
        )
    }
}

enum ToastStyle {
    case successCheck
}

enum ToastHaptic {
    case selection
    case light
    case medium
}
