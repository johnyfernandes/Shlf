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
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            ReadingActivityChart(sessions: summary.sessions)
                .frame(height: 180)
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
            Text("Recent Sessions")
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
                title: "No activity yet",
                message: "Log your first session to unlock detailed stats for this book.",
                actionTitle: onPrimaryAction == nil ? nil : "Log session"
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
            let percent = summary.percentRead.map { " \($0)%" } ?? ""
            return Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld pages"),
                    summary.totalPagesRead
                )
            ) + Text(verbatim: percent)
                .foregroundStyle(accent)
        case .timeRead:
            return Text(formatMinutes(summary.totalMinutesRead))
                .foregroundStyle(accent)
        case .sessionCount:
            return Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld sessions"),
                    summary.sessionCount
                )
            )
            .foregroundStyle(accent)
        case .averagePages:
            return (
                Text(formatNumber(summary.averagePagesPerSession))
                + Text(verbatim: " ")
                + Text("pages/session")
            )
            .foregroundStyle(accent)
        case .averageSpeed:
            return (
                Text(formatNumber(summary.averagePagesPerHour))
                + Text(verbatim: " ")
                + Text("pages/hour")
            )
            .foregroundStyle(accent)
        case .longestSession:
            if summary.longestSessionMinutes > 0 {
                return Text(formatMinutes(summary.longestSessionMinutes))
                    .foregroundStyle(accent)
            }
            return Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld pages"),
                    summary.longestSessionPages
                )
            )
                .foregroundStyle(accent)
        case .streak:
            return Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld days"),
                    summary.streakDays
                )
            )
                .foregroundStyle(accent)
        case .daysSinceLast:
            if let value = summary.daysSinceLastRead {
                return Text(
                    String.localizedStringWithFormat(
                        String(localized: "%lld days"),
                        value
                    )
                )
                    .foregroundStyle(accent)
            }
            return Text("No reads yet")
                .foregroundStyle(accent)
        case .firstLastDate:
            if let first = summary.firstReadDate, let last = summary.lastReadDate {
                return Text(verbatim: "\(formatDate(first)) – \(formatDate(last))")
                    .foregroundStyle(accent)
            }
            return Text("No dates yet")
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
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
