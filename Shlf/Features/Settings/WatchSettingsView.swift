//
//  WatchSettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 28/11/2025.
//

import SwiftUI
import WatchConnectivity
import Combine

struct WatchSettingsView: View {
    @StateObject private var connectionObserver = WatchConnectionObserver()

    private var isWatchPaired: Bool {
        connectionObserver.isPaired
    }

    private var isWatchAppInstalled: Bool {
        connectionObserver.isWatchAppInstalled
    }

    private var isWatchReachable: Bool {
        connectionObserver.isReachable
    }

    var body: some View {
        Form {
            Section("Connection Status") {
                HStack {
                    Image(systemName: isWatchPaired ? "applewatch" : "applewatch.slash")
                        .foregroundStyle(isWatchPaired ? Theme.Colors.accent : Theme.Colors.tertiaryText)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Watch")
                            .font(Theme.Typography.body)

                        Text(isWatchPaired ? "Paired" : "Not Paired")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(isWatchPaired ? Theme.Colors.success : Theme.Colors.tertiaryText)
                    }

                    Spacer()

                    if isWatchPaired {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.success)
                    }
                }

                if isWatchPaired {
                    HStack {
                        Image(systemName: isWatchAppInstalled ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                            .foregroundStyle(isWatchAppInstalled ? Theme.Colors.accent : Theme.Colors.tertiaryText)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Watch App")
                                .font(Theme.Typography.body)

                            Text(isWatchAppInstalled ? "Installed" : "Not Installed")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(isWatchAppInstalled ? Theme.Colors.success : Theme.Colors.tertiaryText)
                        }

                        Spacer()

                        if isWatchAppInstalled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.success)
                        }
                    }

                    HStack {
                        Image(systemName: isWatchReachable ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundStyle(isWatchReachable ? Theme.Colors.accent : Theme.Colors.tertiaryText)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Real-Time Sync")
                                .font(Theme.Typography.body)

                            Text(isWatchReachable ? "Connected" : "Not Connected")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(isWatchReachable ? Theme.Colors.success : Theme.Colors.tertiaryText)
                        }

                        Spacer()

                        if isWatchReachable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.success)
                        }
                    }
                }
            }

            if !isWatchPaired || !isWatchAppInstalled {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if !isWatchPaired {
                            Label("Pair your Apple Watch with your iPhone to use Shlf on your wrist.", systemImage: "applewatch")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        } else if !isWatchAppInstalled {
                            Label("Install Shlf on your Apple Watch to track reading progress on the go.", systemImage: "square.and.arrow.down")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                }
            }

            Section("About Watch App") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The Shlf Watch app lets you:")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Update reading progress with quick +1 or +5 buttons", systemImage: "plus.circle.fill")
                        Label("Track currently reading books", systemImage: "book.fill")
                        Label("Sync instantly with your iPhone", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
        }
        .navigationTitle("Apple Watch")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
class WatchConnectionObserver: ObservableObject {
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false
    @Published var isReachable = false

    private var cancellable: AnyCancellable?

    init() {
        updateStatus()

        // Listen for real-time reachability changes
        cancellable = NotificationCenter.default.publisher(for: .watchReachabilityDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateStatus()
                }
            }
    }

    deinit {
        cancellable?.cancel()
    }

    private func updateStatus() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
    }
}

#Preview {
    NavigationStack {
        WatchSettingsView()
    }
}
