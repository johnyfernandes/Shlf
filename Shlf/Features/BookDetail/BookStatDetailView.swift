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
                    Button("Common.Done") {
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
            Text("BookStatDetail.Activity")
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
            Text("BookStatDetail.RecentSessions")
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
                title: "BookStatDetail.Empty.Title",
                message: "BookStatDetail.Empty.Message",
                actionTitle: onPrimaryAction == nil ? nil : "BookStatDetail.Empty.Action"
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
                singularKey: "BookDetail.Stats.PageSingular",
                pluralKey: "BookDetail.Stats.PagePlural"
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
                "\(formatNumber(summary.sessionCount)) \(unitText(value: summary.sessionCount, singularKey: "BookDetail.Stats.SessionSingular", pluralKey: "BookDetail.Stats.SessionPlural"))"
            )
            .foregroundStyle(accent)
        case .averagePages:
            return Text("\(formatNumber(summary.averagePagesPerSession)) \(localized("BookStatDetail.PagesPerSession", locale: locale))")
                .foregroundStyle(accent)
        case .averageSpeed:
            return Text("\(formatNumber(summary.averagePagesPerHour)) \(localized("BookStatDetail.PagesPerHour", locale: locale))")
                .foregroundStyle(accent)
        case .longestSession:
            if summary.longestSessionMinutes > 0 {
                return Text(formatMinutes(summary.longestSessionMinutes))
                    .foregroundStyle(accent)
            }
            return Text(
                "\(formatNumber(summary.longestSessionPages)) \(unitText(value: summary.longestSessionPages, singularKey: "BookDetail.Stats.PageSingular", pluralKey: "BookDetail.Stats.PagePlural"))"
            )
                .foregroundStyle(accent)
        case .streak:
            return Text(
                "\(formatNumber(summary.streakDays)) \(unitText(value: summary.streakDays, singularKey: "BookDetail.Stats.DaySingular", pluralKey: "BookDetail.Stats.DayPlural"))"
            )
                .foregroundStyle(accent)
        case .daysSinceLast:
            if let lastReadDate = summary.lastReadDate {
                let relative = relativeTimeString(from: lastReadDate, locale: locale)
                return Text(relative)
                    .foregroundStyle(accent)
            }
            return Text(verbatim: localized("BookDetail.Stats.NoReadsYet", locale: locale))
                .foregroundStyle(accent)
        case .firstLastDate:
            if let first = summary.firstReadDate, let last = summary.lastReadDate {
                return Text(verbatim: "\(formatDate(first)) – \(formatDate(last))")
                    .foregroundStyle(accent)
            }
            return Text(verbatim: localized("BookStatDetail.NoDatesYet", locale: locale))
                .foregroundStyle(accent)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return String.localizedStringWithFormat(localized("BookDetail.Duration.HoursShortFormat %lld", locale: locale), hours)
            }
            return String.localizedStringWithFormat(
                localized("BookDetail.Duration.HoursMinutesShortFormat %lld %lld", locale: locale),
                hours,
                mins
            )
        }
        return String.localizedStringWithFormat(localized("BookDetail.Duration.MinutesShortFormat %lld", locale: locale), minutes)
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
