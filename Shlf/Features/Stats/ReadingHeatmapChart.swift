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
    let period: HeatmapPeriod

    private let columns = 7 // Days of week
    private let cellSize: CGFloat = 18
    private let cellSpacing: CGFloat = 4

    // Get data for the selected period
    private var periodData: [Date: Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var data: [Date: Int] = [:]

        let startDate: Date
        switch period {
        case .last12Weeks:
            // Last 84 days
            startDate = calendar.date(byAdding: .day, value: -83, to: today)!

        case .currentMonth:
            // First day of current month
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!

        case .currentYear:
            // First day of current year (January 1st)
            startDate = calendar.date(from: calendar.dateComponents([.year], from: today))!
        }

        // Iterate from start date to today
        var currentDate = startDate
        while currentDate <= today {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let pagesRead = sessions
                .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
                .reduce(0) { $0 + $1.pagesRead }

            data[dayStart] = max(0, pagesRead)

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return data
    }

    // Organize data into weeks (columns)
    private var weeklyData: [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var weeks: [[Date]] = []

        var startDate: Date
        switch period {
        case .last12Weeks:
            // Last 84 days
            startDate = calendar.date(byAdding: .day, value: -83, to: today)!

        case .currentMonth:
            // First day of current month
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!

        case .currentYear:
            // First day of current year
            startDate = calendar.date(from: calendar.dateComponents([.year], from: today))!
        }

        // Find the first Sunday before or on startDate
        var gridStartDate = startDate
        while calendar.component(.weekday, from: gridStartDate) != 1 {
            gridStartDate = calendar.date(byAdding: .day, value: -1, to: gridStartDate)!
        }

        var currentWeek: [Date] = []
        var currentDate = gridStartDate

        // Build weeks until we pass today
        while currentDate <= today {
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
        guard let max = periodData.values.max(), max > 0 else { return 1 }
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
        periodData.values.reduce(0, +)
    }

    private var totalDaysActive: Int {
        periodData.values.filter { $0 > 0 }.count
    }

    private var periodTitle: String {
        let calendar = Calendar.current
        let today = Date()

        switch period {
        case .last12Weeks:
            return "Last 12 Weeks"
        case .currentMonth:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: today)
        case .currentYear:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: today))!
            let daysSinceStart = calendar.dateComponents([.day], from: startOfYear, to: today).day! + 1
            return "\(formatter.string(from: today)) (\(daysSinceStart) days)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with stats
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(periodTitle)
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
                                    let pages = periodData[date] ?? 0

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
    ReadingHeatmapChart(sessions: [], period: .last12Weeks)
        .padding()
}
