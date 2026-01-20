//
//  ToastCenter.swift
//  Shlf
//
//  Created by Codex on 19/01/2026.
//

import SwiftUI
import Combine

@MainActor
final class ToastCenter: ObservableObject {
    @Published private(set) var toast: ToastData?

    private var showTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?

    func show(_ toast: ToastData, delay: TimeInterval = 0) {
        showTask?.cancel()
        dismissTask?.cancel()

        if delay > 0 {
            showTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.present(toast)
            }
        } else {
            present(toast)
        }
    }

    func dismiss() {
        showTask?.cancel()
        dismissTask?.cancel()
        toast = nil
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
            }
        }
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
}

struct ToastData: Identifiable {
    let id = UUID()
    let titleKey: String
    let style: ToastStyle
    let tint: Color?
    let duration: TimeInterval
    let haptic: ToastHaptic?

    static func sessionLogged(tint: Color?) -> ToastData {
        ToastData(
            titleKey: "Session logged",
            style: .successCheck,
            tint: tint,
            duration: 3,
            haptic: .light
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
