//
//  WatchSettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 28/11/2025.
//

import SwiftUI
import WatchConnectivity
import Combine
import SwiftData

struct WatchSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query private var profiles: [UserProfile]
    @StateObject private var connectionObserver = WatchConnectionObserver()
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    private var profile: UserProfile? {
        profiles.first
    }

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
        ZStack(alignment: .top) {
            // Dynamic gradient background
            LinearGradient(
                colors: [
                    (profile?.themeColor.color ?? Theme.Colors.accent).opacity(0.12),
                    (profile?.themeColor.color ?? Theme.Colors.accent).opacity(0.04),
                    Theme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // About Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "applewatch")
                                .font(.caption)
                                .foregroundStyle(profile?.themeColor.color ?? Theme.Colors.accent)
                                .frame(width: 16)

                            Text("WatchSettings.AboutTitle")
                                .font(.headline)
                        }

                        Text("WatchSettings.AboutDescription")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Connection Status Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.caption)
                                .foregroundStyle(profile?.themeColor.color ?? Theme.Colors.accent)
                                .frame(width: 16)

                            Text("WatchSettings.ConnectionStatusTitle")
                                .font(.headline)
                        }

                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: isWatchPaired ? "applewatch" : "applewatch.slash")
                                    .foregroundStyle(isWatchPaired ? Theme.Colors.accent : Theme.Colors.tertiaryText)
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("WatchSettings.Connection.AppleWatch")
                                        .font(.subheadline)

                                    Text(isWatchPaired ? "WatchSettings.Connection.Paired" : "WatchSettings.Connection.NotPaired")
                                        .font(.caption)
                                        .foregroundStyle(isWatchPaired ? Theme.Colors.success : Theme.Colors.tertiaryText)
                                }

                                Spacer()

                                if isWatchPaired {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.Colors.success)
                                }
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            if isWatchPaired {
                                HStack {
                                    Image(systemName: isWatchAppInstalled ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                                        .foregroundStyle(isWatchAppInstalled ? Theme.Colors.accent : Theme.Colors.tertiaryText)
                                        .font(.title2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("WatchSettings.Connection.WatchApp")
                                            .font(.subheadline)

                                        Text(isWatchAppInstalled ? "WatchSettings.Connection.Installed" : "WatchSettings.Connection.NotInstalled")
                                            .font(.caption)
                                            .foregroundStyle(isWatchAppInstalled ? Theme.Colors.success : Theme.Colors.tertiaryText)
                                    }

                                    Spacer()

                                    if isWatchAppInstalled {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.Colors.success)
                                    }
                                }
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                HStack {
                                    Image(systemName: isWatchReachable ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                        .foregroundStyle(isWatchReachable ? Theme.Colors.accent : Theme.Colors.tertiaryText)
                                        .font(.title2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("WatchSettings.Connection.RealTimeSync")
                                            .font(.subheadline)

                                        Text(isWatchReachable ? "WatchSettings.Connection.Connected" : "WatchSettings.Connection.NotConnected")
                                            .font(.caption)
                                            .foregroundStyle(isWatchReachable ? Theme.Colors.success : Theme.Colors.tertiaryText)
                                    }

                                    Spacer()

                                    if isWatchReachable {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.Colors.success)
                                    }
                                }
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            if !isWatchPaired || !isWatchAppInstalled {
                                Text(!isWatchPaired ?
                                    "WatchSettings.Connection.PairPrompt" :
                                    "WatchSettings.Connection.InstallPrompt")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Progress Display Section
                    if let profile = profile, isWatchAppInstalled {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.caption)
                                    .foregroundStyle(profile.themeColor.color)
                                    .frame(width: 16)

                                Text("WatchSettings.ProgressDisplay.Title")
                                    .font(.headline)
                            }

                            VStack(spacing: 10) {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        profile.useCircularProgressWatch = false
                                        do {
                                            try modelContext.save()
                                            WatchConnectivityManager.shared.sendProfileSettingsToWatch(profile)
                                        } catch {
                                            saveErrorMessage = String.localizedStringWithFormat(
                                                localized("WatchSettings.SaveErrorFormat", locale: locale),
                                                error.localizedDescription
                                            )
                                            showSaveError = true
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "minus")
                                            .font(.title3)
                                            .foregroundStyle(profile.themeColor.color)
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("WatchSettings.ProgressDisplay.BarTitle")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)

                                            Text("WatchSettings.ProgressDisplay.BarDescription")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if !profile.useCircularProgressWatch {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(profile.themeColor.color)
                                        }
                                    }
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                !profile.useCircularProgressWatch ? profile.themeColor.color : .clear,
                                                lineWidth: 2
                                            )
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        profile.useCircularProgressWatch = true
                                        do {
                                            try modelContext.save()
                                            WatchConnectivityManager.shared.sendProfileSettingsToWatch(profile)
                                        } catch {
                                            saveErrorMessage = String.localizedStringWithFormat(
                                                localized("WatchSettings.SaveErrorFormat", locale: locale),
                                                error.localizedDescription
                                            )
                                            showSaveError = true
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "circle")
                                            .font(.title3)
                                            .foregroundStyle(profile.themeColor.color)
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("WatchSettings.ProgressDisplay.RingTitle")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)

                                            Text("WatchSettings.ProgressDisplay.RingDescription")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if profile.useCircularProgressWatch {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(profile.themeColor.color)
                                        }
                                    }
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                profile.useCircularProgressWatch ? profile.themeColor.color : .clear,
                                                lineWidth: 2
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Session Display Section
                    if let profile = profile, isWatchAppInstalled {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "eye")
                                    .font(.caption)
                                    .foregroundStyle(profile.themeColor.color)
                                    .frame(width: 16)

                                Text("WatchSettings.SessionDisplay.Title")
                                    .font(.headline)
                            }

                            VStack(spacing: 12) {
                                Toggle(isOn: Binding(
                                    get: { profile.hideAutoSessionsWatch },
                                    set: { newValue in
                                        profile.hideAutoSessionsWatch = newValue
                                        do {
                                            try modelContext.save()
                                            WatchConnectivityManager.shared.sendProfileSettingsToWatch(profile)
                                        } catch {
                                            saveErrorMessage = String.localizedStringWithFormat(
                                                localized("WatchSettings.SaveErrorFormat", locale: locale),
                                                error.localizedDescription
                                            )
                                            showSaveError = true
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("WatchSettings.SessionDisplay.HideQuick")
                                            .font(.subheadline)
                                        Text("WatchSettings.SessionDisplay.HideQuickDetail")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .tint(profile.themeColor.color)
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Text("WatchSettings.SessionDisplay.Footer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Watch Features Section
                    if let profile = profile, isWatchAppInstalled {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(profile.themeColor.color)
                                    .frame(width: 16)

                                Text("WatchSettings.Features.Title")
                                    .font(.headline)
                            }

                            VStack(spacing: 12) {
                                Toggle(isOn: Binding(
                                    get: { profile.enableWatchPositionMarking },
                                    set: { newValue in
                                        profile.enableWatchPositionMarking = newValue
                                        do {
                                            try modelContext.save()
                                            WatchConnectivityManager.shared.sendProfileSettingsToWatch(profile)
                                        } catch {
                                            saveErrorMessage = String.localizedStringWithFormat(
                                                localized("WatchSettings.SaveErrorFormat", locale: locale),
                                                error.localizedDescription
                                            )
                                            showSaveError = true
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("WatchSettings.Features.MarkPosition")
                                            .font(.subheadline)
                                        Text("WatchSettings.Features.MarkPositionDetail")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .tint(profile.themeColor.color)
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Watch App UI Section
                    if let profile = profile, isWatchAppInstalled {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "gearshape.fill")
                                    .font(.caption)
                                    .foregroundStyle(profile.themeColor.color)
                                    .frame(width: 16)

                                Text("WatchSettings.AppUI.Title")
                                    .font(.headline)
                            }

                            VStack(spacing: 12) {
                                Toggle(isOn: Binding(
                                    get: { profile.showSettingsOnWatch },
                                    set: { newValue in
                                        profile.showSettingsOnWatch = newValue
                                        do {
                                            try modelContext.save()
                                            WatchConnectivityManager.shared.sendProfileSettingsToWatch(profile)
                                        } catch {
                                            saveErrorMessage = String.localizedStringWithFormat(
                                                localized("WatchSettings.SaveErrorFormat", locale: locale),
                                                error.localizedDescription
                                            )
                                            showSaveError = true
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("WatchSettings.AppUI.ShowSettings")
                                            .font(.subheadline)
                                        Text("WatchSettings.AppUI.ShowSettingsDetail")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .tint(profile.themeColor.color)
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // About Watch App Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(profile?.themeColor.color ?? Theme.Colors.accent)
                                .frame(width: 16)

                            Text("WatchSettings.AboutApp.Title")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("WatchSettings.AboutApp.Heading")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            VStack(alignment: .leading, spacing: 6) {
                                Label("WatchSettings.AboutApp.Feature.ProgressButtons", systemImage: "plus.circle.fill")
                                Label("WatchSettings.AboutApp.Feature.TrackBooks", systemImage: "book.fill")
                                Label("WatchSettings.AboutApp.Feature.InstantSync", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("WatchSettings.Title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("WatchSettings.SaveErrorTitle", isPresented: $showSaveError) {
            Button("Common.OK") {}
        } message: {
            Text(saveErrorMessage)
        }
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
