//
//  DeveloperSettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

#if DEBUG
struct DeveloperSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var storeKit = StoreKitService.shared
    @State private var showResetAlert = false
    @State private var isWorking = false

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        Form {
            Section("Purchases") {
                Button("Reload Products") {
                    Task { await storeKit.loadProducts() }
                }

                Button("Refresh Entitlements") {
                    Task { await storeKit.refreshEntitlements() }
                }

                Button("Reset Pro Status (Local)", role: .destructive) {
                    showResetAlert = true
                }
                .disabled(isWorking)
            }

            Section("Status") {
                HStack {
                    Text("StoreKit Pro")
                    Spacer()
                    Text(storeKit.isProUser ? "Yes" : "No")
                        .foregroundStyle(storeKit.isProUser ? Theme.Colors.success : Theme.Colors.secondaryText)
                }

                HStack {
                    Text("Cached Pro")
                    Spacer()
                    Text(ProAccess.cachedIsPro ? "Yes" : "No")
                        .foregroundStyle(ProAccess.cachedIsPro ? Theme.Colors.success : Theme.Colors.secondaryText)
                }

                if let profile = profile {
                    HStack {
                        Text("Profile Pro")
                        Spacer()
                        Text(profile.isProUser ? "Yes" : "No")
                            .foregroundStyle(profile.isProUser ? Theme.Colors.success : Theme.Colors.secondaryText)
                    }
                }
            }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Pro Status?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetProStatus()
            }
        } message: {
            Text("Clears local Pro flags so you can test fresh purchases.")
        }
    }

    private func resetProStatus() {
        isWorking = true
        Task { @MainActor in
            storeKit.resetLocalProState()
            if let profile = profile {
                profile.isProUser = false
                try? modelContext.save()
            }
            isWorking = false
        }
    }
}
#endif
