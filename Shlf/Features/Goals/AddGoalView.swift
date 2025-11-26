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
    @Bindable var profile: UserProfile

    @State private var selectedType: GoalType = .booksPerMonth
    @State private var targetValue: Int = 5
    @State private var duration: GoalDuration = .month
    @State private var customEndDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

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
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Target") {
                    Stepper("\(targetValue) \(selectedType.unit)", value: $targetValue, in: 1...1000)
                        .font(Theme.Typography.body)
                }

                Section("Duration") {
                    Picker("Duration", selection: $duration) {
                        ForEach(GoalDuration.allCases, id: \.self) { duration in
                            Text(duration.rawValue).tag(duration)
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
    }

    private func createGoal() {
        let newGoal = ReadingGoal(
            type: selectedType,
            targetValue: targetValue,
            endDate: endDate
        )

        profile.readingGoals.append(newGoal)
        modelContext.insert(newGoal)

        dismiss()
    }
}

struct GoalPreviewCard: View {
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
                    .foregroundStyle(Theme.Colors.primary)

                Text(type.rawValue)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                Text("0%")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.primary)
            }

            ProgressView(value: 0, total: 100)
                .tint(Theme.Colors.primary)

            HStack {
                Text("0 / \(targetValue) \(type.unit)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Spacer()

                Text("\(daysRemaining) days left")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
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
}

#Preview {
    AddGoalView(profile: UserProfile())
        .modelContainer(for: [UserProfile.self, ReadingGoal.self], inMemory: true)
}
