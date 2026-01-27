//
//  ReadingHeatmapChart.swift
//  Shlf
//
//  GitHub-style activity heatmap for reading
//

import SwiftUI

struct ReadingHeatmapChart: View {
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale
    let sessions: [ReadingSession]
    let period: HeatmapPeriod

    @State private var selectedDate: IdentifiableDate?

    // PERFORMANCE: Cache expensive computed properties as @State
    @State private var periodData: [Date: Int] = [:]
    @State private var weeklyData: [[Date]] = []
    @State private var maxPages: Int = 1
    @State private var totalPages: Int = 0
    @State private var totalDaysActive: Int = 0
    @State private var shouldScrollToEnd = false

    private let columns = 7 // Days of week
    private let cellSize: CGFloat = 18
    private let cellSpacing: CGFloat = 4

    // PERFORMANCE: Reuse calendar instance
    private let calendar = Calendar.current

    private var weekdayHeaderDates: [Date] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    // PERFORMANCE: Calculate all data once when view appears or period changes
    private func calculateData() {
        let today = calendar.startOfDay(for: Date())
        var data: [Date: Int] = [:]

        let startDate: Date
        switch period {
        case .last12Weeks:
            startDate = calendar.date(byAdding: .day, value: -83, to: today)!
        case .currentMonth:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        case .currentYear:
            startDate = calendar.date(from: calendar.dateComponents([.year], from: today))!
        }

        // Build periodData dictionary
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

        periodData = data

        // Build weeklyData array
        var weeks: [[Date]] = []
        var gridStartDate = startDate
        while calendar.component(.weekday, from: gridStartDate) != 1 {
            gridStartDate = calendar.date(byAdding: .day, value: -1, to: gridStartDate)!
        }

        var currentWeek: [Date] = []
        currentDate = gridStartDate

        while currentDate <= today {
            currentWeek.append(currentDate)
            if calendar.component(.weekday, from: currentDate) == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }

        weeklyData = weeks

        // Calculate aggregate values
        maxPages = data.values.max() ?? 1
        totalPages = data.values.reduce(0, +)
        totalDaysActive = data.values.filter { $0 > 0 }.count

        // Trigger scroll to end after data is ready
        shouldScrollToEnd = true
    }

    private var periodTitleText: Text {
        let todayDate = Date()
        switch period {
        case .last12Weeks:
            return Text("Last 12 Weeks")
        case .currentMonth:
            return Text(todayDate, format: .dateTime.month(.wide).year())
        case .currentYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: todayDate))!
            let daysSinceStart = calendar.dateComponents([.day], from: startOfYear, to: todayDate).day! + 1
            let daysText = String.localizedStringWithFormat(
                String(localized: "%lld days", locale: locale),
                daysSinceStart
            )
            return Text("\(todayDate, format: .dateTime.year()) (\(daysText))")
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with stats
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    periodTitleText
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.text)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "book.pages")
                                .font(.caption2)
                            Text(
                                String.localizedStringWithFormat(
                                    String(localized: "%lld total", locale: locale),
                                    totalPages
                                )
                            )
                                .font(.caption)
                        }
                        .foregroundStyle(Theme.Colors.secondaryText)

                        Text(verbatim: "•")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.tertiaryText)

                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                            Text(
                                String.localizedStringWithFormat(
                                    String(localized: "%lld days", locale: locale),
                                    totalDaysActive
                                )
                            )
                                .font(.caption)
                        }
                        .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }

                Spacer()
            }

            // Heatmap
            ZStack(alignment: .topLeading) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 8) {
                            // Spacer for day labels
                            Color.clear
                                .frame(width: 20)

                            // Heatmap grid
                            HStack(alignment: .top, spacing: cellSpacing) {
                                ForEach(Array(weeklyData.enumerated()), id: \.offset) { weekIndex, week in
                                    VStack(spacing: cellSpacing) {
                                        ForEach(Array(week.enumerated()), id: \.offset) { dayIndex, date in
                                            let pages = periodData[date] ?? 0

                                            Button {
                                                if pages > 0 {
                                                    selectedDate = IdentifiableDate(date: date)
                                                }
                                            } label: {
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
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .id(weekIndex)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .onChange(of: shouldScrollToEnd) { _, newValue in
                        if newValue && !weeklyData.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(weeklyData.count - 1, anchor: .trailing)
                                }
                                shouldScrollToEnd = false
                            }
                        }
                    }
                }

                // Sticky day labels
                VStack(alignment: .trailing, spacing: cellSpacing) {
                    ForEach(weekdayHeaderDates, id: \.self) { date in
                        Text(date, format: .dateTime.weekday(.narrow))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Theme.Colors.tertiaryText)
                            .frame(width: 12, height: cellSize)
                    }
                }
                .padding(.top, 4)
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
        .sheet(item: $selectedDate) { identifiableDate in
            LazyView(DayDetailView(date: identifiableDate.date, sessions: sessions))
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            calculateData()
        }
        .onChange(of: period) { _, _ in
            calculateData()
        }
        .onChange(of: sessions.count) { _, _ in
            calculateData()
        }
    }
}

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct BookReadingData: Identifiable {
    let id: UUID
    let book: Book?
    let pages: Int
}

struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale
    let date: Date
    let sessions: [ReadingSession]

    // PERFORMANCE: Cache calculations on init
    @State private var daySessions: [ReadingSession] = []
    @State private var booksRead: [BookReadingData] = []
    @State private var totalPages: Int = 0

    // PERFORMANCE: Reuse calendar
    private let calendar = Calendar.current

    private func calculateData() {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        daySessions = sessions.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }

        var bookMap: [UUID: (Book?, Int)] = [:]
        for session in daySessions {
            if let book = session.book {
                if let existing = bookMap[book.id] {
                    bookMap[book.id] = (book, existing.1 + session.pagesRead)
                } else {
                    bookMap[book.id] = (book, session.pagesRead)
                }
            }
        }

        booksRead = bookMap.map { BookReadingData(id: $0.key, book: $0.value.0, pages: $0.value.1) }
            .sorted { $0.pages > $1.pages }

        totalPages = daySessions.reduce(0) { $0 + $1.pagesRead }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Dynamic gradient background
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
                    VStack(spacing: 20) {
                        if daySessions.isEmpty {
                            emptyDayCard
                        } else {
                            summaryCard
                            booksListCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(localizedDateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeColor.color)
                }
            }
            .onAppear {
                calculateData()
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "book.pages")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("Reading Summary")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(themeColor.color)

                    Text("\(totalPages, format: .number) \(localized("pages", locale: locale))")
                    .font(.title2)
                    .fontWeight(.bold)

                    Spacer()

                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(themeColor.color)

                    let unitText = booksRead.count == 1
                        ? localized("book", locale: locale)
                        : localized("books", locale: locale)
                    Text("\(booksRead.count, format: .number) \(unitText)")
                    .font(.title2)
                    .fontWeight(.bold)
                }
            }
            .padding(12)
            .background(themeColor.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var booksListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical.fill")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("Books Read")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                ForEach(booksRead) { bookData in
                    if let book = bookData.book {
                        HStack(spacing: 12) {
                            BookCoverView(
                                imageURL: book.coverImageURL,
                                title: book.title,
                                width: 50,
                                height: 75
                            )
                            .shadow(color: Theme.Shadow.medium, radius: 6, y: 3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.Colors.text)
                                    .lineLimit(2)

                                Text(book.author)
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                                    .lineLimit(1)

                                HStack(spacing: 4) {
                                    Image(systemName: "book.pages")
                                        .font(.caption2)
                                    Text("\(bookData.pages, format: .number) \(localized("pages", locale: locale))")
                                    .font(.caption)
                                }
                                .foregroundStyle(themeColor.color)
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyDayCard: some View {
        InlineEmptyStateView(
            icon: "calendar",
            title: "No sessions logged",
            message: "Log a session to see details for this day."
        )
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var localizedDateTitle: Text {
        Text(date, format: .dateTime.day().month(.wide).year())
    }
}

#Preview {
    ReadingHeatmapChart(sessions: [], period: .last12Weeks)
        .padding()
}
