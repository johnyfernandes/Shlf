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
    @State private var selectedAchievement: AchievementSelection?

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

    // Computed properties that SwiftUI watches
    private var statSessions: [ReadingSession] {
        allSessions.filter { $0.countsTowardStats }
    }

    private var totalPagesRead: Int {
        statSessions.reduce(0) { $0 + $1.pagesRead }
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

                StatCard(
                    title: "Current Streak",
                    value: "\(profile.currentStreak) days",
                    icon: "flame.fill",
                    gradient: Theme.Colors.streakGradient
                )

                StatCard(
                    title: "Longest Streak",
                    value: "\(profile.longestStreak) days",
                    icon: "flame.circle.fill",
                    gradient: Theme.Colors.streakGradient
                )

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
                    value: "\(booksThisYear) books",
                    icon: "calendar",
                    gradient: Theme.Colors.successGradient
                )

                StatCard(
                    title: "This Month",
                    value: "\(booksThisMonth) books",
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

                    Text("You've read \(totalPagesRead) pages!")
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
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                ForEach(AchievementType.allCases, id: \.self) { type in
                    let unlockedAchievement = (profile.achievements ?? []).first { $0.type == type }
                    let progress = achievementProgress(for: type, isUnlocked: unlockedAchievement != nil)
                    AchievementCard(
                        type: type,
                        achievement: unlockedAchievement,
                        progress: progress,
                        onView: {
                            selectedAchievement = AchievementSelection(
                                type: type,
                                achievement: unlockedAchievement,
                                progress: progress
                            )
                            if let achievement = unlockedAchievement, achievement.isNew {
                                achievement.isNew = false
                                do {
                                    try modelContext.save()
                                } catch {
                                    // Log but don't show error to user (non-critical UX state)
                                    print("Failed to mark achievement as viewed: \(error.localizedDescription)")
                                }
                            }
                        }
                    )
                }
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

                NavigationLink {
                    ManageGoalsView()
                } label: {
                    Text("Manage")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(themeColor.color)
                }
            }

            if (profile.readingGoals ?? []).isEmpty {
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
            } else {
                ForEach((profile.readingGoals ?? []).filter { $0.isActive }) { goal in
                    GoalCard(goal: goal)
                }
            }
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalView(profile: profile)
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
            return progress(current: profile.currentStreak, target: 7, unit: "days", repeatCount: repeatCount)
        case .thirtyDayStreak:
            return progress(current: profile.currentStreak, target: 30, unit: "days", repeatCount: repeatCount)
        case .hundredDayStreak:
            return progress(current: profile.currentStreak, target: 100, unit: "days", repeatCount: repeatCount)
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

    private func progress(current: Int, target: Int, unit: String, repeatCount: Int) -> AchievementProgress {
        let clampedCurrent = max(0, current)
        let text = "\(formatNumber(clampedCurrent))/\(formatNumber(target)) \(unit)"
        return AchievementProgress(current: clampedCurrent, target: target, text: text, repeatCount: repeatCount)
    }

    private func levelProgress(current: Int, target: Int, repeatCount: Int) -> AchievementProgress {
        let clampedCurrent = max(0, current)
        let text = "Level \(formatNumber(clampedCurrent))/\(formatNumber(target))"
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

private struct AchievementSelection: Identifiable {
    let id = UUID()
    let type: AchievementType
    let achievement: Achievement?
    let progress: AchievementProgress
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

struct GoalCard: View {
    @Environment(\.themeColor) private var themeColor
    let goal: ReadingGoal

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: goal.type.icon)
                    .foregroundStyle(themeColor.color)

                Text(goal.type.rawValue)
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
                Text("\(goal.currentValue) / \(goal.targetValue) \(goal.type.unit)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Spacer()

                if let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: goal.endDate).day {
                    if goal.type.isDaily {
                        Text("Resets at midnight")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    } else if daysLeft >= 0 {
                        Text("\(daysLeft) days left")
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

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        List {
            if let profile = profile {
                if !(profile.readingGoals ?? []).isEmpty {
                    Section("Active Goals") {
                        ForEach((profile.readingGoals ?? []).filter { $0.isActive }) { goal in
                            GoalRow(goal: goal, profile: profile)
                        }
                    }

                    let completedGoals = (profile.readingGoals ?? []).filter { $0.isCompleted }
                    if !completedGoals.isEmpty {
                        Section("Completed") {
                            ForEach(completedGoals) { goal in
                                GoalRow(goal: goal, profile: profile)
                            }
                        }
                    }

                    let expiredGoals = (profile.readingGoals ?? []).filter { !$0.isActive && !$0.isCompleted && $0.endDate < Date() }
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
                    showAddGoal = true
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

                    Text(goal.type.rawValue)
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
                    Text("\(goal.currentValue) / \(goal.targetValue) \(goal.type.unit)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    Spacer()

                    if let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: goal.endDate).day, daysLeft >= 0 {
                        if goal.type.isDaily {
                            Text("Resets at midnight")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        } else {
                            Text("\(daysLeft) days left")
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
