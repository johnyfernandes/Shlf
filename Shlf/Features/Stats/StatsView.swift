//
//  StatsView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query private var allSessions: [ReadingSession]
    @Query private var allBooks: [Book]
    @State private var showAddGoal = false
    @State private var refreshTrigger = UUID() // Force refresh when Watch updates
    @State private var selectedAchievement: AchievementEntry?
    @State private var showAllAchievements = false
    @State private var showShareSheet = false
    @State private var showSettings = false
    @State private var showUpgradeSheet = false
    @State private var showStreakDetail = false
    @State private var trendsRange: TrendsRange = .last7
    @State private var calendarMonthOffset = 0
    @State private var selectedCalendarDate: Date?
    @State private var selectedTrend: TrendMetric?

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }

        // CRITICAL: Check again after fetching to prevent race condition
        let descriptor = FetchDescriptor<UserProfile>()
        if let existingAfterFetch = try? modelContext.fetch(descriptor).first {
            return existingAfterFetch
        }

        // Now safe to create
        let new = UserProfile()
        modelContext.insert(new)
        try? modelContext.save() // Save immediately to prevent other threads from creating
        return new
    }

    private var engine: GamificationEngine {
        GamificationEngine(modelContext: modelContext)
    }

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
    }

    private var streaksEnabled: Bool {
        !profile.streaksPaused
    }

    // Computed properties that SwiftUI watches
    private var statSessions: [ReadingSession] {
        allSessions.filter { $0.countsTowardStats }
    }

    private var totalPagesRead: Int {
        max(0, statSessions.reduce(0) { $0 + $1.pagesRead })
    }

    private var totalMinutesRead: Int {
        statSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalBooksRead: Int {
        allBooks.filter { $0.readingStatus == .finished }.count
    }

    private var calendarMonthStart: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let start = calendar.date(from: components) ?? Date()
        return calendar.date(byAdding: .month, value: calendarMonthOffset, to: start) ?? start
    }

    private var minCalendarOffset: Int {
        let calendar = Calendar.current
        let now = Date()
        let currentStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        guard let earliest = earliestCalendarDate else { return 0 }
        let earliestYear = calendar.component(.year, from: earliest)
        let earliestStart = calendar.date(from: DateComponents(year: earliestYear, month: 1, day: 1)) ?? earliest
        let diff = calendar.dateComponents([.month], from: earliestStart, to: currentStart).month ?? 0
        return -max(0, diff)
    }

    private var calendarMonthOptions: [CalendarMonthOption] {
        let calendar = Calendar.current
        let now = Date()
        let currentStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let selectedYear = calendar.component(.year, from: calendarMonthStart)
        let currentYear = calendar.component(.year, from: currentStart)
        let maxMonth = selectedYear == currentYear
            ? calendar.component(.month, from: currentStart)
            : 12

        return (1...maxMonth).compactMap { month in
            guard let date = calendar.date(from: DateComponents(year: selectedYear, month: month, day: 1)) else {
                return nil
            }
            let diff = calendar.dateComponents([.month], from: date, to: currentStart).month ?? 0
            let offset = -diff
            return CalendarMonthOption(offset: offset, date: date)
        }
    }

    private var earliestCalendarDate: Date? {
        let sessionDate = statSessions.map(\.startDate).min()
        let addedDate = allBooks.map(\.dateAdded).min()
        let finishedDate = allBooks.compactMap(\.dateFinished).min()
        return [sessionDate, addedDate, finishedDate].compactMap { $0 }.min()
    }

    private var calendarWeekdays: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }

    private var calendarDaySummaries: [Date: CalendarDaySummary] {
        struct DayAggregate {
            var pages: Int = 0
            var minutes: Int = 0
            var bookPages: [UUID: (pages: Int, cover: URL)] = [:]
        }

        let calendar = Calendar.current
        var totals: [Date: DayAggregate] = [:]

        for session in statSessions {
            let day = calendar.startOfDay(for: session.startDate)
            var entry = totals[day] ?? DayAggregate()
            entry.pages += session.pagesRead
            entry.minutes += session.durationMinutes

            if let book = session.book, let cover = book.coverImageURL {
                let existing = entry.bookPages[book.id]?.pages ?? 0
                entry.bookPages[book.id] = (existing + session.pagesRead, cover)
            }

            totals[day] = entry
        }

        return totals.mapValues { value in
            let topCovers = value.bookPages
                .sorted { $0.value.pages > $1.value.pages }
                .prefix(2)
                .map { $0.value.cover }
            return CalendarDaySummary(pages: value.pages, minutes: value.minutes, coverURLs: topCovers)
        }
    }

    private var calendarGridDays: [CalendarGridDay] {
        let calendar = Calendar.current
        let monthStart = calendarMonthStart
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let totalCells = leadingBlanks + range.count
        let rows = Int(ceil(Double(totalCells) / 7.0))
        let gridCount = rows * 7

        return (0..<gridCount).map { index in
            let dayNumber = index - leadingBlanks + 1
            guard dayNumber >= 1, dayNumber <= range.count else {
                return CalendarGridDay(id: index, date: nil)
            }
            let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart)
            return CalendarGridDay(id: index, date: date)
        }
    }

    private var calendarMonthHasData: Bool {
        let calendar = Calendar.current
        let monthStart = calendarMonthStart
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return false }
        let monthEnd = calendar.date(byAdding: .day, value: range.count - 1, to: monthStart) ?? monthStart
        return calendarDaySummaries.keys.contains { $0 >= monthStart && $0 <= monthEnd }
    }

    private var trendsStartDate: Date {
        let calendar = Calendar.current
        switch trendsRange {
        case .year:
            let year = calendar.component(.year, from: Date())
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? calendar.startOfDay(for: Date())
        default:
            let end = calendar.startOfDay(for: Date())
            let offset = max(1, trendsRange.days) - 1
            return calendar.date(byAdding: .day, value: -offset, to: end) ?? end
        }
    }

    private var trendsEndDate: Date {
        Date()
    }

    private var trendSessions: [ReadingSession] {
        statSessions.filter { session in
            session.startDate >= trendsStartDate && session.startDate <= trendsEndDate
        }
    }

    private var previousTrendSessions: [ReadingSession] {
        let calendar = Calendar.current
        let rangeDays = max(1, trendsRangeDays)
        let previousEnd = calendar.date(byAdding: .day, value: -rangeDays, to: trendsStartDate) ?? trendsStartDate
        let previousStart = calendar.date(byAdding: .day, value: -rangeDays + 1, to: previousEnd) ?? previousEnd
        return statSessions.filter { session in
            session.startDate >= previousStart && session.startDate <= previousEnd
        }
    }

    private var trendsRangeDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: trendsStartDate, to: trendsEndDate).day ?? trendsRange.days
        return max(1, days)
    }

    private var pagesReadInRange: Int {
        max(0, trendSessions.reduce(0) { $0 + $1.pagesRead })
    }

    private var minutesReadInRange: Int {
        max(0, trendSessions.reduce(0) { $0 + $1.durationMinutes })
    }

    private var booksFinishedInRange: Int {
        let calendar = Calendar.current
        return allBooks.filter { book in
            guard book.readingStatus == .finished,
                  let finished = book.dateFinished else { return false }
            return finished >= trendsStartDate && finished <= trendsEndDate
        }.count
    }

    private var topCategoryInRange: String? {
        var counts: [String: Int] = [:]
        for session in trendSessions {
            guard let subjects = session.book?.subjects else { continue }
            for subject in subjects {
                let key = subject.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { continue }
                counts[key, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private var averageSpeedText: String {
        let minutes = minutesReadInRange
        guard minutes > 0 else { return "—" }
        let hours = Double(minutes) / 60.0
        let speed = Double(pagesReadInRange) / max(0.1, hours)
        return String(format: "%.1f", speed)
    }

    private var trendsDateRangeText: Text {
        Text(trendsStartDate, format: .dateTime.day().month(.abbreviated))
        + Text(verbatim: " – ")
        + Text(trendsEndDate, format: .dateTime.day().month(.abbreviated))
    }

    private func trendTitle(prefix: LocalizedStringKey, value: Text, suffix: LocalizedStringKey? = nil, accent: Color) -> Text {
        var text = Text(prefix)
            .foregroundStyle(Theme.Colors.text)

        text = text + Text(verbatim: " ")
            .foregroundStyle(Theme.Colors.text)

        text = text + value
            .foregroundStyle(accent)

        if let suffix {
            text = text + Text(verbatim: " ")
                .foregroundStyle(Theme.Colors.text)
            text = text + Text(suffix)
                .foregroundStyle(Theme.Colors.text)
        }

        return text
    }

    private func trendDelta(current: Int, previous: Int, unit: LocalizedStringKey) -> TrendDelta? {
        guard previous > 0 || current > 0 else { return nil }
        let delta = current - previous
        guard delta != 0 else { return nil }
        let isPositive = delta > 0
        let deltaValue = abs(delta)
        let text = Text(deltaValue, format: .number)
            + Text(verbatim: " ")
            + Text(unit)
        return TrendDelta(text: text, isPositive: isPositive)
    }

    private var todayTrackedSessions: [ReadingSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return statSessions.filter { calendar.isDate($0.startDate, inSameDayAs: today) }
    }

    private var todayPagesRead: Int {
        max(0, todayTrackedSessions.reduce(0) { $0 + $1.pagesRead })
    }

    private var todayMinutesRead: Int {
        max(0, todayTrackedSessions.reduce(0) { $0 + $1.durationMinutes })
    }

    private var dailyPagesTotals: [Date: Int] {
        let calendar = Calendar.current
        var totals: [Date: Int] = [:]
        for session in statSessions {
            let day = calendar.startOfDay(for: session.startDate)
            totals[day, default: 0] += session.pagesRead
        }
        return totals
    }

    private var dailyHundredPageCount: Int {
        dailyPagesTotals.values.filter { max(0, $0) >= 100 }.count
    }

    private var marathonSessionCount: Int {
        statSessions.filter { $0.pagesRead > 0 && $0.durationMinutes >= 180 }.count
    }

    private var booksThisYear: Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return allBooks.filter { book in
            guard book.readingStatus == .finished,
                  let finishDate = book.dateFinished else { return false }
            return calendar.component(.year, from: finishDate) == year
        }.count
    }

    private var booksThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        return allBooks.filter { book in
            guard book.readingStatus == .finished,
                  let finishDate = book.dateFinished else { return false }
            return calendar.isDate(finishDate, equalTo: now, toGranularity: .month)
        }.count
    }

    private var previousBooksFinishedInRange: Int {
        let calendar = Calendar.current
        let rangeDays = max(1, trendsRangeDays)
        let previousEnd = calendar.date(byAdding: .day, value: -rangeDays, to: trendsStartDate) ?? trendsStartDate
        let previousStart = calendar.date(byAdding: .day, value: -rangeDays + 1, to: previousEnd) ?? previousEnd
        return allBooks.filter { book in
            guard book.readingStatus == .finished,
                  let finished = book.dateFinished else { return false }
            return finished >= previousStart && finished <= previousEnd
        }.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Dynamic gradient background
                LinearGradient(
                    colors: [
                        themeColor.color.opacity(0.08),
                        themeColor.color.opacity(0.02),
                        Theme.Colors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        calendarSection
                        overviewSection
                        readingChartSection
                        achievementsSection
                        goalsSection
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(themeColor.color)
                    }
                }
            }
            .id(refreshTrigger) // Force view refresh
            .onAppear {
                refreshGoals()
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    refreshGoals()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchSessionReceived)) { _ in
                refreshTrigger = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchStatsUpdated)) { _ in
                refreshTrigger = UUID()
            }
            .sheet(isPresented: $showAllAchievements) {
                AchievementsGridView(
                    entries: achievementEntries,
                    onSelect: markAchievementViewed
                )
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheetView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(profile: profile)
            }
            .sheet(isPresented: $showStreakDetail) {
                StreakDetailView(profile: profile)
            }
            .sheet(item: $selectedAchievement) { selection in
                AchievementDetailView(
                    type: selection.type,
                    achievement: selection.achievement,
                    progress: selection.progress
                )
            }
            .sheet(item: Binding(
                get: { selectedCalendarDate.map { IdentifiableDate(date: $0) } },
                set: { selectedCalendarDate = $0?.date }
            )) { identifiableDate in
                LazyView(DayDetailView(date: identifiableDate.date, sessions: statSessions))
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedTrend) { metric in
                switch metric {
                case .streak:
                    StreakDetailView(profile: profile)
                default:
                    TrendDetailView(
                        metric: metric,
                        sessions: trendSessions,
                        books: allBooks,
                        range: trendsRange,
                        startDate: trendsStartDate,
                        endDate: trendsEndDate
                    )
                }
            }
        }
    }

    private func refreshGoals() {
        let tracker = GoalTracker(modelContext: modelContext)
        tracker.updateGoals(for: profile)
    }

    private var calendarSection: some View {
        let cellSize: CGFloat = 46
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Calendar")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)

            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Button {
                        calendarMonthOffset = max(minCalendarOffset, calendarMonthOffset - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.text)
                            .padding(6)
                            .background(Theme.Colors.tertiaryBackground, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(calendarMonthOffset <= minCalendarOffset)
                    .opacity(calendarMonthOffset <= minCalendarOffset ? 0.4 : 1)

                    Spacer()

                    Menu {
                        ForEach(calendarMonthOptions) { option in
                            Button {
                                calendarMonthOffset = option.offset
                            } label: {
                                Text(option.date, format: .dateTime.month(.wide).year())
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(calendarMonthStart, format: .dateTime.month(.wide).year())
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Theme.Colors.text)

                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                    }

                    Spacer()

                    Button {
                        calendarMonthOffset = min(0, calendarMonthOffset + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.text)
                            .padding(6)
                            .background(Theme.Colors.tertiaryBackground, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(calendarMonthOffset == 0)
                    .opacity(calendarMonthOffset == 0 ? 0.4 : 1)
                }

                HStack(spacing: 0) {
                    ForEach(calendarWeekdays, id: \.self) { date in
                        Text(date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.Colors.tertiaryText)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(calendarGridDays) { day in
                        if let date = day.date {
                            let dayStart = Calendar.current.startOfDay(for: date)
                            CalendarDayCell(
                                date: date,
                                summary: calendarDaySummaries[dayStart],
                                isToday: Calendar.current.isDateInToday(date),
                                size: cellSize
                            ) {
                                if let summary = calendarDaySummaries[dayStart], summary.pages > 0 {
                                    selectedCalendarDate = date
                                }
                            }
                        } else {
                            CalendarEmptyCell(size: cellSize)
                        }
                    }
                }

                if !calendarMonthHasData {
                    InlineEmptyStateView(
                        icon: "calendar",
                        title: "No sessions this month",
                        message: "Log a session to fill your calendar."
                    )
                    .padding(.top, Theme.Spacing.sm)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(themeColor.color.opacity(0.06), lineWidth: 1)
            )
        }
    }


    private var overviewSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trends")
                        .font(Theme.Typography.title3)
                        .foregroundStyle(Theme.Colors.text)

                    trendsDateRangeText
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                Spacer()

                Menu {
                    Picker("Range", selection: $trendsRange) {
                        ForEach(TrendsRange.allCases) { range in
                            Text(range.title)
                                .tag(range)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(trendsRange.title)
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(Theme.Colors.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.secondaryBackground, in: Capsule())
                }
            }

            VStack(spacing: 12) {
                TrendCard(
                    title: trendTitle(
                        prefix: "You read",
                        value: Text(formatNumber(pagesReadInRange)),
                        suffix: "pages",
                        accent: themeColor.color
                    ),
                    delta: trendDelta(
                        current: pagesReadInRange,
                        previous: previousTrendSessions.reduce(0) { $0 + $1.pagesRead },
                        unit: "pages"
                    ),
                    accent: themeColor.color,
                    icon: .bars,
                    onTap: { selectedTrend = .pages }
                )

                TrendCard(
                    title: trendTitle(
                        prefix: "You read for",
                        value: Text(formatNumber(minutesReadInRange)),
                        suffix: "min",
                        accent: Theme.Colors.secondary
                    ),
                    delta: trendDelta(
                        current: minutesReadInRange,
                        previous: previousTrendSessions.reduce(0) { $0 + $1.durationMinutes },
                        unit: "min"
                    ),
                    accent: Theme.Colors.secondary,
                    icon: .line,
                    onTap: { selectedTrend = .minutes }
                )

                TrendCard(
                    title: trendTitle(
                        prefix: "You finished",
                        value: Text(formatNumber(booksFinishedInRange)),
                        suffix: "books",
                        accent: Theme.Colors.success
                    ),
                    delta: trendDelta(
                        current: booksFinishedInRange,
                        previous: previousBooksFinishedInRange,
                        unit: "books"
                    ),
                    accent: Theme.Colors.success,
                    icon: .bars,
                    onTap: { selectedTrend = .books }
                )

                TrendCard(
                    title: trendTitle(
                        prefix: "Your top category was",
                        value: topCategoryInRange.map(Text.init) ?? Text("No categories yet"),
                        suffix: nil,
                        accent: topCategoryInRange == nil ? Theme.Colors.secondaryText : themeColor.color
                    ),
                    delta: nil,
                    accent: themeColor.color,
                    icon: .dot,
                    onTap: { selectedTrend = .categories }
                )

                TrendCard(
                    title: trendTitle(
                        prefix: "Your longest streak was",
                        value: Text(formatNumber(profile.longestStreak)),
                        suffix: "days",
                        accent: Theme.Colors.warning
                    ),
                    delta: nil,
                    accent: Theme.Colors.warning,
                    icon: .flame,
                    onTap: { selectedTrend = .streak }
                )

                let speedValue: Text = averageSpeedText == "—"
                ? Text(verbatim: "—")
                : Text(averageSpeedText)
                let speedSuffix: LocalizedStringKey? = averageSpeedText == "—" ? nil : "pages/hour"
                let speedAccent = averageSpeedText == "—" ? Theme.Colors.secondaryText : Theme.Colors.primary
                TrendCard(
                    title: trendTitle(
                        prefix: "Your average reading speed was",
                        value: speedValue,
                        suffix: speedSuffix,
                        accent: speedAccent
                    ),
                    delta: nil,
                    accent: Theme.Colors.primary,
                    icon: .speed,
                    onTap: { selectedTrend = .speed }
                )
            }
        }
    }

    private var readingChartSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Reading Activity")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)

            if !statSessions.isEmpty {
                Group {
                    switch profile.chartType {
                    case .bar:
                        ReadingActivityChart(sessions: statSessions)
                            .frame(height: 260)
                    case .heatmap:
                        ReadingHeatmapChart(sessions: statSessions, period: profile.heatmapPeriod)
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)

                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeColor.color.opacity(0.05),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    themeColor.color.opacity(0.15),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            } else if totalPagesRead > 0 {
                // Show simple progress indicator if we have page progress but no sessions
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(themeColor.color.opacity(0.3))

                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "You've read %lld pages!"),
                            totalPagesRead
                        )
                    )
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.text)

                    Text("Use the reading timer to track detailed reading sessions")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.xl)
                .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                EmptyStateView(
                    icon: "chart.bar",
                    title: "No Data Yet",
                    message: "Start reading to see your activity"
                )
            }
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Achievements")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                Text(
                    String.localizedStringWithFormat(
                        String(localized: "%lld/%lld"),
                        (profile.achievements ?? []).count,
                        AchievementType.allCases.count
                    )
                )
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)

                if AchievementType.allCases.count > 6 {
                    Button("View All") {
                        showAllAchievements = true
                    }
                    .font(Theme.Typography.callout)
                    .foregroundStyle(themeColor.color)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(achievementHighlights) { entry in
                        AchievementCard(
                            type: entry.type,
                            achievement: entry.achievement,
                            progress: entry.progress,
                            onView: { handleAchievementSelection(entry) }
                        )
                        .frame(width: 120)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Goals")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                if isProUser {
                    NavigationLink {
                        ManageGoalsView()
                    } label: {
                        Text("Manage")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(themeColor.color)
                    }
                } else {
                    Button {
                        showUpgradeSheet = true
                    } label: {
                        Text("Upgrade")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(themeColor.color)
                    }
                    .buttonStyle(.plain)
                }
            }

            if (profile.readingGoals ?? []).isEmpty {
                if !isProUser {
                    HStack {
                        Spacer()
                        EmptyStateView(
                            icon: "crown.fill",
                            title: "Goals are Pro",
                            message: "Upgrade to create custom reading goals",
                            actionTitle: "Upgrade to Pro",
                            action: {
                                showUpgradeSheet = true
                            }
                        )
                        Spacer()
                    }
                } else {
                    HStack {
                        Spacer()
                        EmptyStateView(
                            icon: "target",
                            title: "No Goals Set",
                            message: "Set reading goals to track your progress",
                            actionTitle: "Add Goal",
                            action: {
                                showAddGoal = true
                            }
                        )
                        Spacer()
                    }
                }
            } else {
                ForEach((profile.readingGoals ?? []).filter { $0.isActive && (streaksEnabled || $0.type != .readingStreak) }) { goal in
                    GoalCard(goal: goal)
                }
            }
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalView(profile: profile)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
    }

    private func achievementProgress(for type: AchievementType, isUnlocked: Bool) -> AchievementProgress {
        let repeatCount = repeatCount(for: type, isUnlocked: isUnlocked)
        switch type {
        case .firstBook:
            return progress(current: totalBooksRead, target: 1, unit: "book", repeatCount: repeatCount)
        case .tenBooks:
            return progress(current: totalBooksRead, target: 10, unit: "books", repeatCount: repeatCount)
        case .fiftyBooks:
            return progress(current: totalBooksRead, target: 50, unit: "books", repeatCount: repeatCount)
        case .hundredBooks:
            return progress(current: totalBooksRead, target: 100, unit: "books", repeatCount: repeatCount)
        case .hundredPages:
            return progress(current: totalPagesRead, target: 100, unit: "pages", repeatCount: repeatCount)
        case .thousandPages:
            return progress(current: totalPagesRead, target: 1000, unit: "pages", repeatCount: repeatCount)
        case .tenThousandPages:
            return progress(current: totalPagesRead, target: 10000, unit: "pages", repeatCount: repeatCount)
        case .sevenDayStreak:
            return progress(current: streaksEnabled ? profile.currentStreak : 0, target: 7, unit: "days", repeatCount: repeatCount)
        case .thirtyDayStreak:
            return progress(current: streaksEnabled ? profile.currentStreak : 0, target: 30, unit: "days", repeatCount: repeatCount)
        case .hundredDayStreak:
            return progress(current: streaksEnabled ? profile.currentStreak : 0, target: 100, unit: "days", repeatCount: repeatCount)
        case .levelFive:
            return levelProgress(current: profile.currentLevel, target: 5, repeatCount: repeatCount)
        case .levelTen:
            return levelProgress(current: profile.currentLevel, target: 10, repeatCount: repeatCount)
        case .levelTwenty:
            return levelProgress(current: profile.currentLevel, target: 20, repeatCount: repeatCount)
        case .hundredPagesInDay:
            return progress(current: todayPagesRead, target: 100, unit: "pages today", repeatCount: repeatCount)
        case .marathonReader:
            return progress(current: todayMinutesRead, target: 180, unit: "min today", repeatCount: repeatCount)
        }
    }

    private func progress(current: Int, target: Int, unit: LocalizedStringKey, repeatCount: Int) -> AchievementProgress {
        let clampedCurrent = max(0, current)
        let text = Text(verbatim: "\(formatNumber(clampedCurrent))/\(formatNumber(target))")
            + Text(verbatim: " ")
            + Text(unit)
        return AchievementProgress(current: clampedCurrent, target: target, text: text, repeatCount: repeatCount)
    }

    private func levelProgress(current: Int, target: Int, repeatCount: Int) -> AchievementProgress {
        let clampedCurrent = max(0, current)
        let text = Text(
            String.localizedStringWithFormat(
                String(localized: "Level %lld/%lld"),
                clampedCurrent,
                target
            )
        )
        return AchievementProgress(current: clampedCurrent, target: target, text: text, repeatCount: repeatCount)
    }

    private func repeatCount(for type: AchievementType, isUnlocked: Bool) -> Int {
        guard isUnlocked, type.isRepeatable else { return 0 }
        switch type {
        case .hundredPagesInDay:
            return dailyHundredPageCount
        case .marathonReader:
            return marathonSessionCount
        default:
            return 0
        }
    }

    private var achievementEntries: [AchievementEntry] {
        AchievementType.allCases.filter { streaksEnabled || !$0.isStreakAchievement }.map { type in
            let unlockedAchievement = (profile.achievements ?? []).first { $0.type == type }
            let progress = achievementProgress(for: type, isUnlocked: unlockedAchievement != nil)
            return AchievementEntry(
                type: type,
                achievement: unlockedAchievement,
                progress: progress
            )
        }
    }

    private var achievementHighlights: [AchievementEntry] {
        let sorted = achievementEntries.sorted { lhs, rhs in
            if lhs.isUnlocked != rhs.isUnlocked {
                return lhs.isUnlocked && !rhs.isUnlocked
            }
            return lhs.progress.fraction > rhs.progress.fraction
        }
        return Array(sorted.prefix(6))
    }

    private func handleAchievementSelection(_ entry: AchievementEntry) {
        selectedAchievement = entry
        markAchievementViewed(entry)
    }

    private func markAchievementViewed(_ entry: AchievementEntry) {
        if let achievement = entry.achievement, achievement.isNew {
            achievement.isNew = false
            do {
                try modelContext.save()
            } catch {
                print("Failed to mark achievement as viewed: \(error.localizedDescription)")
            }
        }
    }
}

private enum TrendsRange: String, CaseIterable, Identifiable {
    case last7
    case last30
    case year

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .last7: return 7
        case .last30: return 30
        case .year: return 365
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .last7: return "7 Days"
        case .last30: return "30 Days"
        case .year: return "This Year"
        }
    }
}

private enum TrendMetric: String, Identifiable {
    case pages
    case minutes
    case books
    case categories
    case streak
    case speed

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .pages: return "Pages Read"
        case .minutes: return "Reading Time"
        case .books: return "Books Finished"
        case .categories: return "Top Categories"
        case .streak: return "Streak"
        case .speed: return "Reading Speed"
        }
    }
}

private enum TrendIcon {
    case bars
    case line
    case dot
    case flame
    case speed
}

private struct TrendCard: View {
    @Environment(\.themeColor) private var themeColor
    let title: Text
    let delta: TrendDelta?
    let accent: Color
    let icon: TrendIcon
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    title
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.text)
                        .lineLimit(2)

                    if let delta {
                        HStack(spacing: 4) {
                            Image(systemName: delta.isPositive ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(delta.isPositive ? Theme.Colors.success : Theme.Colors.error)

                            delta.text
                                .font(.caption)
                                .foregroundStyle(delta.isPositive ? Theme.Colors.success : Theme.Colors.error)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    TrendSpark(icon: icon, accent: accent)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
            }
            .padding(14)
            .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(themeColor.color.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Theme.Shadow.small, radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

private struct TrendSpark: View {
    let icon: TrendIcon
    let accent: Color

    var body: some View {
        switch icon {
        case .bars:
            HStack(spacing: 4) {
                Capsule()
                    .fill(accent.opacity(0.5))
                    .frame(width: 4, height: 10)
                Capsule()
                    .fill(accent)
                    .frame(width: 4, height: 18)
                Capsule()
                    .fill(accent.opacity(0.7))
                    .frame(width: 4, height: 14)
            }
        case .line:
            Image(systemName: "waveform.path.ecg")
                .font(.title3)
                .foregroundStyle(accent)
        case .dot:
            Circle()
                .fill(accent.opacity(0.2))
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                )
        case .flame:
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundStyle(accent)
        case .speed:
            Image(systemName: "speedometer")
                .font(.title3)
                .foregroundStyle(accent)
        }
    }
}

private struct TrendDelta {
    let text: Text
    let isPositive: Bool
}

private struct CalendarDaySummary {
    let pages: Int
    let minutes: Int
    let coverURLs: [URL]
}

private struct CalendarMonthOption: Identifiable {
    let offset: Int
    let date: Date
    var id: Int { offset }
}

private struct CalendarGridDay: Identifiable {
    let id: Int
    let date: Date?
}

private struct CalendarDayCell: View {
    @Environment(\.themeColor) private var themeColor
    let date: Date
    let summary: CalendarDaySummary?
    let isToday: Bool
    let size: CGFloat
    let onSelect: () -> Void

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }

    private var hasActivity: Bool {
        (summary?.pages ?? 0) > 0
    }

    var body: some View {
        Button {
            if hasActivity {
                onSelect()
            }
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hasActivity ? themeColor.color.opacity(0.14) : Theme.Colors.tertiaryBackground)

                if hasActivity {
                    if let summary, !summary.coverURLs.isEmpty {
                        CalendarCoverStack(
                            urls: summary.coverURLs,
                            size: size,
                            accent: themeColor.color
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeColor.color.opacity(0.28),
                                        themeColor.color.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: size * 0.56, height: size * 0.82)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }

                Text(dayNumber)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(hasActivity ? Theme.Colors.text : Theme.Colors.tertiaryText)
                    .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isToday ? themeColor.color.opacity(0.8) : themeColor.color.opacity(0.08),
                        lineWidth: isToday ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: size, maxHeight: size)
        .opacity(hasActivity ? 1 : 0.55)
        .accessibilityLabel(Text(dayNumber))
    }
}

private struct CalendarEmptyCell: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.clear)
            .frame(maxWidth: .infinity, minHeight: size, maxHeight: size)
    }
}

private struct CalendarCoverStack: View {
    let urls: [URL]
    let size: CGFloat
    let accent: Color

    private var coverSize: CGSize {
        CGSize(width: size * 0.56, height: size * 0.82)
    }

    var body: some View {
        ZStack {
            if urls.count > 1 {
                coverView(urls[1])
                    .offset(x: -5, y: -4)
                    .opacity(0.9)

                coverView(urls[0])
                    .offset(x: 4, y: 4)
            } else if let url = urls.first {
                coverView(url)
            }
        }
    }

    private func coverView(_ url: URL) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(0.18))

            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                accent.opacity(0.12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(width: coverSize.width, height: coverSize.height)
        .shadow(color: Theme.Shadow.small, radius: 2, y: 1)
    }
}

private struct TrendDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    let metric: TrendMetric
    let sessions: [ReadingSession]
    let books: [Book]
    let range: TrendsRange
    let startDate: Date
    let endDate: Date

    private struct DailySnapshot: Identifiable {
        let id = UUID()
        let date: Date
        let pages: Int
        let minutes: Int
        let sessions: Int
        let finishedBooks: Int
        let speed: Double
    }

    private var dailySnapshots: [DailySnapshot] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 0

        var sessionsByDay: [Date: [ReadingSession]] = [:]
        for session in sessions {
            let key = calendar.startOfDay(for: session.startDate)
            sessionsByDay[key, default: []].append(session)
        }

        var booksByDay: [Date: Int] = [:]
        for book in books {
            guard book.readingStatus == .finished,
                  let finished = book.dateFinished else { continue }
            let key = calendar.startOfDay(for: finished)
            if finished >= start && finished <= end {
                booksByDay[key, default: 0] += 1
            }
        }

        return (0...dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let daySessions = sessionsByDay[day] ?? []
            let pages = max(0, daySessions.reduce(0) { $0 + $1.pagesRead })
            let minutes = max(0, daySessions.reduce(0) { $0 + $1.durationMinutes })
            let speed = minutes > 0 ? Double(pages) / (Double(minutes) / 60.0) : 0
            return DailySnapshot(
                date: day,
                pages: pages,
                minutes: minutes,
                sessions: daySessions.count,
                finishedBooks: booksByDay[day] ?? 0,
                speed: speed
            )
        }
    }

    private var rangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) – \(end)"
    }

    private var totalPages: Int {
        sessions.reduce(0) { $0 + $1.pagesRead }
    }

    private var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalBooksFinished: Int {
        books.filter { book in
            guard book.readingStatus == .finished, let finished = book.dateFinished else { return false }
            return finished >= startDate && finished <= endDate
        }.count
    }

    private var categoryCounts: [(String, Int)] {
        var counts: [String: Int] = [:]
        for session in sessions {
            guard let subjects = session.book?.subjects else { continue }
            for subject in subjects {
                let key = subject.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { continue }
                counts[key, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }

    private var bestDayPages: Int {
        dailySnapshots.map(\.pages).max() ?? 0
    }

    private var bestDayMinutes: Int {
        dailySnapshots.map(\.minutes).max() ?? 0
    }

    private var averagePagesPerDay: Int {
        guard !dailySnapshots.isEmpty else { return 0 }
        return totalPages / dailySnapshots.count
    }

    private var averageMinutesPerDay: Int {
        guard !dailySnapshots.isEmpty else { return 0 }
        return totalMinutes / dailySnapshots.count
    }

    private var averageSpeed: Double {
        let minutes = totalMinutes
        guard minutes > 0 else { return 0 }
        return Double(totalPages) / (Double(minutes) / 60.0)
    }

    private var fastestSessionSpeed: Double {
        let speeds = sessions.map { session -> Double in
            guard session.durationMinutes > 0 else { return 0 }
            return Double(session.pagesRead) / (Double(session.durationMinutes) / 60.0)
        }
        return speeds.max() ?? 0
    }

    private var finishedBooksInRange: [Book] {
        books.filter { book in
            guard book.readingStatus == .finished, let finished = book.dateFinished else { return false }
            return finished >= startDate && finished <= endDate
        }
        .sorted { ($0.dateFinished ?? .distantPast) > ($1.dateFinished ?? .distantPast) }
    }

    private var accent: Color {
        switch metric {
        case .pages: return themeColor.color
        case .minutes: return Theme.Colors.secondary
        case .books: return Theme.Colors.success
        case .categories: return themeColor.color
        case .streak: return Theme.Colors.warning
        case .speed: return Theme.Colors.primary
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    summaryCard
                    detailCard
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.background)
            .navigationTitle(metric.title)
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

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(summaryValue)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.text)

                Text(summarySuffix)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Spacer()
            }

            Text(rangeLabel)
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)

            if let summaryHint {
                summaryHint
                    .font(.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.12), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
    }

    @ViewBuilder
    private var detailCard: some View {
        switch metric {
        case .pages:
            metricChartCard(
                valueKeyPath: \.pages,
                title: "Pages per day",
                highlight: Text("Best day \(bestDayPages) pages • Avg \(averagePagesPerDay) per day")
            )
        case .minutes:
            metricChartCard(
                valueKeyPath: \.minutes,
                title: "Minutes per day",
                highlight: Text("Best day \(bestDayMinutes) min • Avg \(averageMinutesPerDay) min/day")
            )
        case .books:
            booksDetailCard
        case .categories:
            categoriesDetailCard
        case .streak:
            EmptyView()
        case .speed:
            speedDetailCard
        }
    }

    private func metricChartCard(valueKeyPath: KeyPath<DailySnapshot, Int>, title: LocalizedStringKey, highlight: Text) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.text)

            if dailySnapshots.allSatisfy({ $0[keyPath: valueKeyPath] == 0 }) {
                Text("No activity yet in this range.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            } else {
                Chart(dailySnapshots) { snapshot in
                    BarMark(
                        x: .value("Day", snapshot.date, unit: .day),
                        y: .value("Value", snapshot[keyPath: valueKeyPath])
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, range.days / 6))) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.day()))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.tertiaryText)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }

            highlight
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var booksDetailCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Books finished")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.text)

            if dailySnapshots.allSatisfy({ $0.finishedBooks == 0 }) {
                Text("No finished books in this range.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            } else {
                Chart(dailySnapshots) { snapshot in
                    BarMark(
                        x: .value("Day", snapshot.date, unit: .day),
                        y: .value("Books", snapshot.finishedBooks)
                    )
                    .foregroundStyle(accent)
                    .cornerRadius(6)
                }
                .frame(height: 160)
            }

            if finishedBooksInRange.isEmpty {
                InlineEmptyStateView(
                    icon: "checkmark.seal",
                    title: "No finished books",
                    message: "Finish a book to see it here."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(finishedBooksInRange.prefix(6), id: \.id) { book in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.text)
                                    .lineLimit(1)

                                Text(book.author)
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if let finished = book.dateFinished {
                                Text(finished.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var categoriesDetailCard: some View {
        let topCategories = Array(categoryCounts.prefix(6))
        let maxCount = max(topCategories.map(\.1).max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Categories")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.text)

            if topCategories.isEmpty {
                Text("No categories logged in this range.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(topCategories, id: \.0) { category, count in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(category)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.text)
                                    .lineLimit(1)

                                Spacer()

                                Text(count, format: .number)
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }

                            ProgressView(value: Double(count), total: Double(maxCount))
                                .tint(accent)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var speedDetailCard: some View {
        let averageText = averageSpeed > 0 ? String(format: "%.1f", averageSpeed) : "—"
        let fastestText = fastestSessionSpeed > 0 ? String(format: "%.1f", fastestSessionSpeed) : "—"

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Pages per hour")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.text)

            if dailySnapshots.allSatisfy({ $0.speed == 0 }) {
                Text("No timed sessions in this range.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            } else {
                Chart(dailySnapshots) { snapshot in
                    LineMark(
                        x: .value("Day", snapshot.date, unit: .day),
                        y: .value("Speed", snapshot.speed)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accent)

                    AreaMark(
                        x: .value("Day", snapshot.date, unit: .day),
                        y: .value("Speed", snapshot.speed)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 180)
            }

            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Text(averageText)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.text)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Fastest")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Text(fastestText)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.text)
                }
            }
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var summaryValue: String {
        switch metric {
        case .pages:
            return "\(totalPages)"
        case .minutes:
            return "\(totalMinutes)"
        case .books:
            return "\(totalBooksFinished)"
        case .categories:
            return categoryCounts.first?.0 ?? "—"
        case .streak:
            return "—"
        case .speed:
            let value = averageSpeed > 0 ? String(format: "%.1f", averageSpeed) : "—"
            return value
        }
    }

    private var summarySuffix: LocalizedStringKey {
        switch metric {
        case .pages:
            return "pages"
        case .minutes:
            return "min"
        case .books:
            return "books"
        case .categories:
            return categoryCounts.isEmpty ? "" : "top category"
        case .streak:
            return ""
        case .speed:
            return "pages/hour"
        }
    }

    private var summaryHint: Text? {
        switch metric {
        case .pages:
            return Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld sessions logged"),
                    sessions.count
                )
            )
        case .minutes:
            return Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld sessions logged"),
                    sessions.count
                )
            )
        case .books:
            return Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld books finished"),
                    finishedBooksInRange.count
                )
            )
        case .categories:
            return categoryCounts.isEmpty
            ? nil
            : Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld sessions tagged"),
                    categoryCounts.first?.1 ?? 0
                )
            )
        case .streak:
            return nil
        case .speed:
            return sessions.isEmpty
            ? nil
            : Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld timed sessions"),
                    sessions.count
                )
            )
        }
    }
}

struct ReadingActivityChart: View {
    @Environment(\.themeColor) private var themeColor
    let sessions: [ReadingSession]

    @State private var selectedDate: Date?

    private var last7DaysData: [(Date, Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get last 7 days INCLUDING today (0=today, 1=yesterday, ..., 6=6 days ago)
        return (0..<7).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let pagesRead = sessions
                .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
                .reduce(0) { $0 + $1.pagesRead }

            // CRITICAL: Clamp to non-negative (chart can't display negative bars correctly)
            return (date, max(0, pagesRead))
        }
        .reversed()
    }

    private var totalPages: Int {
        last7DaysData.reduce(0) { $0 + $1.1 }
    }

    private var averagePages: Double {
        let total = last7DaysData.reduce(0) { $0 + $1.1 }
        return Double(total) / 7.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with stats
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last 7 Days")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.text)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "book.pages")
                                .font(.caption2)
                            Text(
                                String.localizedStringWithFormat(
                                    String(localized: "%lld total"),
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
                            Image(systemName: "chart.bar")
                                .font(.caption2)
                            Text(Int(averagePages), format: .number)
                                + Text(verbatim: " ")
                                + Text("avg")
                                .font(.caption)
                        }
                        .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }

                Spacer()
            }

            // Chart
            Chart(last7DaysData, id: \.0) { date, pages in
                BarMark(
                    x: .value("Day", date, unit: .day),
                    y: .value("Pages", pages)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            themeColor.color,
                            themeColor.color.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.weekday(.narrow))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.Colors.tertiaryText.opacity(0.2))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let pages = value.as(Int.self) {
                            Text(pages, format: .number)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Theme.Colors.tertiaryText.opacity(0.2))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartGesture { chart in
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        if let date: Date = chart.value(atX: value.location.x) {
                            // Only show sheet if there are pages read on that day
                            let calendar = Calendar.current
                            let dayStart = calendar.startOfDay(for: date)
                            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

                            let pagesOnDay = sessions
                                .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
                                .reduce(0) { $0 + $1.pagesRead }

                            if pagesOnDay > 0 {
                                selectedDate = date
                            }
                        }
                    }
            }
            .frame(height: 160)
        }
        .sheet(item: Binding(
            get: { selectedDate.map { IdentifiableDate(date: $0) } },
            set: { selectedDate = $0?.date }
        )) { identifiableDate in
            LazyView(DayDetailView(date: identifiableDate.date, sessions: sessions))
                .presentationDetents([.medium, .large])
        }
    }

}

struct AchievementEntry: Identifiable {
    var id: String { type.rawValue }
    let type: AchievementType
    let achievement: Achievement?
    let progress: AchievementProgress

    var isUnlocked: Bool {
        achievement != nil
    }
}

struct AchievementCard: View {
    @Environment(\.themeColor) private var themeColor
    let type: AchievementType
    let achievement: Achievement?
    let progress: AchievementProgress
    let onView: () -> Void

    @State private var shimmerPhase: CGFloat = 0

    private var isUnlocked: Bool {
        achievement != nil
    }

    var body: some View {
        Button {
            onView()
        } label: {
            ZStack {
                VStack(spacing: Theme.Spacing.xs) {
                    ZStack {
                        // Glow effect for unlocked achievements
                        if isUnlocked {
                            Image(systemName: type.icon)
                                .font(.title)
                                .foregroundStyle(themeColor.color)
                                .blur(radius: 8)
                                .opacity(0.6)
                        }

                        Image(systemName: type.icon)
                            .font(.title)
                            .foregroundStyle(isUnlocked ? themeColor.color : Theme.Colors.tertiaryText)
                    }
                    .overlay {
                        if isUnlocked {
                            // Shimmer effect
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white.opacity(0.6),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .rotationEffect(.degrees(30))
                            .offset(x: shimmerPhase)
                            .mask(
                                Image(systemName: type.icon)
                                    .font(.title)
                            )
                            .blendMode(.overlay)
                        }
                    }

                    Text(type.titleKey)
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(isUnlocked ? Theme.Colors.text : Theme.Colors.tertiaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(type.descriptionKey)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isUnlocked ? Theme.Colors.secondaryText : Theme.Colors.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    ProgressView(value: progress.fraction)
                        .tint(isUnlocked ? themeColor.color : Theme.Colors.tertiaryText)
                        .progressViewStyle(.linear)
                        .frame(height: 4)

                    progress.text
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)


                    if let achievement = achievement, achievement.isNew {
                        Text("New!")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeColor.color)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isUnlocked ? themeColor.color.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUnlocked ? themeColor.color.opacity(0.3) : Theme.Colors.tertiaryText.opacity(0.2), lineWidth: 1)
                )

                if isUnlocked && progress.repeatCount > 1 {
                    VStack {
                        HStack {
                            Text(
                                String.localizedStringWithFormat(
                                    String(localized: "x%lld"),
                                    progress.repeatCount
                                )
                            )
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(themeColor.color)
                                .clipShape(Capsule())
                            Spacer()
                        }
                        Spacer()
                    }
                } else if !isUnlocked {
                    // Lock icon for locked achievements
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                                .padding(4)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if isUnlocked {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    shimmerPhase = 200
                }
            }
        }
    }
}

struct AchievementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    let type: AchievementType
    let achievement: Achievement?
    let progress: AchievementProgress

    private var isUnlocked: Bool {
        achievement != nil
    }

    private var statusText: LocalizedStringKey {
        isUnlocked ? "Unlocked" : "Locked"
    }

    private var unlockedDateText: String? {
        guard let unlockedAt = achievement?.unlockedAt else { return nil }
        return unlockedAt.formatted(date: .abbreviated, time: .omitted)
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
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            ZStack {
                                if isUnlocked {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 52))
                                        .foregroundStyle(themeColor.color)
                                        .blur(radius: 10)
                                        .opacity(0.5)
                                }

                                Image(systemName: type.icon)
                                    .font(.system(size: 52))
                                    .foregroundStyle(isUnlocked ? themeColor.color : Theme.Colors.tertiaryText)
                            }

                            Text(type.titleKey)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Theme.Colors.text)

                            Text(type.descriptionKey)
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status")
                                .font(.headline)

                            HStack {
                                Text(statusText)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isUnlocked ? themeColor.color : Theme.Colors.tertiaryText)

                                Spacer()

                                if let unlockedDateText {
                                    Text(unlockedDateText)
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }
                            }

                            if type.isRepeatable {
                                Text(
                                    String.localizedStringWithFormat(
                                        String(localized: "Times earned: %lld"),
                                        progress.repeatCount
                                    )
                                )
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Progress")
                                .font(.headline)

                            ProgressView(value: progress.fraction)
                                .tint(isUnlocked ? themeColor.color : Theme.Colors.tertiaryText)
                                .progressViewStyle(.linear)

                            progress.text
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Achievement")
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
}

struct AchievementsGridView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    let entries: [AchievementEntry]
    let onSelect: (AchievementEntry) -> Void
    @State private var selectedAchievement: AchievementEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: Theme.Spacing.sm
                ) {
                    ForEach(entries) { entry in
                        AchievementCard(
                            type: entry.type,
                            achievement: entry.achievement,
                            progress: entry.progress,
                            onView: {
                                onSelect(entry)
                                selectedAchievement = entry
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeColor.color)
                }
            }
            .sheet(item: $selectedAchievement) { selection in
                AchievementDetailView(
                    type: selection.type,
                    achievement: selection.achievement,
                    progress: selection.progress
                )
            }
        }
    }
}

struct AchievementProgress {
    let current: Int
    let target: Int
    let text: Text
    let repeatCount: Int

    var fraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1)
    }
}

private let achievementNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter
}()

private func formatNumber(_ value: Int) -> String {
    achievementNumberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

struct GoalCard: View {
    @Environment(\.themeColor) private var themeColor
    let goal: ReadingGoal

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: goal.type.icon)
                    .foregroundStyle(themeColor.color)

                Text(goal.type.displayNameKey)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                (
                    Text(Int(goal.progressPercentage), format: .number)
                    + Text(verbatim: "%")
                )
                    .font(Theme.Typography.callout)
                    .foregroundStyle(themeColor.color)
            }

            ProgressView(value: goal.progressPercentage, total: 100)
                .tint(themeColor.color)

            HStack {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "%lld/%lld"),
                        goal.currentValue,
                        goal.targetValue
                    )
                )
                + Text(verbatim: " ")
                + Text(goal.type.unitTextKey)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Spacer()

                if let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: goal.endDate).day {
                    if goal.type.isDaily {
                        Text("Resets at midnight")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    } else if daysLeft >= 0 {
                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "%lld days left"),
                                daysLeft
                            )
                        )
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    } else {
                        Text("Expired")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.error)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ManageGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showAddGoal = false
    @State private var showUpgradeSheet = false

    private var profile: UserProfile? {
        profiles.first
    }

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
    }

    private var streaksEnabled: Bool {
        !(profile?.streaksPaused ?? false)
    }

    var body: some View {
        List {
            if let profile = profile {
                let visibleGoals = (profile.readingGoals ?? []).filter { streaksEnabled || $0.type != .readingStreak }
                if !visibleGoals.isEmpty {
                    Section {
                        ForEach(visibleGoals.filter { $0.isActive }) { goal in
                            GoalRow(goal: goal, profile: profile)
                        }
                    } header: {
                        Text("Active Goals")
                    }

                    let completedGoals = visibleGoals.filter { $0.isCompleted }
                    if !completedGoals.isEmpty {
                        Section {
                            ForEach(completedGoals) { goal in
                                GoalRow(goal: goal, profile: profile)
                            }
                        } header: {
                            Text("Completed")
                        }
                    }

                    let expiredGoals = visibleGoals.filter { !$0.isActive && !$0.isCompleted && $0.endDate < Date() }
                    if !expiredGoals.isEmpty {
                        Section {
                            ForEach(expiredGoals) { goal in
                                GoalRow(goal: goal, profile: profile)
                            }
                        } header: {
                            Text("Expired")
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Goals Yet",
                        systemImage: "target",
                        description: Text("Tap the + button to create your first reading goal")
                    )
                }
            }
        }
        .navigationTitle("Goals")
        .onAppear {
            if let profile = profile {
                let tracker = GoalTracker(modelContext: modelContext)
                tracker.updateGoals(for: profile)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if isProUser {
                        showAddGoal = true
                    } else {
                        showUpgradeSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddGoal) {
            if let profile = profile {
                AddGoalView(profile: profile)
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
    }
}

struct GoalRow: View {
    @Environment(\.themeColor) private var themeColor
    let goal: ReadingGoal
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @State private var showEditGoal = false

    var body: some View {
        Button {
            showEditGoal = true
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Image(systemName: goal.type.icon)
                        .foregroundStyle(goal.isCompleted ? Theme.Colors.success : themeColor.color)

                    Text(goal.type.displayNameKey)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.text)

                    Spacer()

                    if goal.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.success)
                    }
                }

                ProgressView(value: goal.progressPercentage, total: 100)
                    .tint(goal.isCompleted ? Theme.Colors.success : themeColor.color)

                HStack {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "%lld/%lld"),
                            goal.currentValue,
                            goal.targetValue
                        )
                    )
                    + Text(verbatim: " ")
                    + Text(goal.type.unitTextKey)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    Spacer()

                    if let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: goal.endDate).day, daysLeft >= 0 {
                        if goal.type.isDaily {
                            Text("Resets at midnight")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        } else {
                            Text(
                                String.localizedStringWithFormat(
                                    String(localized: "%lld days left"),
                                    daysLeft
                                )
                            )
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                    } else if !goal.isCompleted {
                        Text("Expired")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.error)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.xxs)
        }
        .sheet(isPresented: $showEditGoal) {
            EditGoalView(goal: goal, profile: profile)
        }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [UserProfile.self, ReadingSession.self, Book.self], inMemory: true)
}
