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
    @Query private var profiles: [UserProfile]
    @Query private var allSessions: [ReadingSession]
    @Query private var allBooks: [Book]

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
                    value: "\(engine.totalBooksRead())",
                    icon: "books.vertical.fill"
                )

                StatCard(
                    title: "Pages Read",
                    value: "\(engine.totalPagesRead())",
                    icon: "doc.text.fill"
                )

                StatCard(
                    title: "This Year",
                    value: "\(engine.booksReadThisYear()) books",
                    icon: "calendar"
                )

                StatCard(
                    title: "This Month",
                    value: "\(engine.booksReadThisMonth()) books",
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
            } else {
                EmptyStateView(
                    icon: "chart.bar",
                    title: "No Data Yet",
                    message: "Start logging reading sessions to see your activity"
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

                Text("\(profile.achievements.count) / \(AchievementType.allCases.count)")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            if profile.achievements.isEmpty {
                EmptyStateView(
                    icon: "trophy",
                    title: "No Achievements Yet",
                    message: "Keep reading to unlock achievements"
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    ForEach(profile.achievements.sorted { $0.unlockedAt > $1.unlockedAt }) { achievement in
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
                        .foregroundStyle(Theme.Colors.primary)
                }
            }

            if profile.readingGoals.isEmpty {
                EmptyStateView(
                    icon: "target",
                    title: "No Goals Set",
                    message: "Set reading goals to track your progress",
                    actionTitle: "Add Goal",
                    action: {}
                )
            } else {
                ForEach(profile.readingGoals.filter { $0.isActive }) { goal in
                    GoalCard(goal: goal)
                }
            }
        }
    }
}

struct ReadingActivityChart: View {
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
                .foregroundStyle(Theme.Colors.primary.gradient)
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
    let goal: ReadingGoal

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: goal.type.icon)
                    .foregroundStyle(Theme.Colors.primary)

                Text(goal.type.rawValue)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                Text("\(Int(goal.progressPercentage))%")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.primary)
            }

            ProgressView(value: goal.progressPercentage, total: 100)
                .tint(Theme.Colors.primary)

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
    var body: some View {
        Text("Manage Goals - Coming Soon")
            .navigationTitle("Goals")
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [UserProfile.self, ReadingSession.self, Book.self], inMemory: true)
}
