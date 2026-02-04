//
//  BookStatDetailView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct BookStatDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale
    let stat: BookStatsCardType
    let book: Book
    let summary: BookStatsSummary
    let rangeLabel: String
    let onPrimaryAction: (() -> Void)?

    private var accent: Color {
        stat.accent.color(themeColor: themeColor)
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
                    VStack(spacing: 16) {
                        headerCard
                        valueCard

                        if !summary.sessions.isEmpty {
                            chartCard
                            sessionsCard
                        } else {
                            emptyCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(stat.titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeColor.color)
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: stat.icon)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(stat.titleKey)
                    .font(.headline)

                Text(rangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var valueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailValueText()
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Colors.text)

            Text(stat.descriptionKey)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(themeColor.color.opacity(0.06), lineWidth: 1)
        )
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("Activity", locale: locale))
                .font(.headline)

            ReadingActivityChart(sessions: summary.sessions)
                .frame(height: 180)
                .padding(.top, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(themeColor.color.opacity(0.06), lineWidth: 1)
        )
    }

    private var sessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Recent Sessions", locale: locale))
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(summary.sessions.prefix(4)) { session in
                    ReadingSessionRow(session: session)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(themeColor.color.opacity(0.06), lineWidth: 1)
        )
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            InlineEmptyStateView(
                icon: "chart.bar.xaxis",
                title: LocalizedStringKey(localized("No activity yet", locale: locale)),
                message: LocalizedStringKey(localized("Log your first session to unlock detailed stats for this book.", locale: locale)),
                actionTitle: onPrimaryAction == nil ? nil : LocalizedStringKey(localized("Log session", locale: locale))
            ) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onPrimaryAction?()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(themeColor.color.opacity(0.06), lineWidth: 1)
        )
    }

    private func detailValueText() -> Text {
        switch stat {
        case .pagesPercent:
            let unit = unitText(
                value: summary.totalPagesRead,
                singularKey: "page",
                pluralKey: "pages"
            )
            let base = "\(formatNumber(summary.totalPagesRead)) \(unit)"
            var attributed = AttributedString(base)
            if let percent = summary.percentRead {
                var percentText = AttributedString(" \(percent)%")
                percentText.foregroundColor = UIColor(accent)
                attributed += percentText
            }
            return Text(attributed)
        case .timeRead:
            return Text(formatMinutes(summary.totalMinutesRead))
                .foregroundStyle(accent)
        case .sessionCount:
            return Text(
                "\(formatNumber(summary.sessionCount)) \(unitText(value: summary.sessionCount, singularKey: "session", pluralKey: "sessions"))"
            )
            .foregroundStyle(accent)
        case .averagePages:
            return Text("\(formatNumber(summary.averagePagesPerSession)) \(localized("pages/session", locale: locale))")
                .foregroundStyle(accent)
        case .averageSpeed:
            return Text("\(formatNumber(summary.averagePagesPerHour)) \(localized("pages/hour", locale: locale))")
                .foregroundStyle(accent)
        case .longestSession:
            if summary.longestSessionMinutes > 0 {
                return Text(formatMinutes(summary.longestSessionMinutes))
                    .foregroundStyle(accent)
            }
            return Text(
                "\(formatNumber(summary.longestSessionPages)) \(unitText(value: summary.longestSessionPages, singularKey: "page", pluralKey: "pages"))"
            )
                .foregroundStyle(accent)
        case .streak:
            return Text(
                "\(formatNumber(summary.streakDays)) \(unitText(value: summary.streakDays, singularKey: "day", pluralKey: "days"))"
            )
                .foregroundStyle(accent)
        case .daysSinceLast:
            if let lastReadDate = summary.lastReadDate {
                let relative = relativeTimeString(from: lastReadDate, locale: locale)
                return Text(relative)
                    .foregroundStyle(accent)
            }
            return Text(localized("No reads yet", locale: locale))
                .foregroundStyle(accent)
        case .firstLastDate:
            if let first = summary.firstReadDate, let last = summary.lastReadDate {
                return Text(verbatim: "\(formatDate(first)) – \(formatDate(last))")
                    .foregroundStyle(accent)
            }
            return Text(localized("No dates yet", locale: locale))
                .foregroundStyle(accent)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return String.localizedStringWithFormat(String(localized: "%lldh"), hours)
            }
            return String.localizedStringWithFormat(String(localized: "%lldh %lldm"), hours, mins)
        }
        return String.localizedStringWithFormat(String(localized: "%lldm"), minutes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func relativeTimeString(from date: Date, locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        let elapsedSeconds = max(1, Int(Date().timeIntervalSince(date)))
        return formatter.localizedString(fromTimeInterval: -Double(elapsedSeconds))
    }

    private func unitText(value: Int, singularKey: String, pluralKey: String) -> String {
        value == 1
        ? localized(singularKey, locale: locale)
        : localized(pluralKey, locale: locale)
    }

    private func formatNumber(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
