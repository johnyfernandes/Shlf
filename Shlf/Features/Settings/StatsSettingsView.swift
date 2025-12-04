//
//  StatsSettingsView.swift
//  Shlf
//
//  Settings for customizing stats display
//

import SwiftUI
import SwiftData

struct StatsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    private var profile: UserProfile? {
        profiles.first
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
                            Image(systemName: "chart.xyaxis.line")
                                .font(.caption)
                                .foregroundStyle(profile?.themeColor.color ?? Theme.Colors.accent)
                                .frame(width: 16)

                            Text("About")
                                .font(.headline)
                        }

                        Text("Customize how your reading statistics are displayed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Reading Activity Graph Section
                    if let profile = profile {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.caption)
                                    .foregroundStyle(profile.themeColor.color)
                                    .frame(width: 16)

                                Text("Reading Activity Graph")
                                    .font(.headline)
                            }

                            VStack(spacing: 10) {
                                ForEach(ChartType.allCases, id: \.self) { chartType in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            profile.chartType = chartType
                                            do {
                                                try modelContext.save()
                                            } catch {
                                                saveErrorMessage = "Failed to save setting: \(error.localizedDescription)"
                                                showSaveError = true
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: chartType.icon)
                                                .font(.title3)
                                                .foregroundStyle(profile.themeColor.color)
                                                .frame(width: 28)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(chartType.rawValue)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(.primary)

                                                Text(chartType.description)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if profile.chartType == chartType {
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
                                                    profile.chartType == chartType ? profile.themeColor.color : .clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
        }
    }
}

#Preview {
    NavigationStack {
        StatsSettingsView()
    }
}
