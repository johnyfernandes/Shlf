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
    @Environment(\.locale) private var locale
    @Bindable var profile: UserProfile
    @Query(sort: [SortDescriptor(\StreakEvent.date, order: .reverse)]) private var events: [StreakEvent]
    @Query private var sessions: [ReadingSession]

    @State private var historyFilter: StreakHistoryFilter = .last90Days
    @State private var showUpgradeSheet = false
    @State private var showPardonConfirm = false
    @State private var isApplyingPardon = false
    @State private var pardonError: LocalizedStringKey?

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
            .navigationTitle("Streak.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Common.Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeColor.color)
                }
            }
            .alert("Streak.Protection.Title", isPresented: Binding(
                get: { pardonError != nil },
                set: { _ in pardonError = nil }
            )) {
                Button("Common.OK") {}
            } message: {
                Text(pardonError ?? "Common.Error.Generic")
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
                            String(localized: "Streak.LongestChain %lld"),
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
                    Text("Streak.Status.ActiveToday")
                        .font(Theme.Typography.callout)
                    if let deadline = streakDeadline {
                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "Streak.Status.KeepGoingBy %@"),
                                formatTime(deadline)
                            )
                        )
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                case 1:
                    Text("Streak.Status.AtRisk")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.warning)
                    if let deadline = streakDeadline {
                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "Streak.Status.ReadByToKeep %@"),
                                formatTime(deadline)
                            )
                        )
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                default:
                    Text("Streak.Status.Lost")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.error)
                    if let missedDay = missedDayDate {
                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "Streak.Status.MissedOn %@"),
                                formatDate(missedDay)
                            )
                        )
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            } else {
                Text("Streak.Status.StartFirst")
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
                    Text("Streak.Protection.Title")
                        .font(Theme.Typography.headline)
                }

                if !isProUser {
                    Text("Streak.Protection.Upsell")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    Button("Common.UpgradeToPro") {
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
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "Streak.Protection.MissedOn %@"),
                        formatDate(missedDay)
                    )
                )
                    .font(Theme.Typography.callout)
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "Streak.Protection.AvailableUntil %@"),
                        formatTime(deadline)
                    )
                )
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Button {
                    showPardonConfirm = true
                } label: {
                    if isApplyingPardon {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Streak.Protection.UsePardon")
                    }
                }
                .primaryButton(color: themeColor.color, foreground: themeColor.onColor(for: colorScheme))
                .disabled(isApplyingPardon)
                .confirmationDialog("Streak.Protection.ConfirmTitle", isPresented: $showPardonConfirm, titleVisibility: .visible) {
                    Button("Streak.Protection.UsePardon") {
                        applyPardon()
                    }
                    Button("Common.Cancel", role: .cancel) {}
                } message: {
                    Text(pardonConfirmMessage)
                }
            case .cooldown(let nextAvailable):
                Text("Streak.Protection.Cooldown")
                    .font(Theme.Typography.callout)
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "Streak.Protection.NextAvailable %@"),
                        formatDate(nextAvailable)
                    )
                )
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            case .expired(let missedDay):
                Text("Streak.Protection.Expired")
                    .font(Theme.Typography.callout)
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "Streak.Protection.MissedOn %@"),
                        formatDate(missedDay)
                    )
                )
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            case .notNeeded:
                Text("Streak.Protection.NoMissedDay")
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
                    Text("Streak.History.Title")
                        .font(Theme.Typography.headline)
                }

                if isProUser {
                    Picker("Streak.History.Title", selection: $historyFilter) {
                        ForEach(StreakHistoryFilter.allCases, id: \.self) { filter in
                            Text(filter.titleKey).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filteredEvents.isEmpty {
                        Text("Streak.History.Empty")
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
                    Text("Streak.History.ProOnly")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    Button("Common.UpgradeToPro") {
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

                        Text(verbatim: isToday ? localized("Streak.Today", locale: locale) : shortWeekdayLabel(for: date))
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
        formatter.locale = locale
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

    private var pardonConfirmMessage: LocalizedStringKey {
        switch pardonEligibility {
        case .available(let missedDay, let deadline):
            return "Streak.Protection.ConfirmMessage \(formatDate(missedDay)) \(formatTime(deadline))"
        default:
            return "Streak.Protection.ConfirmMessage.Generic"
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
                pardonError = pardonErrorMessage(for: eligibility)
            } else {
                pardonError = "Streak.Protection.ApplyFailed"
            }
            isApplyingPardon = false
        }
    }

    private func pardonErrorMessage(for eligibility: StreakPardonEligibility) -> LocalizedStringKey {
        switch eligibility {
        case .cooldown(let nextAvailable):
            return "Streak.Protection.AvailableAgain \(formatTime(nextAvailable))"
        case .expired(let missedDay):
            return "Streak.Protection.ExpiredFor \(formatDate(missedDay))"
        case .notNeeded:
            return "Streak.Protection.NoMissedDay"
        case .available:
            return ""
        }
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }
}

private enum StreakHistoryFilter: CaseIterable {
    case last90Days
    case all

    var titleKey: LocalizedStringKey {
        switch self {
        case .last90Days: return "Streak.History.90Days"
        case .all: return "Common.All"
        }
    }
}

private struct StreakEventRow: View {
    @Environment(\.locale) private var locale
    let event: StreakEvent
    let pagesRead: Int?

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: event.iconName)
                .foregroundStyle(event.iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: event))
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.text)
                if let subtitle = subtitle(for: event) {
                    Text(verbatim: subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                if let pagesRead {
                    let pagesFormat = localized("Streak.Event.PagesRead %lld", locale: locale)
                    Text(String(format: pagesFormat, locale: locale, arguments: [pagesRead]))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.Colors.secondaryText)
                }
            }

            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func title(for event: StreakEvent) -> LocalizedStringKey {
        switch event.type {
        case .day:
            return "Streak.Event.Day"
        case .saved:
            return "Streak.Event.Saved"
        case .lost:
            return "Streak.Event.Lost"
        case .started:
            return "Streak.Event.Started"
        }
    }

    private func subtitle(for event: StreakEvent) -> String? {
        let dateText = event.date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        )
        switch event.type {
        case .day:
            if event.streakLength > 0 {
                let detailFormat = localized("Streak.Event.DayDetail %1$@ %2$lld", locale: locale)
                return String(format: detailFormat, locale: locale, arguments: [dateText, event.streakLength])
            }
            return dateText
        case .saved, .lost:
            let detailFormat = localized("Streak.Event.LengthDetail %1$@ %2$lld", locale: locale)
            return String(format: detailFormat, locale: locale, arguments: [dateText, event.streakLength])
        case .started:
            return dateText
        }
    }
}

private extension StreakEvent {
    var title: String {
        switch type {
        case .day:
            return String(localized: "Streak.Event.Day")
        case .saved:
            return String(localized: "Streak.Event.Saved")
        case .lost:
            return String(localized: "Streak.Event.Lost")
        case .started:
            return String(localized: "Streak.Event.Started")
        }
    }

    var subtitle: String? {
        let dateText = date.formatted(date: .abbreviated, time: .omitted)
        switch type {
        case .day:
            if streakLength > 0 {
                return String(
                    format: String(localized: "Streak.Event.DayDetail %1$@ %2$lld"),
                    locale: .current,
                    arguments: [dateText, streakLength]
                )
            }
            return dateText
        case .saved:
            return String(
                format: String(localized: "Streak.Event.LengthDetail %1$@ %2$lld"),
                locale: .current,
                arguments: [dateText, streakLength]
            )
        case .lost:
            return String(
                format: String(localized: "Streak.Event.LengthDetail %1$@ %2$lld"),
                locale: .current,
                arguments: [dateText, streakLength]
            )
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
