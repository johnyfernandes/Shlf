//
//  StreakDetailView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct StreakDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    @Query(sort: [SortDescriptor(\StreakEvent.date, order: .reverse)]) private var events: [StreakEvent]

    @State private var historyFilter: StreakHistoryFilter = .last90Days
    @State private var showUpgradeSheet = false
    @State private var showPardonConfirm = false
    @State private var isApplyingPardon = false
    @State private var pardonError: String?

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
    }

    private var streakService: StreakService {
        StreakService(modelContext: modelContext)
    }

    private var streakDeadline: Date? {
        streakService.streakDeadline(for: profile)
    }

    private var pardonEligibility: StreakPardonEligibility {
        streakService.pardonEligibility(for: profile)
    }

    private var daysSinceLastStreakDay: Int? {
        guard let lastDay = profile.lastReadingDate else { return nil }
        let calendar = Calendar.current
        let lastStart = calendar.startOfDay(for: lastDay)
        let todayStart = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: lastStart, to: todayStart).day
    }

    private var filteredEvents: [StreakEvent] {
        let cutoff: Date? = historyFilter == .last90Days
            ? Calendar.current.date(byAdding: .day, value: -90, to: Date())
            : nil
        return events.filter { event in
            guard let cutoff else { return true }
            return event.date >= cutoff
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        themeColor.color.opacity(0.12),
                        themeColor.color.opacity(0.04),
                        Theme.Colors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        streakSummaryCard
                        streakProtectionCard
                        streakHistoryCard
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeColor.color)
                }
            }
            .confirmationDialog("Use Streak Protection?", isPresented: $showPardonConfirm, titleVisibility: .visible) {
                Button("Use Pardon") {
                    applyPardon()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(pardonConfirmMessage)
            }
            .alert("Streak Protection", isPresented: Binding(
                get: { pardonError != nil },
                set: { _ in pardonError = nil }
            )) {
                Button("OK") {}
            } message: {
                Text(pardonError ?? "Something went wrong.")
            }
            .sheet(isPresented: $showUpgradeSheet) {
                PaywallView()
            }
        }
    }

    private var streakSummaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Theme.Colors.streakGradient)
                Text("Current Streak")
                    .font(Theme.Typography.headline)
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text("\(profile.currentStreak)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.text)

                Text("days")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Longest")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Text("\(profile.longestStreak) days")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.text)
                }
            }

            streakStatusText
        }
        .padding(Theme.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var streakStatusText: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            if let daysSince = daysSinceLastStreakDay {
                switch daysSince {
                case 0:
                    Text("Streak is active today.")
                        .font(Theme.Typography.callout)
                    if let deadline = streakDeadline {
                        Text("Keep it going by \(formatTime(deadline)).")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                case 1:
                    Text("Streak is at risk.")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.warning)
                    if let deadline = streakDeadline {
                        Text("Read by \(formatTime(deadline)) to keep it.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                default:
                    Text("Streak lost.")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.error)
                    if let missedDay = missedDayDate {
                        Text("Missed \(formatDate(missedDay)).")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            } else {
                Text("Start your first streak by logging a session.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }

    private var streakProtectionCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "shield.fill")
                    .foregroundStyle(themeColor.color)
                Text("Streak Protection")
                    .font(Theme.Typography.headline)
            }

            if !isProUser {
                Text("Protect missed days with a 48-hour pardon window.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Button("Upgrade to Pro") {
                    showUpgradeSheet = true
                }
                .font(Theme.Typography.callout)
                .foregroundStyle(themeColor.color)
            } else {
                streakProtectionContent
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var streakProtectionContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            switch pardonEligibility {
            case .available(let missedDay, let deadline):
                Text("Missed \(formatDate(missedDay)).")
                    .font(Theme.Typography.callout)
                Text("Pardon available until \(formatTime(deadline)).")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Button {
                    showPardonConfirm = true
                } label: {
                    if isApplyingPardon {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Use Pardon")
                    }
                }
                .primaryButton(color: themeColor.color)
                .disabled(isApplyingPardon)
            case .cooldown(let nextAvailable):
                Text("Pardon is cooling down.")
                    .font(Theme.Typography.callout)
                Text("Next available \(formatDate(nextAvailable)).")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            case .expired(let missedDay):
                Text("Pardon window expired.")
                    .font(Theme.Typography.callout)
                Text("Missed \(formatDate(missedDay)).")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            case .notNeeded:
                Text("No missed day to pardon.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }

    private var streakHistoryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(themeColor.color)
                Text("History")
                    .font(Theme.Typography.headline)
            }

            if isProUser {
                Picker("History", selection: $historyFilter) {
                    ForEach(StreakHistoryFilter.allCases, id: \.self) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                if filteredEvents.isEmpty {
                    Text("No streak history yet.")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .padding(.top, Theme.Spacing.xs)
                } else {
                    VStack(spacing: Theme.Spacing.xs) {
                        ForEach(filteredEvents) { event in
                            StreakEventRow(event: event)
                        }
                    }
                    .padding(.top, Theme.Spacing.xs)
                }
            } else {
                Text("Streak history is available with Pro.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Button("Upgrade to Pro") {
                    showUpgradeSheet = true
                }
                .font(Theme.Typography.callout)
                .foregroundStyle(themeColor.color)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var missedDayDate: Date? {
        guard let lastDay = profile.lastReadingDate else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDay))
    }

    private var pardonConfirmMessage: String {
        switch pardonEligibility {
        case .available(let missedDay, let deadline):
            return "Restore your streak for \(formatDate(missedDay)). Available until \(formatTime(deadline))."
        default:
            return "Restore your streak with a pardon."
        }
    }

    private func applyPardon() {
        guard isProUser else {
            showUpgradeSheet = true
            return
        }

        isApplyingPardon = true
        Task { @MainActor in
            let eligibility = try? streakService.applyPardon(for: profile)
            if case .available = eligibility {
                WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
            } else if let eligibility {
                pardonError = eligibility.errorMessage
            } else {
                pardonError = "Pardon could not be applied."
            }
            isApplyingPardon = false
        }
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

private enum StreakHistoryFilter: CaseIterable {
    case last90Days
    case all

    var title: String {
        switch self {
        case .last90Days: return "90 days"
        case .all: return "All"
        }
    }
}

private struct StreakEventRow: View {
    let event: StreakEvent

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: event.iconName)
                .foregroundStyle(event.iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.text)
                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }

            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension StreakEvent {
    var title: String {
        switch type {
        case .saved:
            return "Saved streak"
        case .lost:
            return "Streak lost"
        case .started:
            return "Streak started"
        }
    }

    var subtitle: String? {
        let dateText = date.formatted(date: .abbreviated, time: .omitted)
        switch type {
        case .saved:
            return "\(dateText) • \(streakLength) days"
        case .lost:
            return "\(dateText) • \(streakLength) days"
        case .started:
            return dateText
        }
    }

    var iconName: String {
        switch type {
        case .saved:
            return "shield.fill"
        case .lost:
            return "flame.slash.fill"
        case .started:
            return "flag.fill"
        }
    }

    var iconColor: Color {
        switch type {
        case .saved:
            return Theme.Colors.success
        case .lost:
            return Theme.Colors.error
        case .started:
            return Theme.Colors.secondaryText
        }
    }
}

private extension StreakPardonEligibility {
    var errorMessage: String {
        switch self {
        case .cooldown(let nextAvailable):
            let dateText = nextAvailable.formatted(date: .abbreviated, time: .shortened)
            return "Pardon available again on \(dateText)."
        case .expired(let missedDay):
            let dateText = missedDay.formatted(date: .abbreviated, time: .omitted)
            return "Pardon window expired for \(dateText)."
        case .notNeeded:
            return "No missed day to pardon."
        case .available:
            return ""
        }
    }
}
