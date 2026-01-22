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
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var profile: UserProfile
    @Query(sort: [SortDescriptor(\StreakEvent.date, order: .reverse)]) private var events: [StreakEvent]
    @Query private var sessions: [ReadingSession]

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
            .onAppear {
                let engine = GamificationEngine(modelContext: modelContext)
                engine.refreshStreak(for: profile)
            }
        }
    }

    private var streakSummaryCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Streak.DaysInRow.Title")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.Colors.text)

                    Spacer()

                    streakCountPill
                }

                streakWeekRow

                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Theme.Colors.warning)

                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "Streak.LongestChain"),
                            profile.longestStreak
                        )
                    )
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)

                    Spacer()
                }

                streakStatusText
            }
        }
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
        cardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
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
        }
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
        cardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
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
                                StreakEventRow(
                                    event: event,
                                    pagesRead: pagesForEvent(event)
                                )
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
        }
    }

    private var streakCountPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.caption.weight(.semibold))
            Text("\(profile.currentStreak)")
                .font(.callout.weight(.semibold))
        }
        .foregroundStyle(themeColor.color)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(themeColor.color.opacity(0.16), in: Capsule())
    }

    private var statusPill: some View {
        let labelKey: LocalizedStringKey
        let tint: Color
        if let daysSince = daysSinceLastStreakDay {
            switch daysSince {
            case 0:
                labelKey = "Streak.Status.Active"
                tint = Theme.Colors.success
            case 1:
                labelKey = "Streak.Status.Risk"
                tint = Theme.Colors.warning
            default:
                labelKey = "Streak.Status.Lost"
                tint = Theme.Colors.error
            }
        } else {
            labelKey = "Streak.Status.Start"
            tint = themeColor.color
        }

        return Text(labelKey)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private var streakWeekRow: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        let readingDays = Set(
            sessions
                .filter { $0.countsTowardStats }
                .map { calendar.startOfDay(for: $0.startDate) }
        )

        return ZStack {
            Capsule()
                .fill(Theme.Colors.secondaryBackground)
                .frame(height: 3)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)

            HStack(spacing: 0) {
                ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                    let isToday = calendar.isDate(date, inSameDayAs: Date())
                    let didRead = readingDays.contains(date)
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(didRead ? themeColor.color : Theme.Colors.secondaryBackground)
                                .overlay(
                                    Circle()
                                        .strokeBorder(themeColor.color.opacity(didRead ? 0 : 0.6), lineWidth: didRead ? 0 : 1.5)
                                )
                                .frame(width: 34, height: 34)

                            if didRead {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(themeColor.onColor(for: colorScheme))
                            } else if isToday {
                                Text("?")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(themeColor.color)
                            }
                        }

                        Text(isToday ? String(localized: "Streak.Today") : shortWeekdayLabel(for: date))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func shortWeekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private func pagesForEvent(_ event: StreakEvent) -> Int? {
        guard event.type == .day else { return nil }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: event.date)
        let total = sessions
            .filter { $0.countsTowardStats && calendar.startOfDay(for: $0.startDate) == day }
            .reduce(0) { $0 + max(0, $1.pagesRead) }
        return total > 0 ? total : nil
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
    let pagesRead: Int?

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
                if let pagesRead {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "%lld pages"),
                            pagesRead
                        )
                    )
                    .font(.caption2.weight(.medium))
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
        case .day:
            return String(localized: "Streak day")
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
        case .day:
            if streakLength > 0 {
                return String.localizedStringWithFormat(
                    String(localized: "%@ • Day %lld"),
                    dateText,
                    streakLength
                )
            }
            return dateText
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
        case .day:
            return "flame.fill"
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
        case .day:
            return Theme.Colors.warning
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
