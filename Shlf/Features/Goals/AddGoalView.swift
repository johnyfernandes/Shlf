//
//  AddGoalView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile

    @State private var selectedType: GoalType = .booksPerMonth
    @State private var targetValue: Int = 5
    @State private var duration: GoalDuration = .month
    @State private var customEndDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    private var availableGoalTypes: [GoalType] {
        GoalType.allCases.filter { type in
            !profile.streaksPaused || type != .readingStreak
        }
    }

    var endDate: Date {
        switch duration {
        case .week:
            return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        case .month:
            return Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        case .quarter:
            return Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        case .year:
            return Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        case .custom:
            return customEndDate
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(availableGoalTypes, id: \.self) { type in
                            Label(type.displayNameKey, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .tint(themeColor.color)
                }

                Section("Target") {
                    Stepper("\(targetValue) \(selectedType.unitText)", value: $targetValue, in: 1...1000)
                        .font(Theme.Typography.body)
                }

                Section("Duration") {
                    Picker("Duration", selection: $duration) {
                        ForEach(GoalDuration.allCases, id: \.self) { duration in
                            Text(duration.displayNameKey).tag(duration)
                        }
                    }
                    .pickerStyle(.segmented)

                    if duration == .custom {
                        DatePicker("End Date", selection: $customEndDate, in: Date()..., displayedComponents: .date)
                    } else {
                        HStack {
                            Text("Ends on")
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Spacer()
                            Text(endDate, style: .date)
                                .foregroundStyle(Theme.Colors.text)
                        }
                        .font(Theme.Typography.callout)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Preview")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.text)

                        GoalPreviewCard(
                            type: selectedType,
                            targetValue: targetValue,
                            endDate: endDate
                        )
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGoal()
                    }
                    .disabled(targetValue < 1)
                }
            }
        }
        .onAppear {
            if !availableGoalTypes.contains(selectedType) {
                selectedType = availableGoalTypes.first ?? .booksPerMonth
            }
        }
    }

    private func createGoal() {
        let newGoal = ReadingGoal(
            type: selectedType,
            targetValue: targetValue,
            endDate: endDate
        )

        if profile.readingGoals == nil {
            profile.readingGoals = []
        }
        profile.readingGoals?.append(newGoal)
        modelContext.insert(newGoal)

        // CRITICAL: Save so goal persists
        try? modelContext.save()

        dismiss()
    }
}

struct GoalPreviewCard: View {
    @Environment(\.themeColor) private var themeColor
    let type: GoalType
    let targetValue: Int
    let endDate: Date

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: type.icon)
                    .foregroundStyle(themeColor.color)

                Text(type.displayNameKey)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                Text("0%")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(themeColor.color)
            }

            ProgressView(value: 0, total: 100)
                .tint(themeColor.color)

            HStack {
                Text("0 / \(targetValue) \(type.unitText)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Spacer()

                if type.isDaily {
                    Text("Resets at midnight")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                } else {
                    Text(String.localizedStringWithFormat(String(localized: "%lld days left"), daysRemaining))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }
}

enum GoalDuration: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"
    case custom = "Custom"

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        case .custom: return "Custom"
        }
    }
}

#Preview {
    AddGoalView(profile: UserProfile())
        .modelContainer(for: [UserProfile.self, ReadingGoal.self], inMemory: true)
}
