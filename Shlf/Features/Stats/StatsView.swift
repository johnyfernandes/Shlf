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
    @Query private var profiles: [UserProfile]
    @Query private var allSessions: [ReadingSession]
    @Query private var allBooks: [Book]
    @State private var showAddGoal = false
    @State private var refreshTrigger = UUID() // Force refresh when Watch updates

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        let new = UserProfile()
        modelContext.insert(new)
        return new
    }

    private var engine: GamificationEngine {
        GamificationEngine(modelContext: modelContext)
    }

    // Computed properties that SwiftUI watches
    private var totalPagesRead: Int {
        allSessions.reduce(0) { $0 + $1.pagesRead }
    }

    private var totalMinutesRead: Int {
        allSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalBooksRead: Int {
        allBooks.filter { $0.readingStatus == .finished }.count
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
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    overviewSection
                    readingChartSection
                    achievementsSection
                    goalsSection
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Stats")
            .id(refreshTrigger) // Force view refresh
            .onReceive(NotificationCenter.default.publisher(for: .watchSessionReceived)) { _ in
                refreshTrigger = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchStatsUpdated)) { _ in
                refreshTrigger = UUID()
            }
        }
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
                    icon: "books.vertical.fill"
                )

                StatCard(
                    title: "Pages Read",
                    value: "\(totalPagesRead)",
                    icon: "doc.text.fill"
                )

                StatCard(
                    title: "This Year",
                    value: "\(booksThisYear) books",
                    icon: "calendar"
                )

                StatCard(
                    title: "This Month",
                    value: "\(booksThisMonth) books",
                    icon: "calendar.circle"
                )
            }
        }
    }

    private var readingChartSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Reading Activity")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)

            if !allSessions.isEmpty {
                ReadingActivityChart(sessions: allSessions)
                    .padding(Theme.Spacing.md)
                    .cardStyle()
                    .frame(height: 250)
            } else if allBooks.contains(where: { $0.currentPage > 0 }) {
                // Show simple progress indicator if no sessions but books have progress
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(themeColor.color.opacity(0.3))

                    Text("You've read \(engine.totalPagesRead()) pages!")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.text)

                    Text("Log reading sessions to see detailed activity charts")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.xl)
                .cardStyle()
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

            if (profile.achievements ?? []).isEmpty {
                HStack {
                    Spacer()
                    EmptyStateView(
                        icon: "trophy",
                        title: "No Achievements Yet",
                        message: "Keep reading to unlock achievements"
                    )
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    ForEach((profile.achievements ?? []).sorted { $0.unlockedAt > $1.unlockedAt }) { achievement in
                        AchievementCard(achievement: achievement)
                    }
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
}

struct ReadingActivityChart: View {
    @Environment(\.themeColor) private var themeColor
    let sessions: [ReadingSession]

    private var last7DaysData: [(Date, Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let pagesRead = sessions
                .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
                .reduce(0) { $0 + $1.pagesRead }

            return (date, pagesRead)
        }
        .reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Last 7 Days")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.secondaryText)

            Chart(last7DaysData, id: \.0) { date, pages in
                BarMark(
                    x: .value("Day", date, unit: .day),
                    y: .value("Pages", pages)
                )
                .foregroundStyle(themeColor.color.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.weekday(.narrow))
                                .font(Theme.Typography.caption)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let pages = value.as(Int.self) {
                            Text("\(pages)")
                                .font(Theme.Typography.caption)
                        }
                    }
                }
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: achievement.type.icon)
                .font(.title2)
                .foregroundStyle(Theme.Colors.accent)

            Text(achievement.type.title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if achievement.isNew {
                Text("New!")
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
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
                    Text("\(daysLeft) days left")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
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
                        Text("\(daysLeft) days left")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
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
