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
    @State private var showUpgradeSheet = false
    @State private var showStreakDetail = false

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
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
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
        }
    }

    private func refreshGoals() {
        let tracker = GoalTracker(modelContext: modelContext)
        tracker.updateGoals(for: profile)
    }

    private var overviewSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Overview")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                StatCard(
                    title: "Level",
                    value: "\(profile.currentLevel)",
                    icon: "star.fill",
                    gradient: Theme.Colors.xpGradient
                )

                StatCard(
                    title: "Total XP",
                    value: "\(profile.totalXP)",
                    icon: "bolt.fill",
                    gradient: Theme.Colors.xpGradient
                )

                if streaksEnabled {
                    StatCard(
                        title: "Current Streak",
                        value: formatDays(profile.currentStreak),
                        icon: "flame.fill",
                        gradient: Theme.Colors.streakGradient
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showStreakDetail = true
                    }

                    StatCard(
                        title: "Longest Streak",
                        value: formatDays(profile.longestStreak),
                        icon: "flame.circle.fill",
                        gradient: Theme.Colors.streakGradient
                    )
                }

                StatCard(
                    title: "Books Read",
                    value: "\(totalBooksRead)",
                    icon: "books.vertical.fill",
                    gradient: Theme.Colors.successGradient
                )

                StatCard(
                    title: "Pages Read",
                    value: "\(totalPagesRead)",
                    icon: "doc.text.fill",
                    gradient: Theme.Colors.xpGradient
                )

                StatCard(
                    title: "This Year",
                    value: formatBooks(booksThisYear),
                    icon: "calendar",
                    gradient: Theme.Colors.successGradient
                )

                StatCard(
                    title: "This Month",
                    value: formatBooks(booksThisMonth),
                    icon: "calendar.circle",
                    gradient: Theme.Colors.successGradient
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

                    Text(String.localizedStringWithFormat(String(localized: "You've read %lld pages!"), totalPagesRead))
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

                Text("\((profile.achievements ?? []).count) / \(AchievementType.allCases.count)")
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
            return progress(current: totalBooksRead, target: 1, unit: String(localized: "book"), repeatCount: repeatCount)
        case .tenBooks:
            return progress(current: totalBooksRead, target: 10, unit: String(localized: "books"), repeatCount: repeatCount)
        case .fiftyBooks:
            return progress(current: totalBooksRead, target: 50, unit: String(localized: "books"), repeatCount: repeatCount)
        case .hundredBooks:
            return progress(current: totalBooksRead, target: 100, unit: String(localized: "books"), repeatCount: repeatCount)
        case .hundredPages:
            return progress(current: totalPagesRead, target: 100, unit: String(localized: "pages"), repeatCount: repeatCount)
        case .thousandPages:
            return progress(current: totalPagesRead, target: 1000, unit: String(localized: "pages"), repeatCount: repeatCount)
        case .tenThousandPages:
            return progress(current: totalPagesRead, target: 10000, unit: String(localized: "pages"), repeatCount: repeatCount)
        case .sevenDayStreak:
            return progress(current: streaksEnabled ? profile.currentStreak : 0, target: 7, unit: String(localized: "days"), repeatCount: repeatCount)
        case .thirtyDayStreak:
            return progress(current: streaksEnabled ? profile.currentStreak : 0, target: 30, unit: String(localized: "days"), repeatCount: repeatCount)
        case .hundredDayStreak:
            return progress(current: streaksEnabled ? profile.currentStreak : 0, target: 100, unit: String(localized: "days"), repeatCount: repeatCount)
        case .levelFive:
            return levelProgress(current: profile.currentLevel, target: 5, repeatCount: repeatCount)
        case .levelTen:
            return levelProgress(current: profile.currentLevel, target: 10, repeatCount: repeatCount)
        case .levelTwenty:
            return levelProgress(current: profile.currentLevel, target: 20, repeatCount: repeatCount)
        case .hundredPagesInDay:
            return progress(current: todayPagesRead, target: 100, unit: String(localized: "pages today"), repeatCount: repeatCount)
        case .marathonReader:
            return progress(current: todayMinutesRead, target: 180, unit: String(localized: "min today"), repeatCount: repeatCount)
        }
    }

    private func progress(current: Int, target: Int, unit: String, repeatCount: Int) -> AchievementProgress {
        let clampedCurrent = max(0, current)
        let text = "\(formatNumber(clampedCurrent))/\(formatNumber(target)) \(unit)"
        return AchievementProgress(current: clampedCurrent, target: target, text: text, repeatCount: repeatCount)
    }

    private func levelProgress(current: Int, target: Int, repeatCount: Int) -> AchievementProgress {
        let clampedCurrent = max(0, current)
        let text = String.localizedStringWithFormat(
            String(localized: "Level %lld/%lld"),
            clampedCurrent,
            target
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
                            Text("\(totalPages) total")
                                .font(.caption)
                        }
                        .foregroundStyle(Theme.Colors.secondaryText)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.tertiaryText)

                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar")
                                .font(.caption2)
                            Text("\(Int(averagePages)) avg")
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
                            Text("\(pages)")
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

                    Text(type.title)
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(isUnlocked ? Theme.Colors.text : Theme.Colors.tertiaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(type.description)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isUnlocked ? Theme.Colors.secondaryText : Theme.Colors.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    ProgressView(value: progress.fraction)
                        .tint(isUnlocked ? themeColor.color : Theme.Colors.tertiaryText)
                        .progressViewStyle(.linear)
                        .frame(height: 4)

                    Text(progress.text)
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
                            Text("x\(progress.repeatCount)")
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

    private var statusText: String {
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

                            Text(type.title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Theme.Colors.text)

                            Text(type.description)
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
                                Text("Times earned: \(progress.repeatCount)")
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

                            Text(progress.text)
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
    let text: String
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

private func formatDays(_ value: Int) -> String {
    String.localizedStringWithFormat(String(localized: "%lld days"), value)
}

private func formatBooks(_ value: Int) -> String {
    String.localizedStringWithFormat(String(localized: "%lld books"), value)
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

                Text("\(Int(goal.progressPercentage))%")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(themeColor.color)
            }

            ProgressView(value: goal.progressPercentage, total: 100)
                .tint(themeColor.color)

            HStack {
                Text("\(goal.currentValue) / \(goal.targetValue) \(goal.type.unitText)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Spacer()

                if let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: goal.endDate).day {
                    if goal.type.isDaily {
                        Text("Resets at midnight")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    } else if daysLeft >= 0 {
                        Text(String.localizedStringWithFormat(String(localized: "%lld days left"), daysLeft))
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
                    Section("Active Goals") {
                        ForEach(visibleGoals.filter { $0.isActive }) { goal in
                            GoalRow(goal: goal, profile: profile)
                        }
                    }

                    let completedGoals = visibleGoals.filter { $0.isCompleted }
                    if !completedGoals.isEmpty {
                        Section("Completed") {
                            ForEach(completedGoals) { goal in
                                GoalRow(goal: goal, profile: profile)
                            }
                        }
                    }

                    let expiredGoals = visibleGoals.filter { !$0.isActive && !$0.isCompleted && $0.endDate < Date() }
                    if !expiredGoals.isEmpty {
                        Section("Expired") {
                            ForEach(expiredGoals) { goal in
                                GoalRow(goal: goal, profile: profile)
                            }
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
                    Text("\(goal.currentValue) / \(goal.targetValue) \(goal.type.unitText)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    Spacer()

                    if let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: goal.endDate).day, daysLeft >= 0 {
                        if goal.type.isDaily {
                            Text("Resets at midnight")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        } else {
                            Text(String.localizedStringWithFormat(String(localized: "%lld days left"), daysLeft))
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
