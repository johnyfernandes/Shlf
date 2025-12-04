//
//  ReadingHeatmapChart.swift
//  Shlf
//
//  GitHub-style activity heatmap for reading
//

import SwiftUI

struct ReadingHeatmapChart: View {
    @Environment(\.themeColor) private var themeColor
    let sessions: [ReadingSession]

    private let columns = 7 // Days of week
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3

    // Get last 12 weeks of data (84 days)
    private var last12WeeksData: [Date: Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var data: [Date: Int] = [:]

        // Go back 84 days (12 weeks)
        for daysAgo in 0..<84 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let pagesRead = sessions
                .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
                .reduce(0) { $0 + $1.pagesRead }

            data[dayStart] = max(0, pagesRead)
        }

        return data
    }

    // Organize data into weeks (columns)
    private var weeklyData: [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var weeks: [[Date]] = []

        // Start from 84 days ago and go forward
        guard let startDate = calendar.date(byAdding: .day, value: -83, to: today) else { return [] }

        var currentWeek: [Date] = []
        var currentDate = startDate

        // Find the first Sunday (or your week start day)
        while calendar.component(.weekday, from: currentDate) != 1 { // 1 = Sunday
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // Build weeks
        for _ in 0..<84 {
            currentWeek.append(currentDate)

            if calendar.component(.weekday, from: currentDate) == 7 { // Saturday
                weeks.append(currentWeek)
                currentWeek = []
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // Add remaining days if any
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }

        return weeks
    }

    private var maxPages: Int {
        guard let max = last12WeeksData.values.max(), max > 0 else { return 1 }
        return max
    }

    private func intensityColor(for pages: Int) -> Color {
        if pages == 0 {
            return Theme.Colors.tertiaryBackground
        }

        let intensity = Double(pages) / Double(maxPages)

        if intensity <= 0.25 {
            return themeColor.color.opacity(0.2)
        } else if intensity <= 0.5 {
            return themeColor.color.opacity(0.4)
        } else if intensity <= 0.75 {
            return themeColor.color.opacity(0.7)
        } else {
            return themeColor.color
        }
    }

    private var totalPages: Int {
        last12WeeksData.values.reduce(0, +)
    }

    private var totalDaysActive: Int {
        last12WeeksData.values.filter { $0 > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with stats
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last 12 Weeks")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.text)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "book.pages")
                                .font(.caption2)
                            Text("\(totalPages) total")
                                .font(.caption)
                        }
                        .foregroundStyle(Theme.Colors.secondaryText)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.tertiaryText)

                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                            Text("\(totalDaysActive) days")
                                .font(.caption)
                        }
                        .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }

                Spacer()
            }

            // Heatmap
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    // Day labels (fixed on left)
                    VStack(alignment: .trailing, spacing: cellSpacing) {
                        ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                            Text(day)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Theme.Colors.tertiaryText)
                                .frame(width: 12, height: cellSize)
                        }
                    }
                    .padding(.top, 4)

                    // Heatmap grid
                    HStack(alignment: .top, spacing: cellSpacing) {
                        ForEach(Array(weeklyData.enumerated()), id: \.offset) { weekIndex, week in
                            VStack(spacing: cellSpacing) {
                                ForEach(Array(week.enumerated()), id: \.offset) { dayIndex, date in
                                    let pages = last12WeeksData[date] ?? 0

                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(intensityColor(for: pages))
                                        .frame(width: cellSize, height: cellSize)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .strokeBorder(
                                                    pages > 0 ? themeColor.color.opacity(0.2) : .clear,
                                                    lineWidth: 0.5
                                                )
                                        )
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }

            // Legend
            HStack(spacing: 8) {
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.Colors.tertiaryText)

                HStack(spacing: 3) {
                    ForEach([0, 0.2, 0.4, 0.7, 1.0], id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(intensity == 0 ? Theme.Colors.tertiaryBackground : themeColor.color.opacity(intensity))
                            .frame(width: 10, height: 10)
                    }
                }

                Text("More")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.Colors.tertiaryText)

                Spacer()
            }
        }
    }
}

#Preview {
    ReadingHeatmapChart(sessions: [])
        .padding()
}
